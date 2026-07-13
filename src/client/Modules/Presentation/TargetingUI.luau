--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AimAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AimAssist"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))

local TargetingUI = {}

local highlight = Instance.new("Highlight")
highlight.Name = "DodgeballTarget"
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.FillTransparency = 0.88
highlight.OutlineTransparency = 0.25
highlight.Enabled = false

function TargetingUI.start()
	highlight.Parent = Workspace.CurrentCamera
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		if camera == nil or character == nil then
			highlight.Enabled = false
			return
		end
		local balls = Workspace:FindFirstChild("Balls")
		local hasBall = false
		if balls then
			for _, ball in balls:GetChildren() do
				if ball:GetAttribute("hb") == tostring(Players.LocalPlayer.UserId) then
					hasBall = true
					break
				end
			end
		end
		if not hasBall then
			highlight.Enabled = false
			return
		end
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { character, balls :: any }
		rayParams.RespectCanCollide = true

		local best: Model? = nil
		local bestAngle = math.huge
		local look = camera.CFrame.LookVector
		for _, player in Players:GetPlayers() do
			if player == Players.LocalPlayer or player.Character == nil then
				continue
			end
			local root = player.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
				continue
			end
			local offset = root.Position - camera.CFrame.Position
			local distance = offset.Magnitude
			if distance <= 0 or distance > Combat.Dodgeball.TargetSelectRange then
				continue
			end
			local angle = math.deg(math.acos(math.clamp(look:Dot(offset.Unit), -1, 1)))
			local obstruction = Workspace:Raycast(camera.CFrame.Position, offset, rayParams)
			local visible = obstruction == nil or obstruction.Instance:IsDescendantOf(player.Character)
			if visible and angle <= AimAssist.Mouse.SelectionConeDeg and angle < bestAngle then
				best = player.Character
				bestAngle = angle
			end
		end
		highlight.Adornee = best
		highlight.Enabled = best ~= nil
	end)
end

return TargetingUI
