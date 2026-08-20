--!strict

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local AimDirector = require(script.Parent.AimDirector)
local PlayerIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("PlayerIds")
)
local TouchInput = require(script.Parent.TouchInput)

-- Client side of the input layer. Hardware actions are handled by their
-- InputBindings; the router feeds aim each frame and exposes touch catch for
-- the next HUD without owning any UI.

local InputRouter = {}

local TAP_PULSE_SECONDS = 0.1
local touchCatchFeed: InputBinding? = nil
local generations = { Throw = 0, Catch = 0 }
local modeVoteState: Folder? = nil

-- AimDirector works in characters; the rest of the stack works in sim player
-- ids, so the translation happens once, here, through the owner of that
-- convention.
local function targetIdOf(target: Model?): string?
	if target == nil then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(target)
	return if player then PlayerIds.toId(player) else nil
end

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
	-- Only the catch feed remains here. Touch throws now arrive as classified
	-- gestures from TouchInput, which can tell a tap from a camera drag and can
	-- carry a tapped target; TouchTap could do neither.
	touchCatchFeed = context:WaitForChild("Catch"):WaitForChild("TouchFeed") :: InputBinding
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
		TouchInput.setLockedTarget(targetIdOf(AimDirector.currentTarget()), AimDirector.currentConfidence())
	end)
end

return InputRouter
