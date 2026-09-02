-- Name: OnboardingWaypoint.luau
-- Author: Jack C.
-- Description: Renders the training waypoint arrow. Rides a ring around the player at the bearing of the current objective, which is either a fixed place the server named or whichever live dummy is nearest, and clears once the player has arrived. Presentation only: the objective comes from the server and is never invented here.
-- Created: 2026-08-26

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OnboardingConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Onboarding"))
local OnboardingClient = require(script.Parent:WaitForChild("OnboardingClient"))
local OnboardingTargets = require(script.Parent:WaitForChild("OnboardingTargets"))

local OnboardingWaypoint = {}

-- The authored arrow runs along its X axis, so that is the axis that points at
-- the objective; lookAt aims -Z, hence the quarter turn. The roll then lays the
-- arrow flat about that same long axis.
local POINT_AXIS_YAW = math.rad(90)
local POINT_AXIS_ROLL = math.rad(90)

local started = false
local arrow: BasePart? = nil
local template: BasePart? = nil
local connection: RBXScriptConnection? = nil
local unsubscribe: (() -> ())? = nil
local waypoint: Vector3? = nil
local trackTargets = false
local shown = false

local function resolvedTemplate(): BasePart
	if template == nil then
		local found = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("WaypointArrow")
		assert(found:IsA("BasePart"), "[OnboardingWaypoint] Assets.UI.WaypointArrow must be a BasePart")
		template = found
	end
	return template :: BasePart
end

local function resolvedArrow(): BasePart
	if arrow == nil or arrow.Parent == nil then
		local created = resolvedTemplate():Clone()
		created.Anchored = true
		created.CanCollide = false
		-- The trajectory preview spherecasts the world, so the arrow must be
		-- invisible to queries or it reads as an obstacle mid-throw.
		created.CanQuery = false
		created.CanTouch = false
		created.CastShadow = false
		arrow = created
	end
	return arrow :: BasePart
end

local function hide()
	if not shown then
		return
	end
	shown = false
	if arrow then
		arrow.Parent = nil
	end
end

local function characterRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- A moving dummy is chased rather than pointed at where it spawned, and it is
-- released once the player is close enough to swing at it.
local function objectiveFor(from: Vector3): (Vector3?, number)
	local config = OnboardingConfig.Waypoint
	if trackTargets then
		local target = OnboardingTargets.nearestTo(from)
		local anchor = if target then OnboardingTargets.anchorOf(target) else nil
		if anchor == nil then
			return nil, 0
		end
		return anchor.Position, config.MeleeArriveRadiusStuds
	end
	if waypoint ~= nil then
		return waypoint, config.ArriveRadiusStuds
	end
	return nil, 0
end

local function update(dt: number)
	local root = characterRoot()
	if root == nil then
		hide()
		return
	end
	local destination, arriveRadius = objectiveFor(root.Position)
	if destination == nil then
		hide()
		return
	end

	local toTarget = destination - root.Position
	local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
	if flat.Magnitude <= arriveRadius then
		hide()
		return
	end

	-- The arrow rides a fixed ring around the player at the objective's bearing,
	-- so it reads the same whichever way they happen to be facing.
	local config = OnboardingConfig.Waypoint
	local bearing = flat.Unit
	local bob = math.sin(os.clock() * config.BobFrequency) * config.BobAmplitudeStuds
	local desired = root.Position + bearing * config.DistanceStuds + Vector3.new(0, config.HeightStuds + bob, 0)
	local goal = CFrame.lookAt(desired, desired + bearing)
		* CFrame.Angles(0, POINT_AXIS_YAW, 0)
		* CFrame.Angles(POINT_AXIS_ROLL, 0, 0)

	local placed = resolvedArrow()
	if not shown then
		shown = true
		placed.CFrame = goal
		placed.Parent = Workspace
		return
	end
	placed.CFrame = placed.CFrame:Lerp(goal, 1 - math.exp(-dt * config.TurnResponsiveness))
end

function OnboardingWaypoint.start()
	if started then
		return
	end
	started = true
	local snapshot = OnboardingClient.getSnapshot()
	waypoint = snapshot.waypoint
	trackTargets = snapshot.trackTargets == true
	unsubscribe = OnboardingClient.subscribe(function(next)
		waypoint = next.waypoint
		trackTargets = next.trackTargets == true
	end)
	connection = RunService.RenderStepped:Connect(update)
end

function OnboardingWaypoint.destroy()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if unsubscribe then
		unsubscribe()
		unsubscribe = nil
	end
	hide()
	if arrow then
		arrow:Destroy()
		arrow = nil
	end
	waypoint = nil
	trackTargets = false
	started = false
end

return OnboardingWaypoint
