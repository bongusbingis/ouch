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
		LaunchSpeed = 65, -- legacy authored speed; scaled into the airflow's steady travel speed
		FloatFactor = 0.65, -- larger values make the airflow approach its travel speed more quickly
		LiftSpeedScale = 0.25,
		LiftResponseSeconds = 0.35,
		MaxLiftAcceleration = 80,
		RadiusScale = 0.7, -- central opening, relative to the base's half-width
		ColumnHeight = 18,
		BottomTolerance = 0.5,
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
	-- Course platforms opt into server-applied three-dimensional carry. The
	-- authored arena keeps its original client rider path unless explicitly set.
	ServerCarry = {
		ContactTolerance = 1,
		MaxFrameSeconds = 0.2,
		MaxCarryDelta = 4,
		GuardSeconds = 0.4,
	},
	-- A hammer winds up slowly and strikes quickly. Opt into this rock profile;
	-- ordinary Rotor rock keeps its original sinusoidal timing.
	Hammer = { WindupSeconds = 1.8, StrikeSeconds = 0.3 },
	-- Punch walls extend, hold, retract, then rest. Extent is measured from the
	-- authored home position, not half the total travel as a sine slide would be.
	Piston = { PeriodSeconds = 3.2, ExtendStuds = 12, HoldSeconds = 0.6 },
	-- Only the marked sphere is a Big Ball. Its pole is ordinary geometry.
	-- Top-cap landings bounce; side contacts roll outward once per visit.
	BigBall = {
		CapDegrees = 40,
		BounceSpeed = 58,
		FloatFactor = 0.25,
		RollOffSpeed = 38,
		UpwardSpeed = 6,
		ShoveSeconds = 0.18,
		RetriggerCooldown = 0.65,
		GuardSeconds = 1,
		MaxFloatSeconds = 3,
		ContactPadding = 0.5,
	},
	-- Chevron direction is explicit because imported mesh pivots differ.
	-- Anchored belts use surface velocity, carrying characters and physics balls.
	Conveyor = { Speed = 15.6, Axis = "Z" },
	-- Tiles stay anchored; the server removes collision after a visible warning.
	-- RespawnSeconds = 0 means never; use a positive value on checkpoint routes.
	FallingTile = { DropDelaySeconds = 0.65, RespawnSeconds = 5 },
	-- Native hinges keep active seesaw planks server owned.
	Seesaw = {
		Axis = "X",
		AngularSpeed = 0.4,
		AngularResponsiveness = 1,
		ServoMaxTorque = 300,
		PlankDensity = 0.01,
	},
	-- Attribute fans can face along an explicit local axis and push beach balls.
	-- Unmarked fans keep the arena's world-up airflow direction.
	CourseFan = { BallSpeed = 32, BallAcceleration = 45 },
	-- Course-level liquid trajectory: height is an offset above its authored pose.
	-- Start/stop still belongs to the race; pauses are "height:seconds,...".
	RisingLiquid = { PauseFormat = "height:seconds,..." },
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
		ServerCarries = "ServerCarries", -- true on moving model; legacy Origin is accepted during migration
		RotorProfile = "RotorProfile", -- "hammer" (rock) or "piston" (slide)
		WindupSeconds = "WindupSeconds",
		StrikeSeconds = "StrikeSeconds",
		PistonPeriod = "PistonPeriod",
		PistonPhase = "PistonPhase",
		PistonExtendStuds = "PistonExtendStuds",
		HoldSeconds = "HoldSeconds",
		RotorAccel = "RotorAccel", -- degrees/s^2; requires MotionEpoch on the moving model
		RotorPhaseDegrees = "RotorPhaseDegrees", -- spin's initial angle, independent of rock/slide phase
		MotionEpoch = "MotionEpoch", -- synchronized start time on the moving model
		JumpPad = "JumpPad", -- marker on a model in Scriptables/JumpPads
		LaunchSpeed = "LaunchSpeed",
		FloatFactor = "FloatFactor",
		BeachBall = "BeachBall",
		FanAxis = "FanAxis", -- local X/Y/Z; omit for legacy world-up airflow
		FanDirection = "FanDirection", -- +1 or -1
		FanColumnHeight = "FanColumnHeight",
		FanBallSpeed = "FanBallSpeed",
		BigBall = "BigBall",
		CapDegrees = "CapDegrees",
		BounceSpeed = "BounceSpeed",
		RollOffSpeed = "RollOffSpeed",
		RetriggerCooldown = "RetriggerCooldown",
		GuardSeconds = "GuardSeconds",
		Conveyor = "Conveyor",
		ConveyorSpeed = "ConveyorSpeed",
		ConveyorAxis = "ConveyorAxis",
		FallingTile = "FallingTile",
		DropDelaySeconds = "DropDelaySeconds",
		RespawnSeconds = "RespawnSeconds",
		Seesaw = "Seesaw",
		SeesawAxis = "SeesawAxis",
		MaxTiltDegrees = "MaxTiltDegrees", -- legacy authored metadata; native hinge always uses +/-85
		SeesawResponse = "SeesawResponse", -- legacy authored metadata; native servo tuning is centralized
		ImpactVisual = "ImpactVisual", -- opt-in client-only ghost pulse for Rotor shoves
		RisingLiquid = "RisingLiquid",
		StartDelaySeconds = "StartDelaySeconds",
		RiseStudsPerSecond = "RiseStudsPerSecond",
		MaxHeight = "MaxHeight",
		PauseWaypoints = "PauseWaypoints",
		Shove = "Shove", -- contact pushes the player along the surface motion
		ShoveSpeed = "ShoveSpeed",
		ShoveUpwardSpeed = "ShoveUpwardSpeed",
		ShoveSeconds = "ShoveSeconds",
		ShoveContact = "ShoveContact", -- "mesh" uses actual collision contact; omit for legacy padded bounds
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
