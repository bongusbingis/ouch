-- Name: InputRouter.luau
-- Author: Jack C.
-- Description: Feeds the aim vector into the Aim input action every frame, pulses the Throw action on touch taps, reports the player's device class to the server, and owns whether the mouse cursor is released for menus.
-- Created: 2026-07-12

--!strict

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local AimDirector = require(script.Parent.AimDirector)
-- The mode ballot is arena-only, and this module is shared by both places, so a
-- missing ModeVoteClient in the lobby is expected rather than a missing asset.
local uiModules = script.Parent.Parent:FindFirstChild("UI")
local modeVoteModule = if uiModules then uiModules:FindFirstChild("ModeVoteClient") else nil
local ModeVoteClient = if modeVoteModule then require(modeVoteModule) :: any else nil
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local InputRouter = {}

local started = false
local modeVoteOpen = false
local combatWasActive = false
local connections: { any } = {}

local function updateCursorOwnership()
	if modeVoteOpen then
		Combat.requestCursor("ModeVote")
	else
		Combat.releaseCursor("ModeVote")
	end
end

local function reportDeviceClass()
	local reported: string? = nil
	local function report()
		local deviceClass = AimDirector.deviceClass()
		if deviceClass ~= reported then
			reported = deviceClass
			Network.fireServer("ReportDeviceClass", deviceClass)
		end
	end
	table.insert(connections, UserInputService.LastInputTypeChanged:Connect(report))
	report()
end

function InputRouter.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local context = player:WaitForChild(InputConfig.ContextName)
	local aimAction = context:WaitForChild("Aim")
	local aimBinding = aimAction:WaitForChild("AimFeed") :: InputBinding

	reportDeviceClass()
	if ModeVoteClient then
		table.insert(
			connections,
			ModeVoteClient.subscribe(function(snapshot)
				modeVoteOpen = snapshot.admitted and snapshot.open
				updateCursorOwnership()
			end)
		)
	end
	updateCursorOwnership()

	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			updateCursorOwnership()
			local combatActive = Combat.isActive()
			if combatActive then
				AimDirector.update()
				aimBinding:Fire(AimDirector.currentAim())
			elseif combatWasActive then
				AimDirector.reset()
			end
			combatWasActive = combatActive
		end)
	)
end

function InputRouter.destroy()
	for _, connection in connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		else
			connection()
		end
	end
	table.clear(connections)
	modeVoteOpen = false
	combatWasActive = false
	AimDirector.reset()
	Combat.releaseCursor("ModeVote")
	started = false
end

return InputRouter
