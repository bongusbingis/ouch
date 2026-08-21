--!strict

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local AimDirector = require(script.Parent.AimDirector)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

-- Client side of the input layer. Hardware actions are handled by their
-- InputBindings; the router feeds aim each frame and exposes touch catch for
-- the next HUD without owning any UI.

local InputRouter = {}

local modeVoteState: Folder? = nil

-- Mouse lock, cursor visibility and the shoulder offset all belong to
-- PlayerModule.Combat now. This used to write UserInputService directly, which
-- fought CameraUtils inside the camera stack -- two owners writing the same
-- property every frame. All that is left here is telling Combat when a menu
-- needs the pointer.
local function updateCursorOwnership()
	local voteState = modeVoteState
	local player = Players.LocalPlayer
	local voting = voteState ~= nil
		and voteState:GetAttribute("open") == true
		and player:GetAttribute("ArenaAdmission") ~= "Rejected"

	if voting then
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
	UserInputService.LastInputTypeChanged:Connect(report)
	report()
end

function InputRouter.start()
	local player = Players.LocalPlayer
	local replicatedVoteState = ReplicatedStorage:WaitForChild("ModeVoteState")
	assert(replicatedVoteState:IsA("Folder"), "[InputRouter] ReplicatedStorage.ModeVoteState must be a Folder")
	modeVoteState = replicatedVoteState
	local context = player:WaitForChild(InputConfig.ContextName)
	local aimAction = context:WaitForChild("Aim")
	local aimBinding = aimAction:WaitForChild("AimFeed") :: InputBinding

	reportDeviceClass()
	updateCursorOwnership()

	RunService.RenderStepped:Connect(function()
		updateCursorOwnership()
		AimDirector.update()
		aimBinding:Fire(AimDirector.currentAim())
	end)
end

return InputRouter
