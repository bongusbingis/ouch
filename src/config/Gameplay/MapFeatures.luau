--!strict

-- Terrain feature tuning. Per-pad override via a "LaunchSpeed" attribute on the pad.
-- VerticalPadding widens a volume upward so a root just above the part counts as inside.
return {
	-- MaxOriginDistanceStuds catches a spawn marker authored (or accidentally dragged)
	-- somewhere nowhere near the arena, e.g. parked far below the map instead of removed.
	Spawns = { RootOffsetStuds = 3.5, MaxOriginDistanceStuds = 600 },
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
		ContactPadding = 0.75, -- modest reach beyond the authored paddle bounds
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
		ContactPadding = 0.75, -- modest reach beyond the authored bumper bounds
		KnockbackSpeed = 36,
		UpwardSpeed = 14,
		ShoveSeconds = 0.12,
		RetriggerCooldown = 0.6,
		GuardSeconds = 0.6,
		SquashFrequencyHz = 3.2,
		SquashDampingRatio = 0.22,
		SquashImpulse = -8,
		BeatImpulse = -4,
		-- The squash runs off a metronome locked to the track, not off whatever
		-- is loud right now. Loudness only supplies the onsets the metronome
		-- learns its tempo and phase from. BeatsPerPulse = 4 squashes on the
		-- downbeat of each bar: impulse-2-3-4, impulse-2-3-4. Set it to 1 to
		-- squash on every beat, or 2 for every other one.
		BeatsPerPulse = 4,
		BeatDefaultPeriodSeconds = 0.5, -- 120 BPM, used until the track is read
		BeatMinPeriodSeconds = 0.3, -- 200 BPM
		BeatMaxPeriodSeconds = 1.0, -- 60 BPM
		BeatLoudnessFloor = 8,
		BeatSensitivity = 1.35,
		BeatEnvelopeResponseHz = 3,
		BeatOnsetGapSeconds = 0.25, -- ignore rises closer than this so the tempo is learned from beats, not texture
		BeatTempoSamples = 8,
		BeatTempoAdaptRate = 0.35,
		BeatPhaseCorrection = 0.12,
		BeatPhaseWindow = 0.25, -- once locked, ignore onsets further than this fraction of a beat off the grid
		BeatLockedScale = 0.25, -- how much of the tempo and phase correction survives locking
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
	-- Authored arena pieces are matched by the name lists above. Splashdown
	-- course clones carry these attributes instead, so the same kits drive both
	-- without a course ever having to reuse an arena part name.
	Attributes = {
		Rotor = "Rotor", -- "spin" | "rock" | "slide"
		RotorAxis = "RotorAxis", -- "X" | "Y" | "Z", in the part's own frame
		RotorSpeed = "RotorSpeed", -- degrees per second, spin only
		RotorAmplitude = "RotorAmplitude", -- degrees for rock, studs for slide
		RotorPeriod = "RotorPeriod", -- seconds per full swing
		RotorPhase = "RotorPhase", -- seconds
		RotorCarries = "RotorCarries", -- riders are carried with the part
		Shove = "Shove", -- contact pushes the player along the surface motion
		ShoveSpeed = "ShoveSpeed",
		ShoveUpwardSpeed = "ShoveUpwardSpeed",
		ShoveSeconds = "ShoveSeconds",
		Bumper = "Bumper",
		Fan = "Fan",
		FanBlade = "FanBlade",
		DoorRow = "DoorRow",
		DoorIndex = "DoorIndex",
		ScriptableRoot = "ScriptableRoot", -- CollectionService tag on every Scriptables folder the kits drive
	},
	RotorBump = {
		ContactPadding = 0.75, -- modest reach beyond the authored rotor bounds
		KnockbackSpeed = 34,
		UpwardSpeed = 14,
		OutwardBias = 0.35,
		ShoveSeconds = 0.15,
		RetriggerCooldown = 0.8,
		GuardSeconds = 0.8,
		-- Below this surface speed the contact point is on the rotor's axis and
		-- has no direction of its own, so the push falls back to straight outward.
		MinimumSurfaceSpeed = 0.5,
	},
	Door = {
		-- Reach around a door slab within which an approaching root breaks a
		-- breakable door, before the collision would stop it.
		ContactPadding = 3,
		VerticalPadding = 1,
		BrokenSeconds = 1.6, -- client fall animation
	},
}
