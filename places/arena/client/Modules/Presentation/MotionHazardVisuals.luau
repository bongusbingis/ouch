--!strict
-- Short trails follow the hydrated mover's displayed parts without changing their poses.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapFeatures = require(ReplicatedStorage.Config.Gameplay.MapFeatures)
local RotatingPlatforms = require(ReplicatedStorage.Shared.Game.MapFeatures.RotatingPlatforms)

local MotionHazardVisuals = {}

local MAX_TRAILS = 16
local MAX_DISTANCE = 140
local RECONCILE_SECONDS = 0.5
local DESCRIPTOR = "HazardMotionDescriptorV1"
local PART_ID = "HazardMotionPartIdV1"

type Entry = {
	part: BasePart,
	platform: RotatingPlatforms.Platform,
	rotor: RotatingPlatforms.LocalRotor,
	descriptorOwner: Instance,
	descriptor: string,
	partId: string,
	first: Attachment,
	second: Attachment,
	trail: Trail,
	previousPosition: Vector3,
	axis: Vector3,
	radial: Vector3,
	radialLength: number,
	axialOffset: number,
	width: number,
	side: number,
	connections: { RBXScriptConnection },
}

type Candidate = {
	part: BasePart,
	platform: RotatingPlatforms.Platform,
	rotor: RotatingPlatforms.LocalRotor,
	distance: number,
}

type Allocation = {
	first: Attachment?,
	second: Attachment?,
	trail: Trail?,
}

local entries: { [BasePart]: Entry } = {}
local heartbeat: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local motionConnection: RBXScriptConnection? = nil
local elapsed = 0
local started = false

local function clear(part: BasePart)
	local entry = entries[part]
	if not entry then
		return
	end
	entries[part] = nil
	entry.trail.Enabled = false
	entry.trail:Clear()
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	entry.trail:Destroy()
	entry.first:Destroy()
	entry.second:Destroy()
end

local function descriptorOwner(platform: RotatingPlatforms.Platform): Instance?
	local assembly = platform.assembly
	if assembly:GetAttribute(DESCRIPTOR) == platform.descriptor then
		return assembly
	end
	-- The verified Arena legacy adapter stores its descriptor on the group
	-- containing Origin and Assembly, rather than on Assembly itself.
	local parent = assembly.Parent
	if
		parent
		and parent:FindFirstChild("Assembly") == assembly
		and parent:FindFirstChild("Origin") ~= nil
		and parent:GetAttribute(DESCRIPTOR) == platform.descriptor
	then
		return parent
	end
	return nil
end

local function eligible(platform: RotatingPlatforms.Platform, rotor: RotatingPlatforms.LocalRotor): boolean
	local part = rotor.part
	local attributes = MapFeatures.Attributes
	if
		platform.descriptor == nil
		or platform.clientBatch == nil
		or not part.Anchored
		or not part:IsDescendantOf(Workspace)
		or (part ~= platform.assembly and not part:IsDescendantOf(platform.assembly))
		or typeof(part:GetAttribute(PART_ID)) ~= "string"
		or descriptorOwner(platform) == nil
		or (rotor.mode ~= "spin" and rotor.mode ~= "rock")
		or (rotor.mode == "spin" and rotor.degreesPerSecond == 0)
		or (rotor.mode == "rock" and rotor.amplitude == 0)
		or part:GetAttribute(attributes.FanBlade) == true
		or part:GetAttribute(attributes.Fan) == true
		or part:GetAttribute(attributes.Seesaw) == true
		or part:GetAttribute(attributes.BeachBall) == true
		or part:GetAttribute(attributes.BigBall) == true
		or part.Name:find("ball_001", 1, true) == 1
	then
		return false
	end
	return part.Size.X > 0 and part.Size.Y > 0 and part.Size.Z > 0
end

local function stillValid(entry: Entry): boolean
	return eligible(entry.platform, entry.rotor)
		and entry.platform.descriptor == entry.descriptor
		and entry.part:GetAttribute(PART_ID) == entry.partId
end

local function membershipIntact(platform: RotatingPlatforms.Platform): boolean
	local restParts = platform.restParts
	if not restParts then
		return false
	end
	for _, rest in restParts do
		local part = rest.part
		if
			part:GetAttribute(PART_ID) ~= rest.id
			or not part.Anchored
			or (part ~= platform.assembly and not part:IsDescendantOf(platform.assembly))
		then
			return false
		end
	end
	return true
end

local function facePositions(
	axis: Vector3,
	radial: Vector3,
	radialLength: number,
	axialOffset: number,
	width: number,
	side: number
): (Vector3, Vector3)
	local centre = radial * radialLength + axis * side * axialOffset
	return centre - radial * (width / 2), centre + radial * (width / 2)
end

local function setTransparency(trail: Trail, distance: number)
	local fade = math.clamp((MAX_DISTANCE - distance) / (MAX_DISTANCE - 60), 0, 1)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - 0.3 * fade),
		NumberSequenceKeypoint.new(0.45, 1 - 0.18 * fade),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function add(candidate: Candidate, allocation: Allocation, cameraPosition: Vector3)
	local part = candidate.part
	local platform = candidate.platform
	local rotor = candidate.rotor
	if not membershipIntact(platform) then
		return
	end
	local axis = if rotor.axis == "X" then Vector3.xAxis elseif rotor.axis == "Z" then Vector3.zAxis else Vector3.yAxis
	local size = part.Size
	local radial = if rotor.axis == "X"
		then (if size.Y >= size.Z then Vector3.yAxis else Vector3.zAxis)
		elseif rotor.axis == "Z" then (if size.X >= size.Y then Vector3.xAxis else Vector3.yAxis)
		else (if size.X >= size.Z then Vector3.xAxis else Vector3.zAxis)
	local radialDimension = (size * radial).Magnitude
	local radialLength = radialDimension * 0.375
	local axialOffset = (size * axis).Magnitude / 2 + 0.025
	local width = math.min(0.24, math.max(0.16, 0.025 * radialDimension), 0.20 * radialDimension)
	if radialLength < 0.1 then
		return
	end
	local cameraAxial = part.CFrame:PointToObjectSpace(cameraPosition):Dot(axis)
	local side = if cameraAxial >= 0 then 1 else -1
	local firstPosition, secondPosition = facePositions(axis, radial, radialLength, axialOffset, width, side)
	local first = Instance.new("Attachment")
	allocation.first = first
	first.Name = "MotionTrailInner"
	first.Position = firstPosition
	first.Parent = part
	local second = Instance.new("Attachment")
	allocation.second = second
	second.Name = "MotionTrailOuter"
	second.Position = secondPosition
	second.Parent = part
	local trail = Instance.new("Trail")
	allocation.trail = trail
	trail.Name = "MotionHazardTrail"
	trail.Attachment0 = first
	trail.Attachment1 = second
	trail.Lifetime = 0.14
	trail.MaxLength = 2
	trail.MinLength = 0.04
	trail.WidthScale = NumberSequence.new(1)
	trail.FaceCamera = true
	trail.LightEmission = 0
	trail.Enabled = false
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	setTransparency(trail, candidate.distance)
	trail.Parent = part
	local entry: Entry = {
		part = part,
		platform = platform,
		rotor = rotor,
		descriptorOwner = descriptorOwner(platform) :: Instance,
		descriptor = platform.descriptor :: string,
		partId = part:GetAttribute(PART_ID) :: string,
		first = first,
		second = second,
		trail = trail,
		previousPosition = first.WorldPosition,
		axis = axis,
		radial = radial,
		radialLength = radialLength,
		axialOffset = axialOffset,
		width = width,
		side = side,
		connections = {},
	}
	entries[part] = entry
	local function validate()
		if not stillValid(entry) then
			clear(part)
		end
	end
	table.insert(entry.connections, part.AncestryChanged:Connect(validate))
	table.insert(entry.connections, part:GetAttributeChangedSignal(PART_ID):Connect(validate))
	table.insert(entry.connections, part:GetPropertyChangedSignal("Anchored"):Connect(validate))
	table.insert(entry.connections, entry.descriptorOwner:GetAttributeChangedSignal(DESCRIPTOR):Connect(validate))
	table.insert(
		entry.connections,
		platform.assembly.DescendantRemoving:Connect(function(instance)
			if instance:IsA("BasePart") then
				clear(part)
			end
		end)
	)
end

local function updateView(entry: Entry, candidate: Candidate, cameraPosition: Vector3)
	setTransparency(entry.trail, candidate.distance)
	local cameraAxial = entry.part.CFrame:PointToObjectSpace(cameraPosition):Dot(entry.axis)
	local side = entry.side
	if cameraAxial > 0.5 then
		side = 1
	elseif cameraAxial < -0.5 then
		side = -1
	end
	if side ~= entry.side then
		entry.trail.Enabled = false
		entry.trail:Clear()
		local first, second =
			facePositions(entry.axis, entry.radial, entry.radialLength, entry.axialOffset, entry.width, side)
		entry.first.Position = first
		entry.second.Position = second
		entry.side = side
		entry.previousPosition = entry.first.WorldPosition
	end
end

local function sampleTrails(delta: number)
	for _, entry in entries do
		local current = entry.first.WorldPosition
		local travel = (current - entry.previousPosition).Magnitude
		entry.previousPosition = current
		if delta <= 0 or delta > 0.1 or travel > 3 or travel / delta < 1 then
			if entry.trail.Enabled then
				entry.trail.Enabled = false
				entry.trail:Clear()
			end
		else
			entry.trail.Enabled = true
		end
	end
end

local function reconcile()
	local camera = Workspace.CurrentCamera
	if not camera or GuiService.ReducedMotionEnabled then
		for part in entries do
			clear(part)
		end
		return
	end
	local candidates: { Candidate } = {}
	local seen: { [BasePart]: boolean } = {}
	for _, platform in RotatingPlatforms.all() do
		for _, rotor in platform.localRotors do
			local part = rotor.part
			if not seen[part] and eligible(platform, rotor) then
				seen[part] = true
				local distance =
					math.max(0, (camera.CFrame.Position - part.Position).Magnitude - part.Size.Magnitude / 2)
				if distance <= MAX_DISTANCE then
					table.insert(candidates, { part = part, platform = platform, rotor = rotor, distance = distance })
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	local selected: { [BasePart]: Candidate } = {}
	for index = 1, math.min(MAX_TRAILS, #candidates) do
		local candidate = candidates[index]
		selected[candidate.part] = candidate
	end
	for part, entry in entries do
		local candidate = selected[part]
		if
			candidate == nil
			or entry.platform ~= candidate.platform
			or entry.rotor ~= candidate.rotor
			or not stillValid(entry)
		then
			clear(part)
		end
	end
	for part, candidate in selected do
		if entries[part] == nil then
			local allocation: Allocation = { first = nil, second = nil, trail = nil }
			local ok = pcall(add, candidate, allocation, camera.CFrame.Position)
			if not ok then
				if entries[part] then
					clear(part)
				else
					if allocation.trail then
						allocation.trail:Destroy()
					end
					if allocation.first then
						allocation.first:Destroy()
					end
					if allocation.second then
						allocation.second:Destroy()
					end
				end
			end
		else
			updateView(entries[part], candidate, camera.CFrame.Position)
		end
	end
end

function MotionHazardVisuals.start()
	if started then
		return
	end
	started = true
	elapsed = 0
	motionConnection = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(reconcile)
	renderConnection = RunService.PreRender:Connect(sampleTrails)
	heartbeat = RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed >= RECONCILE_SECONDS then
			elapsed = 0
			reconcile()
		end
	end)
	reconcile()
end

function MotionHazardVisuals.stop()
	started = false
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if motionConnection then
		motionConnection:Disconnect()
		motionConnection = nil
	end
	for part in entries do
		clear(part)
	end
end

return MotionHazardVisuals
