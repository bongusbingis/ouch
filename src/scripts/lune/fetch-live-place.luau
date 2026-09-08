-- Description: Downloads the currently published place file through Open Cloud's asset delivery API, resolving the signed CDN location and writing the resulting place bytes to disk.

--!strict

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local REQUEST_RETRIES = 5
local REQUEST_TIMEOUT_SECONDS = 30
local REQUEST_WATCH_SECONDS = 0.05
local RETRY_MAX_SECONDS = 15
local RETRYABLE_STATUS_CODES = {
	[429] = true,
	[500] = true,
	[502] = true,
	[503] = true,
	[504] = true,
}

local function fail(message: string): never
	print(`error: {message}`)
	return process.exit(1)
end

local function requireEnv(name: string): string
	local value = process.env[name]
	if value == nil or value == "" then
		fail(`environment variable {name} is required`)
	end
	return value :: string
end

local function requestWithTimeout(config: any): (boolean, any)
	local completed = false
	local requestOk = false
	local response: any = nil
	local worker = task.spawn(function()
		requestOk, response = pcall(function()
			return net.request(config)
		end)
		completed = true
	end)
	local deadline = os.clock() + REQUEST_TIMEOUT_SECONDS

	while not completed and os.clock() < deadline do
		task.wait(math.min(REQUEST_WATCH_SECONDS, math.max(deadline - os.clock(), 0)))
	end

	if not completed then
		pcall(function()
			task.cancel(worker)
		end)
		return false, `request timed out after {REQUEST_TIMEOUT_SECONDS}s`
	end
	return requestOk, response
end

local args = table.clone(process.args)
if args[1] == "--" then
	table.remove(args, 1)
end
if #args ~= 1 then
	fail("usage: lune run src/scripts/lune/fetch-live-place.luau <output.rbxl>")
end
local outputPath = args[1]

local apiKey = requireEnv("ROBLOX_API_KEY")
local placeId = requireEnv("ROBLOX_PLACE_ID")

local function getWithRetry(url: string, headers: { [string]: string }, context: string): string
	local lastError = "request failed"
	for attempt = 1, REQUEST_RETRIES do
		local ok, response = requestWithTimeout({
			url = url,
			method = "GET",
			headers = headers,
		})
		if ok and (response :: any).ok then
			return (response :: any).body
		end
		if ok then
			local statusCode = (response :: any).statusCode
			lastError =
				`http {tostring(statusCode)}: {tostring((response :: any).statusMessage)}\n{(response :: any).body}`
			if not RETRYABLE_STATUS_CODES[statusCode] then
				break
			end
		else
			lastError = tostring(response)
		end
		if attempt < REQUEST_RETRIES then
			local retrySeconds = math.min(2 ^ (attempt - 1), RETRY_MAX_SECONDS)
			print(`[{context}] attempt {attempt}/{REQUEST_RETRIES} failed ({lastError}); retrying in {retrySeconds}s`)
			task.wait(retrySeconds)
		end
	end
	return fail(`{context} failed after {REQUEST_RETRIES} attempts:\n{lastError}`)
end

print(`fetching live place metadata for place {placeId}...`)
local metadataBody = getWithRetry(`https://apis.roblox.com/asset-delivery-api/v1/assetId/{placeId}`, {
	["x-api-key"] = apiKey,
	Accept = "application/json",
}, "asset delivery metadata")

local ok, metadata = pcall(serde.decode, "json" :: any, metadataBody)
if not ok or typeof(metadata) ~= "table" then
	fail(`could not parse asset delivery response as JSON:\n{metadataBody}`)
end

local location = (metadata :: any).location
if typeof(location) ~= "string" then
	fail(`asset delivery response had no download location:\n{metadataBody}`)
end

print("downloading live place file...")
local placeBytes = getWithRetry(location :: string, {}, "place download")

fs.writeFile(outputPath, placeBytes)
print(`saved live place to {outputPath} ({#placeBytes} bytes)`)
process.exit(0)
