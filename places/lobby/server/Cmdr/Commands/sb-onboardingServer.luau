-- Name: sb-onboardingServer.luau
-- Author: Jack C.
-- Description: Server implementation of sb-onboarding, forwarding to the single guarded OnboardingDebug implementation.
-- Created: 2026-08-27

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local OnboardingDebug = require(
	ServerScriptService:WaitForChild("Server")
		:WaitForChild("Modules")
		:WaitForChild("Onboarding")
		:WaitForChild("OnboardingDebug")
)

return function(context: any, command: string, player: Player, step: string?): string
	return OnboardingDebug.run(context.Executor, command, player, step)
end
