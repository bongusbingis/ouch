--!strict

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local AimDirector = require(script.Parent.AimDirector)
local ModeVoteClient = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("ModeVoteClient"))
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

-- Client side of the input layer. Hardware actions are handled by their
-- InputBindings; the router feeds aim each frame and exposes touch catch for
-- the next HUD without owning any UI.

local InputRouter = {}

local started = false
local modeVoteOpen = false
local connections: { any } = {}

-- Mouse lock, cursor visibility and the shoulder offset all belong to
-- PlayerModule.Combat now. This used to write UserInputService directly, which
-- fought CameraUtils inside the camera stack -- two owners writing the same
-- property every frame. All that is left here is telling Combat when a menu
-- needs the pointer.
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
	table.insert(
		connections,
		ModeVoteClient.subscribe(function(snapshot)
			modeVoteOpen = snapshot.admitted and snapshot.open
			updateCursorOwnership()
		end)
	)
	updateCursorOwnership()

	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			updateCursorOwnership()
			AimDirector.update()
			aimBinding:Fire(AimDirector.currentAim())
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
	Combat.releaseCursor("ModeVote")
	started = false
end

return InputRouter
