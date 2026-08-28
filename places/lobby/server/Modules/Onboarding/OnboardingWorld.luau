-- Name: OnboardingWorld.luau
-- Author: Jack C.
-- Description: Builds and tears down one prototype training ring per onboarding session — floor, padded walls, columns, spotlight, and exit portal — under a single named container so no generated geometry is left anonymous in the workspace.
-- Created: 2026-08-27

--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local OnboardingConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Onboarding"))
local OnboardingLayout = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Onboarding")
		:WaitForChild("OnboardingLayout")
)

-- PROTOTYPE GEOMETRY. Everything this module builds is placeholder: the shapes
-- are correct, the art is not. docs/onboarding.md lists what should eventually
-- be authored in Studio and dropped in behind the same names.
local OnboardingWorld = {}

local CONTAINER_NAME = "OnboardingArenas"

local rings: { [number]: Folder } = {}

-- The layout module is pure and speaks the native vector type; the engine side
-- converts once, here.
local function toVector3(value: vector): Vector3
	return Vector3.new(value.x, value.y, value.z)
end

local function container(): Folder
	local existing = Workspace:FindFirstChild(CONTAINER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = CONTAINER_NAME
	created.Parent = Workspace
	return created
end

local function part(name: string, parent: Instance, size: Vector3, cframe: CFrame, color: Color3): Part
	local created = Instance.new("Part")
	created.Name = name
	created.Anchored = true
	created.CanCollide = true
	created.CanTouch = false
	created.Material = Enum.Material.SmoothPlastic
	created.TopSurface = Enum.SurfaceType.Smooth
	created.BottomSurface = Enum.SurfaceType.Smooth
	created.Size = size
	created.CFrame = cframe
	created.Color = color
	created.Parent = parent
	return created
end

-- A cylinder part's length runs along its X axis, so every flat disc and
-- upright column here is authored lying down and then stood up.
local function cylinder(
	name: string,
	parent: Instance,
	thickness: number,
	diameter: number,
	cframe: CFrame,
	color: Color3
): Part
	local created = part(
		name,
		parent,
		Vector3.new(thickness, diameter, diameter),
		cframe * CFrame.Angles(0, 0, math.rad(90)),
		color
	)
	created.Shape = Enum.PartType.Cylinder
	return created
end

local function buildFloor(parent: Instance, origin: Vector3)
	local training = OnboardingConfig.Training
	local prototype = OnboardingConfig.Prototype
	local floor = cylinder(
		"Floor",
		parent,
		training.FloorThickness,
		training.RingRadius * 2,
		CFrame.new(origin - Vector3.new(0, training.FloorThickness / 2, 0)),
		prototype.FloorColor
	)
	floor.Material = Enum.Material.Fabric

	local inner = cylinder(
		"InnerRing",
		parent,
		training.FloorThickness * 0.25,
		training.RingRadius * 1.1,
		CFrame.new(origin + Vector3.new(0, 0.06, 0)),
		prototype.AccentColor
	)
	inner.CanCollide = false
	inner.Material = Enum.Material.Neon
	inner.Transparency = 0.65
end

local function buildWalls(parent: Instance, origin: Vector3)
	local training = OnboardingConfig.Training
	local prototype = OnboardingConfig.Prototype
	local segments = 16
	local circumference = 2 * math.pi * training.RingRadius
	local width = circumference / segments * 1.08
	for index = 1, segments do
		local angle = (index - 1) / segments * math.pi * 2
		local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * training.RingRadius
		local pad = part(
			`Pad{index}`,
			parent,
			Vector3.new(width, training.WallHeight, 3),
			CFrame.new(origin + offset + Vector3.new(0, training.WallHeight / 2, 0)) * CFrame.Angles(0, angle, 0),
			if index % 2 == 0 then prototype.WallColor else prototype.AccentColor
		)
		pad.Material = Enum.Material.Fabric
	end
end

local function buildColumns(parent: Instance, origin: Vector3)
	local training = OnboardingConfig.Training
	local prototype = OnboardingConfig.Prototype
	for index = 1, 4 do
		local angle = (index - 1) / 4 * math.pi * 2 + math.pi / 4
		local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * (training.RingRadius * 0.78)
		cylinder(
			`Column{index}`,
			parent,
			9,
			4,
			CFrame.new(origin + offset + Vector3.new(0, 4.5, 0)),
			prototype.ColumnColor
		)
	end
end

local function buildSpotlight(parent: Instance, origin: Vector3): Part
	local prototype = OnboardingConfig.Prototype
	local marker = cylinder("TargetSpotlight", parent, 0.2, 9, CFrame.new(origin), prototype.AccentColor)
	marker.CanCollide = false
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.25

	local light = Instance.new("PointLight")
	light.Brightness = prototype.SpotlightBrightness
	light.Color = prototype.AccentColor
	light.Range = 24
	light.Parent = marker
	return marker
end

local function buildPortal(parent: Instance, slot: number): Part
	local prototype = OnboardingConfig.Prototype
	local portal = part(
		"Portal",
		parent,
		Vector3.new(12, 14, 1.5),
		CFrame.new(toVector3(OnboardingLayout.portalPosition(slot))),
		prototype.PortalColor
	)
	portal.CanCollide = false
	portal.Material = Enum.Material.Neon
	portal.Transparency = 1

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PortalSparkle"
	emitter.Color = ColorSequence.new(prototype.PortalColor)
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Size = NumberSequence.new(1.2)
	emitter.Transparency = NumberSequence.new(0.2)
	emitter.Enabled = false
	emitter.Parent = portal
	return portal
end

local function buildBurst(parent: Instance): ParticleEmitter
	local anchor = part(
		"CelebrationAnchor",
		parent,
		Vector3.one,
		CFrame.new(parent:GetAttribute("Origin") :: Vector3? or Vector3.zero),
		OnboardingConfig.Prototype.AccentColor
	)
	anchor.CanCollide = false
	anchor.Transparency = 1

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Confetti"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, OnboardingConfig.Prototype.AccentColor),
		ColorSequenceKeypoint.new(1, OnboardingConfig.Prototype.WallColor),
	})
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(24, 44)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.9)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Enabled = false
	emitter.Parent = anchor
	return emitter
end

function OnboardingWorld.ensure(slot: number): Folder
	local existing = rings[slot]
	if existing and existing.Parent ~= nil then
		return existing
	end

	local frame = OnboardingLayout.frame(slot)
	local origin = toVector3(frame.origin)
	local ring = Instance.new("Folder")
	ring.Name = `Ring{slot}`
	ring:SetAttribute("Slot", slot)
	ring:SetAttribute("Origin", origin)

	buildFloor(ring, origin)
	buildWalls(ring, origin)
	buildColumns(ring, origin)
	buildSpotlight(ring, toVector3(frame.spawn))
	buildPortal(ring, slot)
	buildBurst(ring)

	ring.Parent = container()
	rings[slot] = ring
	return ring
end

function OnboardingWorld.spotlight(slot: number): BasePart?
	local ring = rings[slot]
	local marker = ring and ring:FindFirstChild("TargetSpotlight")
	return if marker and marker:IsA("BasePart") then marker else nil
end

function OnboardingWorld.moveSpotlight(slot: number, position: Vector3?)
	local marker = OnboardingWorld.spotlight(slot)
	if marker == nil then
		return
	end
	if position == nil then
		marker.Transparency = 1
		marker:SetAttribute("Escalated", false)
		return
	end
	marker.Transparency = 0.25
	marker.CFrame = CFrame.new(position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

-- Assistance escalating is the one time the target should shout. It widens and
-- brightens rather than adding a new symbol the player has to interpret.
function OnboardingWorld.emphasizeTarget(slot: number, emphasized: boolean)
	local marker = OnboardingWorld.spotlight(slot)
	if marker == nil or marker:GetAttribute("Escalated") == emphasized then
		return
	end
	marker:SetAttribute("Escalated", emphasized)
	local prototype = OnboardingConfig.Prototype
	local scale = if emphasized then 1.55 else 1
	local light = marker:FindFirstChildOfClass("PointLight")
	TweenService:Create(marker, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 9 * scale, 9 * scale),
		Transparency = if emphasized then 0.1 else 0.25,
	}):Play()
	if light then
		TweenService:Create(light, TweenInfo.new(0.35), {
			Brightness = prototype.SpotlightBrightness * (if emphasized then 2.2 else 1),
			Range = 24 * scale,
		}):Play()
	end
end

-- A flat ring that snaps outward from a landed hit and fades. It reads as the
-- impact having weight without competing with the elimination splat the real
-- combat presentation already plays.
function OnboardingWorld.impactRing(slot: number, position: Vector3)
	local ring = rings[slot]
	if ring == nil then
		return
	end
	local burst = cylinder(
		"Impact",
		ring,
		0.2,
		4,
		CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0),
		OnboardingConfig.Prototype.AccentColor
	)
	burst.CanCollide = false
	burst.Material = Enum.Material.Neon
	burst.Transparency = 0.1
	TweenService:Create(burst, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 22, 22),
		Transparency = 1,
	}):Play()
	Debris:AddItem(burst, 0.6)
end

-- The way out earns a moment: the doorway opens rather than appearing, so the
-- player reads it as somewhere to go next.
function OnboardingWorld.openPortal(slot: number): Vector3?
	local ring = rings[slot]
	local portal = ring and ring:FindFirstChild("Portal")
	if portal == nil or not portal:IsA("BasePart") then
		return nil
	end
	local full = portal:GetAttribute("OpenSize")
	if typeof(full) ~= "Vector3" then
		full = portal.Size
		portal:SetAttribute("OpenSize", full)
	end
	portal.Size = Vector3.new((full :: Vector3).X * 0.15, 0.6, (full :: Vector3).Z)
	portal.Transparency = 1
	TweenService:Create(portal, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = full :: Vector3,
		Transparency = 0.3,
	}):Play()
	local emitter = portal:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter.Rate = 34
		emitter.Enabled = true
	end
	return portal.Position
end

function OnboardingWorld.celebrate(slot: number, at: Vector3)
	local ring = rings[slot]
	local anchor = ring and ring:FindFirstChild("CelebrationAnchor")
	if anchor == nil or not anchor:IsA("BasePart") then
		return
	end
	anchor.CFrame = CFrame.new(at)
	local emitter = anchor:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter:Emit(160)
		-- A second, slower wave so the burst has a tail rather than a single pop.
		task.delay(0.16, function()
			if emitter.Parent ~= nil then
				emitter:Emit(90)
			end
		end)
	end
	OnboardingWorld.impactRing(slot, at)
end

function OnboardingWorld.destroy(slot: number)
	local ring = rings[slot]
	rings[slot] = nil
	if ring then
		ring:Destroy()
	end
end

function OnboardingWorld.destroyAll()
	for slot in rings do
		OnboardingWorld.destroy(slot)
	end
	local existing = Workspace:FindFirstChild(CONTAINER_NAME)
	if existing then
		existing:Destroy()
	end
end

return OnboardingWorld
