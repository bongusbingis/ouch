--!strict
-- Short rising wind strokes make the authored fans readable without hiding opponents.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local MapFeatures = require(ReplicatedStorage.Config.Gameplay.MapFeatures)
local ScriptableRoots = require(ReplicatedStorage.Shared.Game.MapFeatures.ScriptableRoots)

local FanAirflow = {}

type Stroke = { first: Attachment, last: Attachment, beam: Beam, phase: number, x: number, z: number }
local fans: { [BasePart]: { Stroke } } = {}
local connections: { RBXScriptConnection } = {}
local rootConnections: { [Instance]: { RBXScriptConnection } } = {}
local unwatch: (() -> ())? = nil
local started = false

local function forget(instance: Instance)
	local strokes = fans[instance :: BasePart]
	if strokes == nil then
		return
	end
	fans[instance :: BasePart] = nil
	for _, stroke in strokes do
		stroke.beam:Destroy()
		stroke.first:Destroy()
		stroke.last:Destroy()
	end
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
	local strokes = {}
	fans[instance] = strokes
	for index = 1, 4 do
		local first = Instance.new("Attachment")
		first.Name = "FanWindStart"
		first.Parent = instance
		local last = Instance.new("Attachment")
		last.Name = "FanWindEnd"
		last.Parent = instance
		local beam = Instance.new("Beam")
		beam.Name = "FanWind"
		beam.Attachment0 = first
		beam.Attachment1 = last
		beam.FaceCamera = true
		beam.Width0 = 0.18
		beam.Width1 = 0.08
		beam.Segments = 8
		beam.CurveSize0 = 1.8
		beam.CurveSize1 = 1.2
		beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.35),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.LightEmission = 0.4
		beam.Parent = first
		local angle = index * math.pi / 2
		table.insert(strokes, {
			first = first,
			last = last,
			beam = beam,
			phase = index / 4,
			x = math.cos(angle) * 3.5,
			z = math.sin(angle) * 3.5,
		})
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for base, strokes in fans do
		if base.Parent == nil then
			forget(base)
			continue
		end
		local top = base.Size.Y / 2 + 0.5
		for _, stroke in strokes do
			local rise = ((now * 0.65 + stroke.phase) % 1) * 7
			local start = Vector3.new(stroke.x, top + rise, stroke.z)
			local finish = start + Vector3.new(0.75, 3, 0)
			stroke.first.CFrame = CFrame.fromMatrix(start, Vector3.yAxis, Vector3.xAxis)
			stroke.last.CFrame = CFrame.fromMatrix(finish, Vector3.yAxis, Vector3.xAxis)
		end
	end
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
	table.insert(connections, RunService.RenderStepped:Connect(step))
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
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for base in fans do
		forget(base)
	end
end

return FanAirflow
