--!strict

-- Terrain feature tuning. Per-pad override via a "LaunchSpeed" attribute on the pad.
-- VerticalPadding widens a volume upward so a root just above the part counts as inside.
return {
	Spawns = { RootOffsetStuds = 3.5 },
	-- Squash frequencies/ratios are converted from the prototype's spring constants
	-- (outer m=1, c=3, k=125; inner m=50, c=5, k=200).
	JumpPad = {
		BouncePower = 85, -- vertical speed set on launch, horizontal is preserved
		-- Fraction of gravity cancelled while airborne, which is what makes the
		-- arc floaty rather than a plain high jump.
		FloatFactor = 0.65,
		-- How far above the pad still counts as standing on it, so a jump taken
		-- from the surface triggers rather than only a landing.
		ContactTolerance = 0.75,
		-- A player descending faster than this gets bounced on contact instead of
		-- having to jump.
		FallSpeed = 5,
		MaxFloatSeconds = 8,
		RetriggerCooldown = 0.15,
		ParticleBurst = 50,
		ParticleLifetime = 2,
		-- Squash visuals, client side.
		OuterFrequencyHz = 1.7796,
		OuterDampingRatio = 0.1342,
		OuterImpulse = -2,
		InnerFrequencyHz = 0.3183,
		InnerDampingRatio = 0.025,
		InnerImpulse = -1,
		MinimumSquash = 0.5, -- floor on vertical scale, keeps the pad from inverting
	},
	FoamPit = {
		WalkSpeedScale = 0.45,
		VerticalPadding = 2,
	},
	ElimZone = {
		VerticalPadding = 2,
	},
	Rotating = {
		DegreesPerSecond = 1, -- per-assembly override: numeric "RotationSpeed" attribute on Origin
		CarryHeight = 16,
		ContactTolerance = 0.75,
		MinSupportNormalY = 0.5,
		MaxAirborneSeconds = 4,
		MaxFrameSeconds = 0.2,
		MaxFrameDisplacement = 16,
		MaxCarryDelta = 4,
		MinimumCarryStuds = 1e-3,
	},
}
