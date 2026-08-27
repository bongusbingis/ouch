-- Name: OnboardingTargetMarkers.luau
-- Author: Jack C.
-- Description: Draws the "hit this" marker over every live training dummy, turning it to face the camera each frame so a flat arrow mesh reads from any angle. Presentation only, over the target set OnboardingTargets owns.
-- Created: 2026-08-26

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OnboardingConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Onboarding"))
local OnboardingTargets = require(script.Parent:WaitForChild("OnboardingTargets"))

local OnboardingTargetMarkers = {}

-- The arrow runs along its own X axis with its flat face on Z, so the marker is
-- built from axes directly: X aims down at the dummy, Z turns to the viewer.
local DOWN = Vector3.new(0, -1, 0)

local started = false
local template: BasePart? = nil
local markers: { [Model]: BasePart } = {}
local connection: RBXScriptConnection? = nil

local function resolvedTemplate(): BasePart
	if template == nil then
		local found = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("WaypointArrow")
		assert(found:IsA("BasePart"), "[OnboardingTargetMarkers] Assets.UI.WaypointArrow must be a BasePart")
		template = found
	end
	return template :: BasePart
end

local function buildMarker(): BasePart
	local source = resolvedTemplate()
	local style = OnboardingConfig.Dummy
	local marker = source:Clone()
	marker.Name = "OnboardingTargetMarker"
	marker.Anchored = true
	marker.CanCollide = false
	-- The trajectory preview spherecasts the world, so the marker must be
	-- invisible to queries or it reads as an obstacle mid-throw.
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Color = style.MarkerColor
	marker.Size = source.Size * style.MarkerScale
	marker.Parent = Workspace
	return marker
end

local function markerCFrame(position: Vector3, eye: Vector3): CFrame
	local toEye = eye - position
	local across = toEye - DOWN * toEye:Dot(DOWN)
	local facing = if across.Magnitude > 1e-3 then across.Unit else Vector3.new(0, 0, 1)
	return CFrame.fromMatrix(position, DOWN, facing:Cross(DOWN), facing)
end

local function update(_dt: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local style = OnboardingConfig.Dummy
	local bob = math.sin(os.clock() * style.MarkerBobFrequency) * style.MarkerBobStuds
	local eye = camera.CFrame.Position
	local live: { [Model]: boolean } = {}

	for _, target in OnboardingTargets.list() do
		local anchor = OnboardingTargets.anchorOf(target)
		if anchor == nil then
			continue
		end
		live[target] = true
		local marker = markers[target]
		if marker == nil then
			marker = buildMarker()
			markers[target] = marker
		end
		marker.CFrame = markerCFrame(anchor.Position + Vector3.new(0, style.MarkerHeightStuds + bob, 0), eye)
	end

	for target, marker in markers do
		if not live[target] then
			marker:Destroy()
			markers[target] = nil
		end
	end
end

function OnboardingTargetMarkers.start()
	if started then
		return
	end
	started = true
	connection = RunService.RenderStepped:Connect(update)
end

function OnboardingTargetMarkers.destroy()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for target, marker in markers do
		marker:Destroy()
		markers[target] = nil
	end
	started = false
end

return OnboardingTargetMarkers
