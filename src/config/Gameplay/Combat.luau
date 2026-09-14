--!strict

-- Every combat feel constant. Units: studs, seconds, degrees.

return {
	Network = { MaxQueuedIntentsPerPlayer = 32 },
	MovementValidation = {
		CoordinateLimit = 100000,
		SampleSeconds = 0.1,
		BurstStuds = 32,
		WalkTolerance = 1.6,
		PlatformSpeedAllowance = 8,
		PlatformReachPadding = 8,
		UpwardSpeed = 70,
		MaxAirborneSeconds = 12,
		MinimumFallSpeed = 8,
		GroundToleranceStuds = 1.5,
		WallCheckMinimumStuds = 2,
		WallProbeRadius = 0.7,
		WallToleranceStuds = 2,
	},
	Dodgeball = {
		ThrowSpeed = 140,
		Gravity = 70,

		Charge = {
			FullSeconds = 0.7,
			-- Speed multiplier at full charge.
			MaxSpeedScale = 1.3,
		},

		-- Presentation-only throw preview.
		Preview = {
			FollowFrequency = 20,
			FollowDamping = 1,
			ImpactSamples = 12,
			Segments = 32,
			FovAtFullCharge = -12,
			FovFrequency = 9,
		},

		Radius = 1,
		HitForgiveness = 0.35, -- added to Radius for hit tests (device magnetism adds more)
		ThrowCooldown = 0.6,
		ThrowOriginMaxOffset = 6, -- max distance of throw origin from character center
		MaxFlightTime = 2,
		-- Zero on purpose: anything above zero is latency the thrower feels on their own input.
		WindupDuration = 0,
		ThrowAnimationName = "Throw",
		MomentumInheritance = 0.3,
		KnockbackSpeed = 70,
		KnockbackUpSpeed = 20,
		CatchDistance = 3.25,
		CatchWindow = 0.18,
		CatchCooldown = 0.65,
		CatchConeDeg = 110,
		ReleaseForwardOffset = 0.35,
		HeldVisualHandOffset = vector.create(0.08, -0.28, -0.35),
		OverhandReleaseRootOffset = vector.create(0.85, 2.15, -1.05),

		HomingTurnRateDeg = 72,
		HomingBreakAngleDeg = 55, -- lock fully broken at this angular error
		TargetSelectRange = 100, -- max soft-lock distance

		PickupRadius = 4,
		BounceRestitution = 0.52,
		BounceFriction = 0.8,
		MaxBounces = 5,
		SettleSpeed = 10,
		SettleVerticalSpeed = 5,
		ContactSeparation = 0.08,
		MinBounceNormalSpeed = 1.5,
		MaxBounceContactsPerStep = 4,
		RollFriction = 28,
		RollSettleSpeed = 1.5,
		RollGroundSnap = 3,
		RemoteSmoothing = 18,
		-- Client-side presentation prediction; hit resolution remains server-side.
		Prediction = {
			MaxSeconds = 0.4,
		},
		-- Ceiling (seconds) on how far ahead an in-flight ball's visual is led.
		MaxLatencyExtrapolation = 0.2,
		BallFeel = {
			FlightStretchPerSpeed = 0.01,
			MaxFlightStretch = 0.16,
			ChargeSquash = 0.08,
			-- The held ball sits between the camera and whatever is being aimed at,
			-- so it fades while charging rather than blocking the shot.
			ChargeAimTransparency = 0.55,
			ImpactImpulseScale = 0.018,
			MaxImpactSquash = 0.42,
			SpringFrequencyHz = 9,
			SpringDampingRatio = 0.34,
			RollWobbleScale = 0.045,
			RollWobbleHz = 5,
			LightImpactSpeed = 18,
			HeavyImpactSpeed = 75,
		},
		RestPulse = {
			FillColor = Color3.fromRGB(255, 181, 38),
			OutlineColor = Color3.fromRGB(255, 244, 176),
			BrightFillTransparency = 0.12,
			DimFillTransparency = 0.72,
			BrightOutlineTransparency = 0,
			DimOutlineTransparency = 0.5,
			CyclesPerSecond = 1.25,
		},

		SpawnCadence = 5, -- seconds between world ball spawns per spawn point
		SpawnSearchRadius = 3, -- spawn suppressed while a Free ball sits within this radius
		-- Ceiling on loose balls in the world. Replenishment exists so a round
		-- cannot run dry, not so the floor fills up.
		WorldBallCap = 10,
		-- Studs below MapOrigin.Y at which a loose ball counts as lost to the void
		-- and is returned to a spawn point instead of staying gone for the round.
		RecoveryBelowOffset = -80,
	},

	Hammer = {
		Cooldown = 1.5,
		ActiveDuration = 0.18,
		MissRecovery = 0.5,
		HitRecovery = 0.18,
		MissStunDuration = 0.25,
		MissStunWalkSpeedScale = 0.25,
		Range = 7,
		Width = 4,
		Height = 5,
		KnockbackSpeed = 85,
		KnockbackUpSpeed = 25,
		DashSpeed = 58,
		LineOfSightRadius = 0.35,
		AnimationName = "Swing",
		AutoGrip = {
			MinAxisDominanceRatio = 1.1,
			GripAlongLongAxis = -0.094,
		},
		-- Used only when the character's hand has no built-in
		-- RightGripAttachment (R6, or a custom avatar missing one).
		HandGripFallbackOffset = vector.create(0, 0, -0.05),
	},

	-- Client-only inflatable feel for the hammer visual. Stretch follows each
	-- cosmetic's dimension-resolved long axis; MinStretch must stay above -1.
	HammerFeel = {
		IdleWobbleAmplitude = 0.035,
		IdleWobbleHz = 1.1,
		SpringFrequencyHz = 5.5,
		SpringDampingRatio = 0.32, -- underdamped so squashes visibly rebound
		SwingStretchImpulse = 4.0,
		HitSquashImpulse = -10.0,
		MissDeflateAmount = 0.4,
		MaxStretch = 0.6,
		MinStretch = -0.55,
	},

	-- World-space paint splat played on dodgeball eliminations.
	Splat = {
		Lifetime = 3,
		SoundName = "Splat", -- SoundService.CombatAudio.Dodgeball.<name>
	},

	Elimination = {
		MaxHealth = 1,
		AngularImpulseY = 12,
		DesaturateTime = 0,
		ResaturateTime = 0.45,
		CameraZoomOutDistance = 22,
		CameraUpBias = 0.35,
	},

	DamageFeedback = {
		ShakeMagnitude = 3.6,
		ShakeRoughness = 24,
		ShakeFadeIn = 0,
		ShakeFadeOut = 0.2,
		ShakePositionInfluence = vector.create(0.12, 0.1, 0.1),
		ShakeRotationInfluence = vector.create(1.7, 1.1, 0.65),
	},

	-- Simplified hit capsule applied to every character (never per-limb).
	CharacterCapsule = {
		Height = 5,
		Radius = 1.2,
	},
}
