-- Name: InputRouter.luau
-- Author: Jack C.
-- Description: Feeds the aim vector into the Aim input action every frame, reports the player's device class to the server, and resets the aim director when combat goes inactive.
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
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local InputRouter = {}

local started = false
local combatWasActive = false
local connections: { any } = {}

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
		RunService.RenderStepped:Connect(function()
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
	combatWasActive = false
	AimDirector.reset()
	started = false
end

return InputRouter
