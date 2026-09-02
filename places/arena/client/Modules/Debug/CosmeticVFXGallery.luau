--!strict

-- Studio-only world gallery for replaying, comparing, and stress-testing
-- registered script cosmetic effects with live runtime counts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Debug"))
local Cosmetics = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics")
local CosmeticEffectFactory = require(Cosmetics:WaitForChild("CosmeticEffectFactory"))
local Effects = Cosmetics:WaitForChild("Effects")
local Runtime = require(Effects:WaitForChild("Runtime"))
local ScriptEffects = require(Effects:WaitForChild("ScriptEffects"))

local CosmeticVFXGallery = {}

local FOLDER_NAME = "CosmeticVFXGallery"
local RANDOM_SPREAD = 4
local RAPID_COUNT = 10
local RAPID_INTERVAL = 0.06

local started = false
local generation = 0
local connections: { RBXScriptConnection } = {}
local disconnectStats: (() -> ())? = nil

local function enabled(): boolean
	return Debug.CosmeticVFXGallery == true and RunService:IsStudio()
end

local function newValue(className: string, name: string, value: any, parent: Instance): ValueBase
	local instance = Instance.new(className)
	assert(instance:IsA("ValueBase"), `[CosmeticVFXGallery] {className} must be a ValueBase`)
	instance.Name = name
	local writable: any = instance
	writable.Value = value
	instance.Parent = parent
	return instance
end

local function defaultPosition(): Vector3
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return Vector3.new(0, 8, 0)
	end
	return camera.CFrame.Position + camera.CFrame.LookVector * 18
end

local function makeTarget(parent: Instance, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "PreviewTarget"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = Color3.fromRGB(97, 255, 237)
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 0.65
	part.Transparency = 0.35
	part.Position = position
	part.Parent = parent
	return part
end

local function directionOf(value: Vector3): Vector3?
	return if value.Magnitude > 1e-5 then value.Unit else nil
end

-- A resolvable effect id is either a registered script effect or a
-- Studio-authored template under the Impact folder; existence is a legitimate
-- unknown here (typed by hand), so FindFirstChild is the right check.
local function impactTemplateExists(effectId: string): boolean
	local node: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Cosmetics", "Effects", "Impact" } do
		node = if node then node:FindFirstChild(name) else nil
	end
	return node ~= nil and node:FindFirstChild(effectId) ~= nil
end

local function play(effectId: string, position: Vector3, direction: Vector3, scale: number)
	if ScriptEffects.get(effectId) == nil and not impactTemplateExists(effectId) then
		warn(`[CosmeticVFXGallery] unknown effect {effectId} — not a script effect or an Impact template`)
		return
	end
	CosmeticEffectFactory.play("Impact", effectId, {
		position = position,
		direction = directionOf(direction),
		scale = scale,
	})
end

function CosmeticVFXGallery.start()
	if started or not enabled() then
		return
	end
	started = true

	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute(
		"Instructions",
		"Set EffectId, Scale, Direction, and TargetPosition; toggle Play, RapidTest, SideBySide, or StressTest true."
	)
	folder.Parent = Workspace

	local position = newValue("Vector3Value", "TargetPosition", defaultPosition(), folder) :: Vector3Value
	local direction = newValue("Vector3Value", "Direction", Vector3.new(0, 0, -1), folder) :: Vector3Value
	local scale = newValue("NumberValue", "Scale", 1, folder) :: NumberValue
	local effectId = newValue("StringValue", "EffectId", "StarPop", folder) :: StringValue
	local playTrigger = newValue("BoolValue", "Play", false, folder) :: BoolValue
	local rapidTrigger = newValue("BoolValue", "RapidTest", false, folder) :: BoolValue
	local sideBySideTrigger = newValue("BoolValue", "SideBySide", false, folder) :: BoolValue
	local stressCount = newValue("IntValue", "StressCount", 40, folder) :: IntValue
	local stressTrigger = newValue("BoolValue", "StressTest", false, folder) :: BoolValue
	local activeCount = newValue("IntValue", "ActiveAnimationCount", 0, folder) :: IntValue
	local instanceCount = newValue("IntValue", "TemporaryInstanceCount", 0, folder) :: IntValue
	local loopActive = newValue("BoolValue", "UpdateLoopActive", false, folder) :: BoolValue
	local target = makeTarget(folder, position.Value)

	local effectList = Instance.new("Folder")
	effectList.Name = "RegisteredEffects"
	effectList.Parent = folder
	for index, id in ScriptEffects.ids() do
		newValue("StringValue", string.format("%02d_%s", index, id), id, effectList)
	end

	disconnectStats = Runtime.observeStats(function(stats)
		activeCount.Value = stats.activeAnimations
		instanceCount.Value = stats.temporaryInstances
		loopActive.Value = stats.updateLoopActive
	end)

	table.insert(
		connections,
		position.Changed:Connect(function(value)
			target.Position = value
		end)
	)
	table.insert(
		connections,
		playTrigger.Changed:Connect(function(value)
			if not value then
				return
			end
			playTrigger.Value = false
			play(effectId.Value, position.Value, direction.Value, scale.Value)
		end)
	)
	table.insert(
		connections,
		rapidTrigger.Changed:Connect(function(value)
			if not value then
				return
			end
			rapidTrigger.Value = false
			generation += 1
			local currentGeneration = generation
			task.spawn(function()
				for _ = 1, RAPID_COUNT do
					if currentGeneration ~= generation or folder.Parent == nil then
						return
					end
					play(effectId.Value, position.Value, direction.Value, scale.Value)
					task.wait(RAPID_INTERVAL)
				end
			end)
		end)
	)
	table.insert(
		connections,
		sideBySideTrigger.Changed:Connect(function(value)
			if not value then
				return
			end
			sideBySideTrigger.Value = false
			local ids = ScriptEffects.productionIds()
			local columns = 4
			local rows = math.ceil(#ids / columns)
			local camera = Workspace.CurrentCamera
			local right = if camera then camera.CFrame.RightVector else Vector3.xAxis
			local up = Vector3.yAxis
			local spacing = 28 * math.clamp(scale.Value, 0.5, 1.5)
			for index, id in ids do
				local column = (index - 1) % columns
				local row = math.floor((index - 1) / columns)
				local rowCount = math.min(columns, #ids - row * columns)
				local offset = right * (column - (rowCount - 1) / 2) * spacing + up * ((rows - 1) / 2 - row) * spacing
				play(id, position.Value + offset, direction.Value, scale.Value)
			end
		end)
	)
	table.insert(
		connections,
		stressTrigger.Changed:Connect(function(value)
			if not value then
				return
			end
			stressTrigger.Value = false
			generation += 1
			local currentGeneration = generation
			local count = math.clamp(stressCount.Value, 1, 50)
			local random = Random.new()
			local ids = ScriptEffects.productionIds()
			task.spawn(function()
				for index = 1, count do
					if currentGeneration ~= generation or folder.Parent == nil then
						return
					end
					local offset = Vector3.new(
						random:NextNumber(-RANDOM_SPREAD, RANDOM_SPREAD),
						random:NextNumber(-RANDOM_SPREAD * 0.35, RANDOM_SPREAD * 0.35),
						random:NextNumber(-RANDOM_SPREAD, RANDOM_SPREAD)
					)
					play(ids[(index - 1) % #ids + 1], position.Value + offset, direction.Value, scale.Value)
					if index % 5 == 0 then
						task.wait()
					end
				end
			end)
		end)
	)

	print(
		"[CosmeticVFXGallery] Controls are under Workspace.CosmeticVFXGallery. "
			.. "Set values, then toggle a test BoolValue true."
	)
end

script.Destroying:Connect(function()
	generation += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	if disconnectStats ~= nil then
		disconnectStats()
	end
end)

return CosmeticVFXGallery
