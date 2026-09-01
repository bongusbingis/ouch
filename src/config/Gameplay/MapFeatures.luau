--!strict

-- Terrain feature tuning. Per-pad override via a "LaunchSpeed" attribute on the pad.
-- VerticalPadding widens a volume upward so a root just above the part counts as inside.
return {
	-- Squash frequencies/ratios are converted from the prototype's spring constants
	-- (outer m=1, c=3, k=125; inner m=50, c=5, k=200).
	JumpPad = {
		BouncePower = 85, -- vertical speed set on launch, horizontal is preserved
		-- Fraction of gravity cancelled while airborne, which is what makes the
		-- arc floaty rather than a plain high jump.
		FloatFactor = 0.65,
		-- How far above the pad still counts as standing on it, so a jump taken
		-- from the surface triggers rather than only a landing.
		ZoneHeight = 8,
		VerticalPadding = 2,
		-- A player descending faster than this gets bounced on contact instead of
		-- having to jump.
		FallSpeed = 5,
		FallCastBuffer = 15,
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
		-- A rider is carried while their root sits above the assembly's footprint
		-- and within CarryHeight of its top, which is what keeps them moving with
		-- it through a jump instead of the platform turning out from under them.
		CarryHeight = 16,
		CarryDepthTolerance = 2,
	},
}
