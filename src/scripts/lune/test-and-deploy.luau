-- Description: Deploy pipeline: uploads the merged place as a saved version, runs the in-place test suite against that exact version through Open Cloud, and publishes only when the suite is green.

--!strict

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")
local Artifact = require("./release-artifact")
local Receipt = require("./release-receipt")

local POLL_SECONDS = 3
local POLL_TIMEOUT_SECONDS = 600
local TASK_EXECUTION_TIMEOUT = "300s"
local CREATE_RETRIES = 5
local CREATE_RETRY_SECONDS = 20
local REQUEST_RETRIES = 5
local REQUEST_TIMEOUT_SECONDS = 30
local REQUEST_WATCH_SECONDS = 0.05
local REQUEST_RETRY_MAX_SECONDS = 15
local LOG_TIMEOUT_SECONDS = 90
local MAX_LOG_PAGES = 20
local RETRYABLE_STATUS_CODES = {
	[429] = true,
	[500] = true,
	[502] = true,
	[503] = true,
	[504] = true,
}

type RequestResult = {
	ok: boolean,
	response: any,
	error: string,
	elapsedSeconds: number,
}

type GetResult = {
	ok: boolean,
	body: string,
	error: string,
	elapsedSeconds: number,
	statusCode: number?,
	attempts: number,
}

local function fail(code: number, message: string): never
	print(`error: {message}`)
	return process.exit(code)
end

local function requireEnv(name: string): string
	local value = process.env[name]
	if value == nil or value == "" then
		fail(1, `environment variable {name} is required`)
	end
	return value :: string
end

local args = table.clone(process.args)
if args[1] == "--" then
	table.remove(args, 1)
end
if
	#args < 2
	or #args > 3
	or (args[3] ~= nil and args[3] ~= "--test-only" and args[3] ~= "--stage-only" and args[3] ~= "--publish-tested")
then
	fail(
		1,
		"usage: lune run src/scripts/lune/test-and-deploy.luau <place.rbxl> <task-script.luau> [--test-only|--stage-only|--publish-tested]"
	)
end
local placeFile, taskFile = args[1], args[2]
local testOnly = args[3] == "--test-only"
local stageOnly = args[3] == "--stage-only"
local publishTested = args[3] == "--publish-tested"

if not testOnly and not fs.isFile(placeFile) then
	fail(1, `missing place file: {placeFile}`)
end
if not fs.isFile(taskFile) then
	fail(1, `missing task script: {taskFile}`)
end

local apiKey = requireEnv("ROBLOX_API_KEY")
local universeId = requireEnv("ROBLOX_UNIVERSE_ID")
local placeId = requireEnv("ROBLOX_PLACE_ID")
local artifactSha256 = if testOnly then nil else Artifact.hashFile(placeFile)

local function rbxcloud(subcommand: { string }): (boolean, string, string)
	local fullArgs = table.clone(subcommand)
	table.insert(fullArgs, "--api-key")
	table.insert(fullArgs, apiKey)
	local result = process.exec("rbxcloud", fullArgs)
	return result.ok, result.stdout, result.stderr
end

local function decodeJson(stdout: string, context: string): { [string]: any }
	local ok, decoded = pcall(serde.decode, "json" :: any, stdout)
	if not ok or typeof(decoded) ~= "table" then
		fail(1, `{context}: could not parse JSON response:\n{stdout}`)
	end
	return decoded :: any
end

local function formatSeconds(value: number): string
	return string.format("%.1fs", math.max(value, 0))
end

local function requestWithTimeout(config: any, timeoutSeconds: number): RequestResult
	local startedAt = os.clock()
	local completed = false
	local requestOk = false
	local response: any = nil
	local worker = task.spawn(function()
		requestOk, response = pcall(function()
			return net.request(config)
		end)
		completed = true
	end)
	local deadline = startedAt + timeoutSeconds

	while not completed and os.clock() < deadline do
		task.wait(math.min(REQUEST_WATCH_SECONDS, math.max(deadline - os.clock(), 0)))
	end

	local elapsedSeconds = os.clock() - startedAt
	if not completed then
		pcall(function()
			task.cancel(worker)
		end)
		return {
			ok = false,
			response = nil,
			error = `request timed out after {formatSeconds(timeoutSeconds)}`,
			elapsedSeconds = elapsedSeconds,
		}
	end
	if not requestOk then
		return {
			ok = false,
			response = nil,
			error = tostring(response),
			elapsedSeconds = elapsedSeconds,
		}
	end
	return {
		ok = true,
		response = response,
		error = "",
		elapsedSeconds = elapsedSeconds,
	}
end

local function openCloudGet(path: string, query: { [string]: string }?, context: string, deadline: number?): GetResult
	local startedAt = os.clock()
	local lastBody = ""
	local lastError = "request failed"
	local lastStatusCode: number? = nil
	local attempts = 0
	for attempt = 1, REQUEST_RETRIES do
		attempts = attempt
		local remainingSeconds = if deadline then deadline - os.clock() else REQUEST_TIMEOUT_SECONDS
		if remainingSeconds <= 0 then
			lastError = `{context} exceeded its deadline`
			break
		end

		local requestResult = requestWithTimeout({
			url = `https://apis.roblox.com/cloud/v2/{path}`,
			method = "GET",
			headers = {
				["x-api-key"] = apiKey,
				Accept = "application/json",
			},
			query = query,
		}, math.min(REQUEST_TIMEOUT_SECONDS, remainingSeconds))
		if requestResult.ok then
			local fetchResponse = requestResult.response :: any
			lastStatusCode = fetchResponse.statusCode
			if fetchResponse.ok then
				return {
					ok = true,
					body = fetchResponse.body or "",
					error = "",
					elapsedSeconds = os.clock() - startedAt,
					statusCode = lastStatusCode,
					attempts = attempt,
				}
			end
			lastBody = fetchResponse.body or ""
			lastError = `http {tostring(fetchResponse.statusCode)}: {tostring(fetchResponse.statusMessage)}`
			if not RETRYABLE_STATUS_CODES[fetchResponse.statusCode] then
				break
			end
		else
			lastError = requestResult.error
		end

		if attempt < REQUEST_RETRIES then
			local retrySeconds = math.min(2 ^ (attempt - 1), REQUEST_RETRY_MAX_SECONDS)
			if deadline then
				retrySeconds = math.min(retrySeconds, math.max(deadline - os.clock(), 0))
			end
			if retrySeconds <= 0 then
				break
			end
			print(
				`[Open Cloud] {context}: attempt {attempt}/{REQUEST_RETRIES} failed ({lastError}); retrying in {formatSeconds(
					retrySeconds
				)}`
			)
			task.wait(retrySeconds)
		end
	end
	return {
		ok = false,
		body = lastBody,
		error = lastError,
		elapsedSeconds = os.clock() - startedAt,
		statusCode = lastStatusCode,
		attempts = attempts,
	}
end

local function looksBusy(stderr: string): boolean
	local lowered = string.lower(stderr)
	return string.find(lowered, "429", 1, true) ~= nil
		or string.find(lowered, "too many", 1, true) ~= nil
		or string.find(lowered, "rate limit", 1, true) ~= nil
end

local function upload(versionType: string): string
	assert(Artifact.hashFile(placeFile) == artifactSha256, "[release] artifact changed during deployment")
	print(`uploading {placeFile} as {versionType} version...`)
	local ok, stdout, stderr = rbxcloud({
		"experience",
		"publish",
		"--filename",
		placeFile,
		"--universe-id",
		universeId,
		"--place-id",
		placeId,
		"--version-type",
		versionType,
	})
	if not ok then
		fail(1, `place upload ({versionType}) failed:\n{stderr}\n{stdout}`)
	end
	local response = decodeJson(stdout, "place upload")
	local versionNumber = response.versionNumber or response.version_number
	if typeof(versionNumber) ~= "number" then
		fail(1, `place upload returned no version number:\n{stdout}`)
	end
	print(`uploaded {versionType} version {versionNumber}`)
	return tostring(versionNumber)
end

local function createTask(versionId: string?): { [string]: any }
	local createArgs = {
		"luau",
		"execute",
		"--universe-id",
		universeId,
		"--place-id",
		placeId,
		"--filepath",
		taskFile,
		"--timeout",
		TASK_EXECUTION_TIMEOUT,
	}
	if versionId then
		table.insert(createArgs, "--version-id")
		table.insert(createArgs, versionId)
	end

	for attempt = 1, CREATE_RETRIES do
		local ok, stdout, stderr = rbxcloud(createArgs)
		if ok then
			return decodeJson(stdout, "task creation")
		end
		if not looksBusy(stderr) then
			fail(1, `task creation failed:\n{stderr}\n{stdout}`)
		end
		if attempt < CREATE_RETRIES then
			print(`Open Cloud is busy (attempt {attempt}/{CREATE_RETRIES}); retrying in {CREATE_RETRY_SECONDS}s...`)
			task.wait(CREATE_RETRY_SECONDS)
		end
	end
	return fail(2, "Open Cloud is still busy after retries; nothing was published")
end

local function pollTask(taskPath: string): { [string]: any }
	local startedAt = os.clock()
	local deadline = startedAt + POLL_TIMEOUT_SECONDS
	local pollCount = 0
	local lastState: string? = nil
	print(
		`[Open Cloud] polling every {POLL_SECONDS}s for up to {POLL_TIMEOUT_SECONDS}s; each HTTP request is capped at {REQUEST_TIMEOUT_SECONDS}s`
	)

	while true do
		local remainingSeconds = deadline - os.clock()
		if remainingSeconds <= 0 then
			fail(
				1,
				`task did not finish within {POLL_TIMEOUT_SECONDS}s after {pollCount} polls (last state: {lastState or "not observed"})`
			)
		end

		pollCount += 1
		print(
			`[Open Cloud] poll {pollCount}: requesting state (elapsed {formatSeconds(os.clock() - startedAt)}, remaining {formatSeconds(
				remainingSeconds
			)})`
		)
		local result = openCloudGet(taskPath, { view = "BASIC" }, `task poll {pollCount}`, deadline)
		if not result.ok then
			if looksBusy(result.error) then
				fail(2, `task poll was rate-limited after retries:\n{result.error}\n{result.body}`)
			end
			fail(1, `task poll failed after {formatSeconds(result.elapsedSeconds)}:\n{result.error}\n{result.body}`)
		end
		local taskInfo = decodeJson(result.body, "task poll")
		local state = taskInfo.state
		if typeof(state) ~= "string" then
			fail(1, `task poll returned no state:\n{result.body}`)
		end

		local stateLabel = if lastState and lastState ~= state then `{lastState} -> {state}` else tostring(state)
		lastState = state
		print(
			`[Open Cloud] poll {pollCount}: HTTP {tostring(result.statusCode)}, state {stateLabel}, request {formatSeconds(
				result.elapsedSeconds
			)}, attempts {result.attempts}, elapsed {formatSeconds(os.clock() - startedAt)}`
		)

		if state ~= "QUEUED" and state ~= "PROCESSING" then
			print(`[Open Cloud] task reached terminal state {state} after {pollCount} polls`)
			return taskInfo
		end

		local waitSeconds = math.min(POLL_SECONDS, math.max(deadline - os.clock(), 0))
		if waitSeconds > 0 then
			task.wait(waitSeconds)
		end
	end
end

local function printLogs(taskPath: string)
	print("---- cloud test logs ----")
	local startedAt = os.clock()
	local deadline = startedAt + LOG_TIMEOUT_SECONDS
	local pageToken: string? = nil
	local seenPageTokens: { [string]: boolean } = {}
	local pageCount = 0
	local messageCount = 0
	while true do
		if pageCount >= MAX_LOG_PAGES then
			print(`warning: stopped fetching task logs after {MAX_LOG_PAGES} pages`)
			break
		end
		if os.clock() >= deadline then
			print(`warning: stopped fetching task logs after {LOG_TIMEOUT_SECONDS}s`)
			break
		end

		pageCount += 1
		local query = {
			view = "FLAT",
			maxPageSize = "10000",
		}
		if pageToken then
			query.pageToken = pageToken
		end
		print(`[Open Cloud] requesting task log page {pageCount}`)
		local result = openCloudGet(`{taskPath}/logs`, query, `task logs page {pageCount}`, deadline)
		if not result.ok then
			print(`warning: could not fetch task log page {pageCount}:\n{result.error}`)
			break
		end
		local logs = decodeJson(result.body, "task logs")
		local pageMessageCount = 0
		for _, page in (logs.luauExecutionSessionTaskLogs or {}) :: { any } do
			for _, message in (page.messages or {}) :: { any } do
				print(message)
				pageMessageCount += 1
			end
		end
		messageCount += pageMessageCount
		print(
			`[Open Cloud] task log page {pageCount}: HTTP {tostring(result.statusCode)}, {pageMessageCount} messages, request {formatSeconds(
				result.elapsedSeconds
			)}`
		)
		local nextPageToken = logs.nextPageToken
		if typeof(nextPageToken) == "string" and nextPageToken ~= "" then
			if seenPageTokens[nextPageToken] then
				print("warning: task logs returned a repeated page token; stopping pagination")
				break
			end
			seenPageTokens[nextPageToken] = true
			pageToken = nextPageToken
		else
			break
		end
	end
	print(
		`[Open Cloud] fetched {messageCount} task log messages across {pageCount} pages in {formatSeconds(
			os.clock() - startedAt
		)}`
	)
	print("---- end cloud test logs ----")
end

local function publish(evidence: Receipt.Evidence)
	evidence.publishedVersionId = upload("published")
	Receipt.write(placeFile .. ".published.json", evidence)
	print(`published version {evidence.publishedVersionId} from tested saved version {evidence.savedVersionId}`)
end

if publishTested then
	publish(Receipt.verify(placeFile, universeId, placeId))
	process.exit(0)
end

local versionId: string? = nil
local evidence: Receipt.Evidence? = nil
if testOnly then
	print("running cloud tests against the current place version (--test-only)")
else
	versionId = upload("saved")
	evidence = {
		schemaVersion = 1,
		universeId = universeId,
		placeId = placeId,
		artifactSha256 = artifactSha256 :: string,
		savedVersionId = versionId,
		state = "SAVED",
	}
	Receipt.write(placeFile .. ".tested.json", evidence)
end

print(`creating Luau execution task (timeout {TASK_EXECUTION_TIMEOUT})...`)
local createdTask = createTask(versionId)
local taskPath = createdTask.path
if typeof(taskPath) ~= "string" then
	fail(1, `task creation returned no path:\n{serde.encode("json", createdTask)}`)
end
print(`task created: {taskPath}`)
if evidence then
	evidence.taskPath = taskPath :: string
	evidence.state = "PROCESSING"
	Receipt.write(placeFile .. ".tested.json", evidence)
end

local finishedTask = pollTask(taskPath :: string)
if evidence then
	evidence.state = finishedTask.state
	Receipt.write(placeFile .. ".tested.json", evidence)
end
printLogs(taskPath :: string)

local state = finishedTask.state
if state ~= "COMPLETE" then
	if finishedTask.error then
		print(`task error: {serde.encode("json", finishedTask.error)}`)
	end
	fail(1, `cloud tests did not pass (task state: {tostring(state)}); nothing was published`)
end

print("cloud tests passed")
if stageOnly then
	print(`staged and tested saved version {versionId}; nothing published`)
end
if testOnly or stageOnly then
	process.exit(0)
end

publish(Receipt.verify(placeFile, universeId, placeId))
process.exit(0)
