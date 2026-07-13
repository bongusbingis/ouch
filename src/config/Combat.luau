--!strict

-- Every combat feel constant lives here and is cmdr-tunable at runtime (M3).
-- Units: studs, seconds, degrees.

return {
	Dodgeball = {
		ThrowSpeed = 200,
		Gravity = 50,
		Radius = 1,
		HitForgiveness = 0.35, -- added to Radius for hit tests (device magnetism adds more)
		ThrowCooldown = 0.6,
		ThrowOriginMaxOffset = 6, -- max distance of throw origin from character center
		MaxFlightTime = 2,
		WindupDuration = 0.12,
		MomentumInheritance = 0.3,
		ReleaseForwardOffset = 0.35,

		HomingTurnRateDeg = 72,
		HomingBreakAngleDeg = 55, -- lock fully broken at this angular error
		TargetSelectRange = 100, -- max soft-lock distance

		RecallSpeed = 110,
		RecallAcceleration = 420,
		RecallTurnRateDeg = 720,
		RecallCooldown = 2,
		RecallMaxDistance = 120,
		RecallInterceptable = false, -- playtest toggle: can a recalling ball be blocked/caught

		PickupRadius = 4,
		BounceRestitution = 0.52,
		BounceFriction = 0.22,
		MaxBounces = 3,
		SettleSpeed = 10,
		SettleVerticalSpeed = 5,
		ContactSeparation = 0.08,
		MinBounceNormalSpeed = 1.5,
		MaxBounceContactsPerStep = 4,
		SpinRate = 16,
		RemoteSmoothing = 18,

		SpawnCadence = 5, -- seconds between world ball spawns per spawn point
		SpawnSearchRadius = 3, -- spawn suppressed while a Free ball sits within this radius
	},

	-- Simplified hit capsule applied to every character (never per-limb).
	CharacterCapsule = {
		Height = 5,
		Radius = 1.5,
	},
}
