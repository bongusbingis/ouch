-- Description: Wraps a cloud store call with the configured retry and backoff policy so transient failures do not surface as matchmaking errors.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))

local CloudRetry = {}
local random = Random.new()

function CloudRetry.call(label, callback)
	local lastError

	for attempt = 1, Config.CloudRetryAttempts do
		local results = table.pack(pcall(callback))
		if results[1] then
			return true, table.unpack(results, 2, results.n)
		end

		lastError = results[2]
		if attempt < Config.CloudRetryAttempts then
			local delay = math.min(Config.CloudRetryBaseDelay * 2 ^ (attempt - 1), Config.CloudRetryMaximumDelay)
			task.wait(delay + random:NextNumber(0, delay * 0.25))
		end
	end

	warn(("[%s] %s"):format(label, tostring(lastError)))
	return false, lastError
end

return CloudRetry
