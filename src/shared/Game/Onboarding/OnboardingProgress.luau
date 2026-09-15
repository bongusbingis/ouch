--!strict
-- Server-observed progress in the original arena approach frame.
local Progress = {}

function Progress.atCheckpoint(position: Vector3, distance: number, grounded: boolean, config): boolean
	return grounded
		and Vector2.new(position.X - distance, position.Z).Magnitude <= config.CheckpointRadius
		and position.Y > -2
		and position.Y <= config.CheckpointHeight
end

function Progress.isLost(position: Vector3, world): boolean
	local radius = Vector2.new(position.X, position.Z).Magnitude
	return position.Y < -world.FallRecoveryDepth
		or (
			position.Y < 0
			and radius > world.RingInnerRadius
			and radius < world.RingOuterRadius
			and math.abs(position.Z) > world.BridgeHalfWidth
		)
end

function Progress.jumpedAt(position: Vector3, jumpAt: number?, airborne: boolean, rising: boolean): boolean
	return jumpAt ~= nil
		and airborne
		and rising
		and Vector2.new(position.X - (jumpAt :: number), position.Z).Magnitude <= 12
end

function Progress.needsJump(jumpAt: number?, checkpoint: number, target: number): boolean
	return jumpAt ~= nil
		and (jumpAt :: number) > math.min(checkpoint, target)
		and (jumpAt :: number) < math.max(checkpoint, target)
end

return table.freeze(Progress)
