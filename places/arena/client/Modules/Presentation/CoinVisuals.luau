-- Description: Cosmetic coin feedback: gently bobs and spins the server's tagged coin pickups, and on the server's CoinCollected plays the pickup sound and a floating "+N BONKS" pop where the coin was.

--!strict

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Audio = require(Config:WaitForChild("Infra"):WaitForChild("Audio"))
local CoinConfig = require(Config:WaitForChild("Gameplay"):WaitForChild("Coins"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local T = require(Shared:WaitForChild("UI"):WaitForChild("Tokens"))
local ClientAudio = require(script.Parent.ClientAudio)

local CoinVisuals = {}

local COIN_TAG = "Coin"
local BOB_HEIGHT = 0.6
local BOB_SPEED = 2.2
local SPIN_SPEED = 2.5
local POP_SECONDS = 0.9
local POP_RISE = 3

local started = false
local random = Random.new()
local tracked: { [Instance]: CFrame } = {}
local connections: { RBXScriptConnection } = {}

local function pivotOf(instance: Instance): CFrame?
	if instance:IsA("Model") then
		return instance:GetPivot()
	elseif instance:IsA("BasePart") then
		return instance.CFrame
	end
	return nil
end

local function track(instance: Instance)
	local pivot = pivotOf(instance)
	if pivot then
		tracked[instance] = pivot
	end
end

local function animate()
	if GuiService.ReducedMotionEnabled then
		return
	end
	local now = os.clock()
	for instance, base in tracked do
		local lift = Vector3.new(0, math.sin(now * BOB_SPEED + base.X) * BOB_HEIGHT, 0)
		local frame = CFrame.new(base.Position + lift) * CFrame.Angles(0, now * SPIN_SPEED, 0) * base.Rotation
		if instance:IsA("Model") then
			instance:PivotTo(frame)
		elseif instance:IsA("BasePart") then
			instance.CFrame = frame
		end
	end
end

local function playSound()
	local cue = (Audio.Gameplay :: any)[CoinConfig.SoundId]
	local ids = if type(cue) == "table" then cue.AssetIds else nil
	if type(ids) ~= "table" or #ids == 0 then
		return
	end
	local assetId = ids[random:NextInteger(1, #ids)]
	if type(assetId) ~= "string" or string.match(assetId, "^rbxassetid://%d+$") == nil then
		return
	end
	pcall(ClientAudio.play, { name = "CoinPickup", assetId = assetId, category = "Effects", volume = cue.Volume })
end

local function pop(position: Vector3, bonks: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 44)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = T.Type.Display
	label.TextScaled = true
	label.Text = `+{bonks} BONKS`
	label.TextColor3 = T.Colors.Gold
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = T.Colors.Ink
	stroke.Thickness = 2
	stroke.Parent = label
	anchor.Parent = Workspace
	Debris:AddItem(anchor, POP_SECONDS + 0.2)

	local info = TweenService:Create(label, TweenInfo.new(POP_SECONDS), { TextTransparency = 1 })
	TweenService:Create(stroke, TweenInfo.new(POP_SECONDS), { Transparency = 1 }):Play()
	info:Play()
	if not GuiService.ReducedMotionEnabled then
		TweenService:Create(
			anchor,
			TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = position + Vector3.new(0, POP_RISE, 0) }
		):Play()
	end
end

function CoinVisuals.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged(COIN_TAG) do
		track(instance)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(COIN_TAG):Connect(track))
	table.insert(
		connections,
		CollectionService:GetInstanceRemovedSignal(COIN_TAG):Connect(function(instance)
			tracked[instance] = nil
		end)
	)
	table.insert(connections, RunService.RenderStepped:Connect(animate))
	table.insert(
		connections,
		Network.on("CoinCollected", function(position, bonks)
			if typeof(position) ~= "Vector3" or type(bonks) ~= "number" then
				return
			end
			playSound()
			pop(position, bonks)
		end)
	)
end

return CoinVisuals
