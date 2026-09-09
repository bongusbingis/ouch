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
	Fan = {
		-- Exact authored bases; the static course layout remains unchanged.
		EnabledNames = {
			["propeller_trampoline_1_001.001"] = true,
			["propeller_trampoline_1_001.002"] = true,
			["propeller_trampoline_1_001.003"] = true,
			["propeller_trampoline_1_001.004"] = true,
		},
		BladeDegreesPerSecond = 300,
		LaunchSpeed = 65,
		FloatFactor = 0.65,
		RadiusScale = 0.7, -- central opening, relative to the base's half-width
		EntryHeight = 6, -- root height above the grate that can begin a launch
		ColumnHeight = 18,
		BottomTolerance = 0.5,
		MaxLiftSeconds = 0.45,
		RetriggerCooldown = 0.75,
		GuardSeconds = 3, -- covers the residual arc after leaving the airflow
	},
	Spinner = {
		EnabledNames = {
			["obstacle_6_001.001"] = true,
			["obstacle_6_001.002"] = true,
			["obstacle_6_001.003"] = true,
			["obstacle_6_001.005"] = true,
			["obstacle_6_001.006"] = true,
			["obstacle_6_001.007"] = true,
		},
		DegreesPerSecond = 100,
		KnockbackSpeed = 42,
		UpwardSpeed = 16,
		ShoveSeconds = 0.15,
		OutwardBias = 0.3,
		RetriggerCooldown = 1,
		GuardSeconds = 0.8,
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
	Disc = {
		HubPrefix = "obstacle_14_001",
		PlatePrefix = "obstacle_14_002",
		DegreesPerSecond = 45,
	},
	SwingPanel = {
		AxlePrefix = "obstacle_8_001",
		PanelPrefix = "obstacle_8_002",
		AmplitudeDegrees = 28,
		PeriodSeconds = 2.8,
		PhaseStepSeconds = 0.55, -- per numeric suffix, so the five panels are not in lockstep
	},
	Bumper = {
		NamePrefixes = { "obstacle_18_001", "obstacle_19_001" },
		KnockbackSpeed = 36,
		UpwardSpeed = 14,
		ShoveSeconds = 0.12,
		RetriggerCooldown = 0.6,
		GuardSeconds = 0.6,
		SquashFrequencyHz = 3.2,
		SquashDampingRatio = 0.22,
		SquashImpulse = -4,
		MinimumSquash = 0.6,
		WidenScale = 0.35,
	},
	BeachBall = {
		NamePrefix = "ball_001",
		Density = 0.08,
		Friction = 0.7,
		Elasticity = 0.45,
		ResetBelowOffset = -80, -- studs below MapOrigin.Y
		ResetRadius = 420, -- studs from MapOrigin
		CheckIntervalSeconds = 0.5,
	},
}
