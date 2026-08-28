-- Name: CmdrService.luau
-- Author: Jack C.
-- Description: Installs the Cmdr developer console for a place, registering that place's commands and argument types and restricting who may open it based on the environment configuration.
-- Created: 2026-07-15

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Env = require(script.Parent.Parent.Env)

local CmdrService = {}

local ACCESS_ATTRIBUTE = "CmdrAccess"
local READY_ATTRIBUTE = "SplatBrawlReady"
local started = false

local function canUse(player: Player): boolean
	local config = Env.Cmdr
	if not config.Enabled then
		return false
	end
	if config.AllowStudio and RunService:IsStudio() then
		return true
	end
	if config.AllowCreator and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return config.UserIds[player.UserId] == true
end

local function shouldInitialize(): boolean
	local config = Env.Cmdr
	local creatorAccess = config.AllowCreator and game.CreatorType == Enum.CreatorType.User
	return config.Enabled
		and ((config.AllowStudio and RunService:IsStudio()) or creatorAccess or next(config.UserIds) ~= nil)
end

function CmdrService.start()
	if started then
		return
	end
	started = true

	local initialize = shouldInitialize()
	local ready = false
	Players.PlayerAdded:Connect(function(player)
		if ready or not initialize then
			player:SetAttribute(ACCESS_ATTRIBUTE, canUse(player))
		end
	end)

	if not initialize then
		for _, player in Players:GetPlayers() do
			player:SetAttribute(ACCESS_ATTRIBUTE, false)
		end
		return
	end

	local cmdr = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("cmdr"))
	cmdr.Registry:RegisterHook("BeforeRun", function(context)
		if not canUse(context.Executor) then
			return "You do not have access to developer commands."
		end
		return nil
	end)

	local root = script.Parent.Parent:WaitForChild("Cmdr")
	-- A place whose commands use only Cmdr's built-in argument types ships no
	-- Types folder, so its absence is legitimate rather than a setup problem.
	local types = root:FindFirstChild("Types")
	if types then
		cmdr:RegisterTypesIn(types)
	end
	cmdr:RegisterCommandsIn(root:WaitForChild("Commands"))
	cmdr:RegisterDefaultCommands({ "Help" })
	cmdr.ReplicatedRoot:SetAttribute(READY_ATTRIBUTE, true)

	ready = true
	for _, player in Players:GetPlayers() do
		player:SetAttribute(ACCESS_ATTRIBUTE, canUse(player))
	end
end

return CmdrService
