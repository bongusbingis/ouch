--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local AimDirector = require(Client:WaitForChild("Modules"):WaitForChild("Input"):WaitForChild("AimDirector"))

-- Pure renderer: AimDirector owns target selection; the highlight shows only
-- while the local player is holding a ball to throw.

local TargetingUI = {}

local highlight = Instance.new("Highlight")
highlight.Name = "DodgeballTarget"
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.FillTransparency = 0.88
highlight.OutlineTransparency = 0.25
highlight.Enabled = false

local function holdingBall(): boolean
	local balls = Workspace:FindFirstChild("Balls")
	if balls == nil then
		return false
	end
	local localId = tostring(Players.LocalPlayer.UserId)
	for _, ball in balls:GetChildren() do
		if ball:GetAttribute("hb") == localId then
			return true
		end
	end
	return false
end

function TargetingUI.start()
	highlight.Parent = Workspace.CurrentCamera
	RunService.RenderStepped:Connect(function()
		local target = AimDirector.currentTarget()
		if target == nil or not holdingBall() then
			highlight.Enabled = false
			highlight.Adornee = nil
			return
		end
		highlight.Adornee = target
		highlight.Enabled = true
	end)
end

return TargetingUI
