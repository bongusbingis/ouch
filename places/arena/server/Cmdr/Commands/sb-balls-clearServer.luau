-- Description: Server implementation of sb-balls-clear, emptying the world balls folder through the ball service.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local BallService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("BallService"))

return function(_context: any): string
	BallService.clearAll()
	return "Cleared all active balls."
end
