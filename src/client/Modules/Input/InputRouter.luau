--!strict

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local AimDirector = require(script.Parent.AimDirector)

-- Client side of the input layer. Hardware actions are handled by their
-- InputBindings; the router feeds aim each frame and exposes touch catch for
-- the next HUD without owning any UI.

local InputRouter = {}

local TAP_PULSE_SECONDS = 0.1
local touchCatchFeed: InputBinding? = nil
local generations = { Throw = 0, Catch = 0 }
local modeVoteState: Folder? = nil

local function lockMouse()
	local voteState = modeVoteState
	local player = Players.LocalPlayer
	if voteState and voteState:GetAttribute("open") == true and player:GetAttribute("ArenaAdmission") ~= "Rejected" then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		return
	end
	if UserInputService.MouseEnabled and not GuiService.MenuIsOpen then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
end

local function pulse(name: "Throw" | "Catch", binding: InputBinding)
	generations[name] += 1
	local generation = generations[name]
	binding:Fire(true)
	task.delay(TAP_PULSE_SECONDS, function()
		if generations[name] == generation then
			binding:Fire(false)
		end
	end)
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

local function bindTouchControls(context: Instance)
	local throwFeed = context:WaitForChild("Throw"):WaitForChild("TouchFeed") :: InputBinding
	touchCatchFeed = context:WaitForChild("Catch"):WaitForChild("TouchFeed") :: InputBinding
	UserInputService.TouchTap:Connect(function(_positions, gameProcessedEvent)
		if gameProcessedEvent or AimDirector.deviceClass() ~= "Touch" then
			return
		end
		pulse("Throw", throwFeed)
	end)
end

function InputRouter.triggerTouchCatch(): boolean
	local feed = touchCatchFeed
	if feed == nil or AimDirector.deviceClass() ~= "Touch" then
		return false
	end
	pulse("Catch", feed)
	return true
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
	if UserInputService.TouchEnabled then
		bindTouchControls(context)
	end
	lockMouse()

	RunService.RenderStepped:Connect(function()
		lockMouse()
		AimDirector.update()
		aimBinding:Fire(AimDirector.currentAim())
	end)
end

return InputRouter
