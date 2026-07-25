--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local AimDirector = require(script.Parent.AimDirector)

-- Client side of the input layer. Hardware actions are handled by their
-- InputBindings; the router feeds AimDirector's aim into the Aim action every
-- frame, pulses touch Throw and Catch controls, and reports
-- the device class to the server.

local InputRouter = {}

local TAP_PULSE_SECONDS = 0.1

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
	local catchFeed = context:WaitForChild("Catch"):WaitForChild("TouchFeed") :: InputBinding
	local catchButton = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Hud"):WaitForChild("CatchButton")
	assert(catchButton:IsA("ImageButton"), "[InputRouter] Hud.CatchButton must be an ImageButton")
	local matchState = ReplicatedStorage:WaitForChild("MatchState")
	assert(matchState:IsA("Folder"), "[InputRouter] ReplicatedStorage.MatchState must be a Folder")

	local generations = { Throw = 0, Catch = 0 }
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

	local function updateVisibility()
		catchButton.Visible = AimDirector.deviceClass() == "Touch" and matchState:GetAttribute("phase") == "Active"
	end
	UserInputService.LastInputTypeChanged:Connect(updateVisibility)
	matchState:GetAttributeChangedSignal("phase"):Connect(updateVisibility)
	updateVisibility()

	catchButton.Activated:Connect(function()
		if AimDirector.deviceClass() == "Touch" then
			pulse("Catch", catchFeed)
		end
	end)
	UserInputService.TouchTap:Connect(function(_positions, gameProcessedEvent)
		if gameProcessedEvent or AimDirector.deviceClass() ~= "Touch" then
			return
		end
		pulse("Throw", throwFeed)
	end)
end

function InputRouter.start()
	local player = Players.LocalPlayer
	local context = player:WaitForChild(InputConfig.ContextName)
	local aimAction = context:WaitForChild("Aim")
	local aimBinding = aimAction:WaitForChild("AimFeed") :: InputBinding

	reportDeviceClass()
	if UserInputService.TouchEnabled then
		bindTouchControls(context)
	end

	RunService.RenderStepped:Connect(function()
		AimDirector.update()
		aimBinding:Fire(AimDirector.currentAim())
	end)
end

return InputRouter
