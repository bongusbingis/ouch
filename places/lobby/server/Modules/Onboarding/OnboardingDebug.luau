-- Name: OnboardingDebug.luau
-- Author: Jack C.
-- Description: The one implementation behind every onboarding developer command — force, reset, jump to a step, mark core complete, finish — guarded so it can never touch a real player's stored progression outside Studio or an allowlisted developer.
-- Created: 2026-08-27

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Onboarding = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Onboarding")
local OnboardingState = require(Onboarding:WaitForChild("OnboardingState"))
local OnboardingSteps = require(Onboarding:WaitForChild("OnboardingSteps"))
local OnboardingConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Onboarding"))

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Env = require(script.Parent.Parent.Parent:WaitForChild("Env"))
local OnboardingService = require(script.Parent:WaitForChild("OnboardingService"))

local OnboardingDebug = {}

local BINDABLE_NAME = "OnboardingDebug"
local started = false

-- Debug commands rewrite persisted progression, so the gate is the same one the
-- developer console uses and is checked on every call rather than at install.
local function allowed(player: Player?): boolean
	local config = Env.Cmdr
	if not config.Enabled then
		return false
	end
	if config.AllowStudio and RunService:IsStudio() then
		return true
	end
	if player == nil then
		return false
	end
	if config.AllowCreator and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return config.UserIds[player.UserId] == true
end

local function resolve(target: Player | string | nil): Player?
	if typeof(target) == "Instance" and target:IsA("Player") then
		return target
	end
	if typeof(target) == "string" then
		for _, player in Players:GetPlayers() do
			if player.Name == target then
				return player
			end
		end
	end
	return nil
end

local COMMANDS: { [string]: (Player, any) -> string } = {
	-- Wipes stored onboarding progress so the next join is a brand-new player.
	Reset = function(player)
		PlayerData.updateOnboarding(player, function(state)
			local reset = table.clone(state)
			reset.Status = "NotStarted"
			reset.Checkpoint = ""
			reset.SkippedAt = ""
			reset.Sessions = 0
			reset.Version = OnboardingConfig.Version
			return reset
		end)
		OnboardingService.forceEnd(player, "Error")
		return `onboarding reset for {player.Name}`
	end,

	-- Starts a session now, whatever the stored status says.
	Force = function(player)
		OnboardingService.forceEnd(player, "Error")
		local ok = OnboardingService.replay(player)
		return if ok then `onboarding started for {player.Name}` else `could not start onboarding for {player.Name}`
	end,

	-- Jumps a running session to a named step without touching what is stored.
	StartAt = function(player, stepId)
		if not OnboardingSteps.isStep(stepId) then
			return `unknown step "{tostring(stepId)}"`
		end
		if not OnboardingService.isTraining(player) then
			OnboardingService.replay(player)
		end
		local ok = OnboardingService.forceStep(player, stepId)
		return if ok then `{player.Name} moved to {stepId}` else `{player.Name} is not in a training session`
	end,

	MarkCoreComplete = function(player)
		local last = OnboardingSteps.lastCore()
		PlayerData.updateOnboarding(player, function(state)
			return OnboardingState.completeStep(state, last.Id)
		end)
		return `{player.Name} marked CoreComplete`
	end,

	MarkCompleted = function(player)
		PlayerData.updateOnboarding(player, OnboardingState.complete)
		OnboardingService.forceEnd(player, "Completed")
		return `{player.Name} marked Completed`
	end,

	MarkSkipped = function(player, stepId)
		PlayerData.updateOnboarding(player, function(state)
			return OnboardingState.skip(state, if OnboardingSteps.isStep(stepId) then stepId else nil)
		end)
		OnboardingService.forceEnd(player, "Skipped")
		return `{player.Name} marked Skipped`
	end,

	Finish = function(player)
		OnboardingService.forceEnd(player, "Completed")
		return `{player.Name} released to the lobby`
	end,

	Status = function(player)
		local stored = PlayerData.getOnboarding(player)
		local session = OnboardingService.stateFor(player)
		if stored == nil then
			return `{player.Name}: profile not loaded`
		end
		local live = if session then `step={session.stepId} attempts={session.attempts}` else "no active session"
		return `{player.Name}: status={stored.Status} checkpoint={stored.Checkpoint ~= "" and stored.Checkpoint or "none"} version={stored.Version} | {live}`
	end,
}

function OnboardingDebug.run(executor: Player?, command: string, target: Player | string | nil, argument: any): string
	if not allowed(executor) then
		return "onboarding debug commands are not available here"
	end
	local handler = COMMANDS[command]
	if handler == nil then
		return `unknown onboarding debug command "{tostring(command)}"`
	end
	local player = resolve(target) or executor
	if player == nil then
		return "no target player"
	end
	return handler(player, argument)
end

function OnboardingDebug.commands(): { string }
	local names = {}
	for name in COMMANDS do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- A second front door for the same commands, so onboarding can be re-tested
-- from the Studio command bar in a place that has no developer console yet:
--   require(game.ServerStorage.OnboardingDebug):Invoke("StartAt", nil, "Hammer")
function OnboardingDebug.start()
	if started or not RunService:IsStudio() then
		return
	end
	started = true
	local bindable = Instance.new("BindableFunction")
	bindable.Name = BINDABLE_NAME
	bindable.OnInvoke = function(command, target, argument)
		local player = resolve(target) or Players:GetPlayers()[1]
		return OnboardingDebug.run(player, command, player, argument)
	end
	bindable.Parent = ServerStorage
end

return OnboardingDebug
