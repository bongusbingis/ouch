-- Description: Drives per-frame aim and soft-lock target selection while combat is active, reports the player's device class to the server, and owns whether the mouse cursor is released for the mode-vote menu.

--!strict

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local DeviceClass = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Input"):WaitForChild("DeviceClass")
)
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

function InputRouter.start()
	if started then
		return
	end
	started = true

	table.insert(
		connections,
		DeviceClass.observe(function(deviceClass)
			Network.fireServer("ReportDeviceClass", deviceClass)
		end)
	)

	local function reassertDeviceClass()
		local honest = DeviceClass.current()
		if Players.LocalPlayer:GetAttribute("DeviceClass") ~= honest then
			Network.fireServer("ReportDeviceClass", honest)
		end
	end
	table.insert(connections, Players.LocalPlayer:GetAttributeChangedSignal("DeviceClass"):Connect(reassertDeviceClass))

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
