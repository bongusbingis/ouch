-- Runs cancellable refreshes; the caller retains ownership of its snapshot and rejects stale results.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("ClientRequests"))

return function(refresh: () -> boolean): () -> ()
	local active = true
	local worker = task.defer(function()
		local retrySeconds = Config.InitialRetrySeconds
		while active do
			local ok, refreshed = pcall(refresh)
			if not active then
				break
			end
			if ok and refreshed then
				retrySeconds = Config.InitialRetrySeconds
				task.wait(Config.RefreshSeconds)
			else
				task.wait(retrySeconds)
				retrySeconds = math.min(retrySeconds * 2, Config.MaxRetrySeconds)
			end
		end
	end)
	return function()
		active = false
		if coroutine.status(worker) ~= "dead" then
			task.cancel(worker)
		end
	end
end
