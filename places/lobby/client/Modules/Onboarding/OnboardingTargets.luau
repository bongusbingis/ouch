-- Name: OnboardingTargets.luau
-- Author: Jack C.
-- Description: Tracks which training dummies belong to the local player, from the attribute the server projects onto each live one. Single client-side owner of that set, so the target markers and the waypoint arrow always agree on what counts as a target.
-- Created: 2026-08-26

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OnboardingConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Onboarding"))
local PlayerIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("PlayerIds")
)
local AimDirector = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("AimDirector"))

local OnboardingTargets = {}

local ARENA_CONTAINER = "OnboardingArenas"
local RESCAN_SECONDS = 0.2

local started = false
local targets: { Model } = {}
local lastPositions: { [Model]: Vector3 } = {}
local lostListeners: { (Model, Vector3) -> () } = {}
local connection: RBXScriptConnection? = nil
local accumulator = RESCAN_SECONDS

local function anchorPart(target: Model): BasePart?
	local part = target:FindFirstChild("Head") or target.PrimaryPart
	return if part and part:IsA("BasePart") then part else nil
end

local function rescan()
	local localId = PlayerIds.toId(Players.LocalPlayer)
	local attribute = OnboardingConfig.TargetAttribute
	table.clear(targets)

	local folder = Workspace:FindFirstChild(ARENA_CONTAINER)
	if folder ~= nil then
		for _, arena in folder:GetChildren() do
			for _, child in arena:GetChildren() do
				if child:IsA("Model") and child:GetAttribute(attribute) == localId then
					table.insert(targets, child)
				end
			end
		end
	end

	-- The reticle treats a dummy like any other target, so aiming at one reads
	-- as a lock rather than as aiming at scenery.
	AimDirector.setExtraTargets(targets)

	local live: { [Model]: boolean } = {}
	for _, target in targets do
		live[target] = true
		local anchor = anchorPart(target)
		if anchor then
			lastPositions[target] = anchor.Position
		end
	end

	-- A target that stops being one has just been knocked down, and where it was
	-- standing is where the payoff belongs.
	for target, position in lastPositions do
		if not live[target] then
			lastPositions[target] = nil
			for _, listener in table.clone(lostListeners) do
				local ok, err = pcall(listener, target, position)
				if not ok then
					warn(`[OnboardingTargets] lost listener failed: {err}`)
				end
			end
		end
	end
end

function OnboardingTargets.onLost(listener: (Model, Vector3) -> ()): () -> ()
	table.insert(lostListeners, listener)
	return function()
		local index = table.find(lostListeners, listener)
		if index then
			table.remove(lostListeners, index)
		end
	end
end

function OnboardingTargets.list(): { Model }
	return targets
end

function OnboardingTargets.anchorOf(target: Model): BasePart?
	return anchorPart(target)
end

function OnboardingTargets.nearestTo(position: Vector3): (Model?, number)
	local best: Model? = nil
	local bestDistance = math.huge
	for _, target in targets do
		local anchor = OnboardingTargets.anchorOf(target)
		if anchor == nil then
			continue
		end
		local offset = anchor.Position - position
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if distance < bestDistance then
			best = target
			bestDistance = distance
		end
	end
	return best, bestDistance
end

function OnboardingTargets.start()
	if started then
		return
	end
	started = true
	accumulator = RESCAN_SECONDS
	connection = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < RESCAN_SECONDS then
			return
		end
		accumulator = 0
		rescan()
	end)
end

function OnboardingTargets.destroy()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	table.clear(targets)
	AimDirector.setExtraTargets({})
	table.clear(lastPositions)
	table.clear(lostListeners)
	started = false
end

return OnboardingTargets
