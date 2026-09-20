--!strict
-- Short rising wind particles make the authored fans readable without hiding opponents.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapFeatures = require(ReplicatedStorage.Config.Gameplay.MapFeatures)
local ScriptableRoots = require(ReplicatedStorage.Shared.Game.MapFeatures.ScriptableRoots)

local FanAirflow = {}

local fans: { [BasePart]: Attachment } = {}
local rootConnections: { [Instance]: { RBXScriptConnection } } = {}
local unwatch: (() -> ())? = nil
local started = false

local function forget(instance: Instance)
	local attachment = fans[instance :: BasePart]
	if attachment == nil then
		return
	end
	fans[instance :: BasePart] = nil
	attachment:Destroy()
end

local function isFan(instance: Instance): boolean
	return instance:IsA("BasePart")
		and (
			MapFeatures.Fan.EnabledNames[instance.Name] == true
			or instance:GetAttribute(MapFeatures.Attributes.Fan) == true
		)
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") or not isFan(instance) or fans[instance] then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "FanAirflowAttachment"
	attachment.Position = Vector3.new(0, instance.Size.Y / 2, 0)
	attachment.Parent = instance

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FanAirflowParticles"
	emitter.Speed = NumberRange.new(6, 8)
	emitter.Lifetime = NumberRange.new(0.8, 1.1)
	emitter.SpreadAngle = Vector2.new(6, 6)
	emitter.Rate = 5
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.4),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
	emitter.LightEmission = 0.4
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = attachment

	fans[instance] = attachment
end

local function addRoot(root: Instance)
	local list = {}
	rootConnections[root] = list
	table.insert(list, root.DescendantAdded:Connect(track))
	table.insert(list, root.DescendantRemoving:Connect(forget))
	for _, instance in root:GetDescendants() do
		track(instance)
	end
end

local function removeRoot(root: Instance)
	local list = rootConnections[root]
	if list then
		for _, connection in list do
			connection:Disconnect()
		end
		rootConnections[root] = nil
	end
	for base in fans do
		if base:IsDescendantOf(root) or base.Parent == nil then
			forget(base)
		end
	end
end

function FanAirflow.start()
	if started then
		return
	end
	started = true
	unwatch = ScriptableRoots.watch(addRoot, removeRoot)
end

function FanAirflow.stop()
	started = false
	if unwatch then
		unwatch()
		unwatch = nil
	end
	for root in rootConnections do
		removeRoot(root)
	end
	for base in fans do
		forget(base)
	end
end

return FanAirflow
