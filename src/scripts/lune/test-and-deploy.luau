--!strict

-- Save → test → publish, gated on the cloud test suite:
--   1. uploads the merged place as a Saved (unpublished) version,
--   2. runs the TestEZ suite via the Open Cloud Luau Execution API against
--      that exact version (rbxcloud CLI does the API calls),
--   3. publishes the same artifact only when the suite is green.
-- With --test-only, skips both uploads and runs the suite against the current
-- version of the place.
-- Usage (from repo root):
--   lune run src/scripts/lune/test-and-deploy.luau <place.rbxl> <task-script.luau> [--test-only]
-- Env: ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID, ROBLOX_PLACE_ID
-- Exit codes: 0 = tests green (and published unless --test-only);
--             1 = tests failed or a step errored (nothing published);
--             2 = Open Cloud busy/rate-limited after retries (nothing published).

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local POLL_SECONDS = 3
local CREATE_RETRIES = 5
local CREATE_RETRY_SECONDS = 20

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
if #args < 2 or #args > 3 or (args[3] ~= nil and args[3] ~= "--test-only") then
	fail(1, "usage: lune run src/scripts/lune/test-and-deploy.luau <place.rbxl> <task-script.luau> [--test-only]")
end
local placeFile, taskFile = args[1], args[2]
local testOnly = args[3] == "--test-only"

if not testOnly and not fs.isFile(placeFile) then
	fail(1, `missing place file: {placeFile}`)
end
if not fs.isFile(taskFile) then
	fail(1, `missing task script: {taskFile}`)
end

local apiKey = requireEnv("ROBLOX_API_KEY")
local universeId = requireEnv("ROBLOX_UNIVERSE_ID")
local placeId = requireEnv("ROBLOX_PLACE_ID")

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
		fail(1, `{context}: could not parse rbxcloud output as JSON:\n{stdout}`)
	end
	return decoded :: any
end

local function looksBusy(stderr: string): boolean
	local lowered = string.lower(stderr)
	return string.find(lowered, "429", 1, true) ~= nil
		or string.find(lowered, "too many", 1, true) ~= nil
		or string.find(lowered, "rate limit", 1, true) ~= nil
end

local function upload(versionType: string): string
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

type TaskLocator = {
	versionId: string?,
	sessionId: string,
	taskId: string,
}

local function locatorFromPath(taskPath: string): TaskLocator
	local versionId = string.match(taskPath, "places/[^/]+/versions/([^/]+)/luau%-execution%-sessions/")
	local sessionId, taskId = string.match(taskPath, "luau%-execution%-sessions/([^/]+)/tasks/([^/]+)")
	if sessionId == nil or taskId == nil then
		fail(1, `could not parse session/task ids from task path: {taskPath}`)
	end
	return {
		versionId = versionId,
		sessionId = sessionId :: string,
		taskId = taskId :: string,
	}
end

local function taskCommand(command: string, locator: TaskLocator): { string }
	local commandArgs = {
		"luau",
		command,
		"--universe-id",
		universeId,
		"--place-id",
		placeId,
		"--session-id",
		locator.sessionId,
		"--task-id",
		locator.taskId,
	}
	if locator.versionId then
		table.insert(commandArgs, "--version-id")
		table.insert(commandArgs, locator.versionId)
	end
	return commandArgs
end

local function pollTask(locator: TaskLocator): { [string]: any }
	while true do
		local ok, stdout, stderr = rbxcloud(taskCommand("get-task", locator))
		if not ok then
			fail(1, `task poll failed:\n{stderr}\n{stdout}`)
		end
		local taskInfo = decodeJson(stdout, "task poll")
		local state = taskInfo.state
		if state ~= "QUEUED" and state ~= "PROCESSING" then
			return taskInfo
		end
		task.wait(POLL_SECONDS)
	end
end

local function printLogs(locator: TaskLocator)
	local commandArgs = taskCommand("get-logs", locator)
	table.insert(commandArgs, "--view")
	table.insert(commandArgs, "flat")
	local ok, stdout, stderr = rbxcloud(commandArgs)
	if not ok then
		print(`warning: could not fetch task logs:\n{stderr}`)
		return
	end
	local logs = decodeJson(stdout, "task logs")
	print("---- cloud test logs ----")
	for _, page in (logs.luauExecutionSessionTaskLogs or {}) :: { any } do
		for _, message in (page.messages or {}) :: { any } do
			print(message)
		end
	end
	print("---- end cloud test logs ----")
end

local versionId: string? = nil
if testOnly then
	print("running cloud tests against the current place version (--test-only)")
else
	versionId = upload("saved")
end

print("creating Luau execution task...")
local createdTask = createTask(versionId)
local taskPath = createdTask.path
if typeof(taskPath) ~= "string" then
	fail(1, `task creation returned no path:\n{serde.encode("json", createdTask)}`)
end
print(`task created: {taskPath}`)

local taskLocator = locatorFromPath(taskPath :: string)
local finishedTask = pollTask(taskLocator)
printLogs(taskLocator)

local state = finishedTask.state
if state ~= "COMPLETE" then
	if finishedTask.error then
		print(`task error: {serde.encode("json", finishedTask.error)}`)
	end
	fail(1, `cloud tests did not pass (task state: {tostring(state)}); nothing was published`)
end

print("cloud tests passed")
if testOnly then
	process.exit(0)
end

upload("published")
print("published")
process.exit(0)
