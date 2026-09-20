-- Description: Hidden tap-corner gesture that asks the server to end the active match with the local player as winner, for exercising the full match and post-match loop solo. The server re-checks the same developer group rank the lobby's solo-play path uses.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Debug"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local DevMatchSkip = {}

local started = false
local tapCount = 0
local lastTapAt = 0
local inputConnection: RBXScriptConnection? = nil

local function config()
	return Debug.DevMatchSkip
end

local function inTopRightCorner(position: Vector2): boolean
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return false
	end
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return false
	end
	local scale = config().CornerScale
	return position.X >= viewport.X * (1 - scale) and position.Y <= viewport.Y * scale
end

local function onInputBegan(input: InputObject)
	local cfg = config()
	if not cfg.Enabled then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if not inTopRightCorner(Vector2.new(input.Position.X, input.Position.Y)) then
		return
	end

	local now = os.clock()
	if now - lastTapAt > cfg.TapWindowSeconds then
		tapCount = 0
	end
	lastTapAt = now
	tapCount += 1

	if tapCount >= cfg.TapCount then
		tapCount = 0
		Network.fireServer("DevEndMatch")
	end
end

function DevMatchSkip.start()
	if started or not RunService:IsStudio() then
		return
	end
	started = true

	inputConnection = UserInputService.InputBegan:Connect(onInputBegan)
end

function DevMatchSkip.stop()
	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
	started = false
	tapCount = 0
end

return DevMatchSkip
