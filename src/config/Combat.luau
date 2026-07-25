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
		-- This should line up with the authored throw/release moment in
		-- Assets.Animations.Throw. The current clip is about 0.75s, so 0.38s
		-- leaves enough follow-through after the projectile releases.
		WindupDuration = 0.3,
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
		BounceFriction = 0.22,
		MaxBounces = 5,
		SettleSpeed = 10,
		SettleVerticalSpeed = 5,
		ContactSeparation = 0.08,
		MinBounceNormalSpeed = 1.5,
		MaxBounceContactsPerStep = 4,
		RollFriction = 18,
		RollSettleSpeed = 1.5,
		RollGroundSnap = 3,
		RemoteSmoothing = 18,
		BallFeel = {
			FlightStretchPerSpeed = 0.001,
			MaxFlightStretch = 0.16,
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
		FlashInTime = 0.035,
		FlashOutTime = 0.28,
		FlashPeakTransparency = 0.42,
		ConfirmHoldTime = 0.2,
		ConfirmFadeTime = 0.18,
	},

	-- Simplified hit capsule applied to every character (never per-limb).
	CharacterCapsule = {
		Height = 5,
		Radius = 1.5,
	},
}
