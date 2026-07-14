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
-- frame, pulses the Throw action on non-GUI screen taps (touch), and reports
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

	local pulseGeneration = 0
	UserInputService.TouchTap:Connect(function(_positions, gameProcessedEvent)
		if gameProcessedEvent or AimDirector.deviceClass() ~= "Touch" then
			return
		end
		pulseGeneration += 1
		local generation = pulseGeneration
		throwFeed:Fire(true)
		task.delay(TAP_PULSE_SECONDS, function()
			if pulseGeneration == generation then
				throwFeed:Fire(false)
			end
		end)
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
