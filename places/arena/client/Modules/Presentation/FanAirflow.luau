--!strict
-- Short rising wind strokes make the authored fans readable without hiding opponents.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local MapFeatures = require(ReplicatedStorage.Config.Gameplay.MapFeatures)

local FanAirflow = {}

type Stroke = { first: Attachment, last: Attachment, beam: Beam, phase: number, x: number, z: number }
local fans: { [BasePart]: { Stroke } } = {}
local connections: { RBXScriptConnection } = {}
local started = false
local generation = 0

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

local function track(instance: Instance)
	if not instance:IsA("BasePart") or not MapFeatures.Fan.EnabledNames[instance.Name] or fans[instance] then
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

function FanAirflow.start()
	if started then
		return
	end
	started = true
	local currentGeneration = generation
	local root = Workspace:WaitForChild("Assets"):WaitForChild("Arena"):WaitForChild("Scriptables")
	if not started or generation ~= currentGeneration then
		return
	end
	table.insert(connections, root.DescendantAdded:Connect(track))
	table.insert(connections, root.DescendantRemoving:Connect(forget))
	for _, instance in root:GetDescendants() do
		track(instance)
	end
	table.insert(connections, RunService.RenderStepped:Connect(step))
end

function FanAirflow.stop()
	started = false
	generation += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for base in fans do
		forget(base)
	end
end

return FanAirflow
