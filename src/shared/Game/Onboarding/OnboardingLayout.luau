-- Name: OnboardingLayout.luau
-- Author: Jack C.
-- Description: Pure geometry for the training rings: which slot a session gets, where its ring sits, and where the spawn, targets, and exit portal are within it.
-- Created: 2026-08-27

--!strict

local OnboardingConfig = require(script.Parent.Parent.Parent.Parent.Config.Onboarding)

-- Positions use the native vector type rather than Vector3 for the same reason
-- the simulation does: this module is pure, and the headless specs have no
-- engine to construct a Vector3 with. Callers on the engine side convert once.
type Vec = vector

local OnboardingLayout = {}

export type Frame = {
	-- Ring centre at floor level.
	origin: Vec,
	-- Where the player stands.
	spawn: Vec,
	-- What they face on arrival: the first target is already in front of them,
	-- so the first throw needs no turn.
	facing: Vec,
}

-- Slots are laid out on a grid far above the lobby proper. Isolation is
-- spatial and permanent: two onboarding players never share a ring, so one
-- player's dummy, ball, or knockout can never touch another's session.
function OnboardingLayout.slotOrigin(slot: number): Vec
	local training = OnboardingConfig.Training
	local index = math.max(math.floor(slot), 1) - 1
	local row = math.floor(index / training.SlotsPerRow)
	local column = index % training.SlotsPerRow
	return training.Origin + vector.create(column * training.SlotSpacing, 0, row * training.SlotSpacing)
end

function OnboardingLayout.frame(slot: number): Frame
	local origin = OnboardingLayout.slotOrigin(slot)
	-- Set back from centre so every target sits comfortably ahead of the player
	-- without a turn, which is what makes the first throw a gimme.
	local spawn = origin + vector.create(0, 3, -OnboardingConfig.Training.RingRadius * 0.45)
	return {
		origin = origin,
		spawn = spawn,
		facing = spawn + vector.create(0, 0, 10),
	}
end

function OnboardingLayout.targetPosition(slot: number, stepId: string): Vec?
	local spec = (OnboardingConfig.Training.Targets :: any)[stepId]
	if spec == nil then
		return nil
	end
	return OnboardingLayout.frame(slot).spawn + spec.Offset
end

-- Practice bots are spread around the far arc so the player has to turn and
-- pick a target rather than spraying at one spot.
function OnboardingLayout.practicePosition(slot: number, index: number, count: number): Vec
	local frame = OnboardingLayout.frame(slot)
	local radius = OnboardingConfig.Training.RingRadius * 0.55
	local spread = math.pi * 0.6
	local alpha = if count <= 1 then 0.5 else (index - 1) / (count - 1)
	local angle = -spread / 2 + spread * alpha
	return frame.spawn + vector.create(math.sin(angle) * radius, 0, math.cos(angle) * radius + 6)
end

function OnboardingLayout.portalPosition(slot: number): Vec
	return OnboardingLayout.slotOrigin(slot) + vector.create(0, 6, -OnboardingConfig.Training.RingRadius + 2)
end

-- A player below this has fallen out of the world and is returned to their
-- spawn with their step intact.
function OnboardingLayout.fallHeight(slot: number): number
	return OnboardingLayout.slotOrigin(slot).y - OnboardingConfig.Training.FallRecoveryDepth
end

function OnboardingLayout.isInsideRing(slot: number, position: Vec): boolean
	local origin = OnboardingLayout.slotOrigin(slot)
	local dx = position.x - origin.x
	local dz = position.z - origin.z
	return math.sqrt(dx * dx + dz * dz) <= OnboardingConfig.Training.RingRadius
end

return OnboardingLayout
