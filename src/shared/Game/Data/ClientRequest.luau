-- Bounds client requests; timed-out responses cannot resume the caller or mutate its projection.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("ClientRequests"))

return function(callback: (...any) -> ...any, ...: any): (boolean, ...any)
	local arguments = table.pack(...)
	local result: any = nil
	local worker = task.spawn(function()
		result = table.pack(pcall(callback, table.unpack(arguments, 1, arguments.n)))
	end)
	local timeout = task.delay(Config.TimeoutSeconds, function()
		if result == nil then
			result = table.pack(false, "request_timed_out")
			if coroutine.status(worker) ~= "dead" then
				task.cancel(worker)
			end
		end
	end)
	while result == nil do
		task.wait()
	end
	if coroutine.status(timeout) ~= "dead" then
		task.cancel(timeout)
	end
	return table.unpack(result, 1, result.n)
end
