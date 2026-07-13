--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))

-- Client side of the input layer. Hardware actions (Throw/Recall) are handled
-- entirely by their InputBindings; the router's only job is feeding continuous
-- camera aim into the Aim action's scriptable binding every frame so the
-- engine replicates and replays it on the simulation timeline.

local InputRouter = {}

function InputRouter.start()
	local player = Players.LocalPlayer
	local context = player:WaitForChild(InputConfig.ContextName)
	local aimAction = context:WaitForChild("Aim")
	local aimBinding = aimAction:WaitForChild("AimFeed") :: InputBinding

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera then
			aimBinding:Fire(camera.CFrame.LookVector)
		end
	end)
end

return InputRouter
