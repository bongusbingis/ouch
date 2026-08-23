--!strict

-- Every combat feel constant lives here and is cmdr-tunable at runtime (M3).
-- Units: studs, seconds, degrees.

return {
	Dodgeball = {
		ThrowSpeed = 140,
		Gravity = 70,

		-- Held throw. A charged ball is simply faster, which is what makes it
		-- flatter, longer and harder to dodge -- the arc is not special-cased.
		-- It cannot hit harder than a normal throw, because a dodgeball hit
		-- already eliminates outright.
		Charge = {
			-- Speed multiplier at full charge; the uncharged throw is 1.
			-- Sane: 1.15-1.6. The catch test samples closest approach over a
			-- tick, so speed does not break it geometrically -- what shrinks is
			-- the defender's reaction time, and past 1.6 that is short enough
			-- that a full charge is effectively uncatchable.
			MaxSpeedScale = 1.3,
		},

		-- The arc drawn while a throw is charging. Presentation only: it predicts
		-- the same parabola the sim will fly, but nothing reads it back.
		Preview = {
			-- How quickly the drawn arc follows the camera, in spring Hz. The arc
			-- is smoothed rather than tracking raw aim, because a beam redrawn
			-- from an unfiltered look vector shimmers with every frame of input
			-- noise. Lower is calmer but lags the camera; higher is tighter and
			-- shows more jitter. Sane: 12-30.
			FollowFrequency = 20,
			-- Damping for that follow. At or just above 1 it settles without
			-- overshoot, which is what an aiming aid wants -- a bouncy arc reads
			-- as inaccurate.
			FollowDamping = 1,
			-- How many straight pieces the flight path is sampled into when
			-- looking for the impact point. Higher is a more exact landing spot
			-- at the cost of that many short raycasts per frame. Sane: 8-16.
			ImpactSamples = 12,
			-- Beam subdivisions. Purely visual smoothness of the curve itself.
			Segments = 32,
			-- Field-of-view pulled in at full charge, in degrees. Negative zooms
			-- in. Scales with charge rather than snapping on press.
			FovAtFullCharge = -12,
			-- How fast the field of view follows, in spring Hz. Sane: 6-14.
			FovFrequency = 9,
		},

		Radius = 1,
		HitForgiveness = 0.35, -- added to Radius for hit tests (device magnetism adds more)
		ThrowCooldown = 0.6,
		ThrowOriginMaxOffset = 6, -- max distance of throw origin from character center
		MaxFlightTime = 2,
		-- Delay between the throw input and the ball leaving the hand. Zero on
		-- purpose: the ball is gone the instant the press ends, and the wind-up
		-- pose held during charge is what telegraphs a throw to opponents.
		-- Anything above zero is latency the thrower feels on their own input.
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
		-- Client-side predicted release. Without it the ball sits in the thrower's
		-- hand for a full round trip after the input, which is the entire moment a
		-- throw is judged by. Presentation only -- what a throw hits is still
		-- decided server-side from the server's own release position.
		Prediction = {
			-- Longest a predicted ball is drawn flying without the server having
			-- confirmed it left the hand. Past this the throw is treated as
			-- refused and the visual returns to wherever the server says the ball
			-- is. Wants to be comfortably above a bad round trip but short enough
			-- that a refused throw does not leave a ghost. Sane: 0.3-0.6.
			MaxSeconds = 0.4,
		},
		-- Ceiling on how far ahead an in-flight ball's visual is extrapolated,
		-- in seconds. The lead applied is network latency plus the smoothing
		-- time constant, so the drawn ball sits where the authoritative one
		-- already is instead of trailing it; this is what a latency spike may
		-- not exceed.
		MaxLatencyExtrapolation = 0.2,
		BallFeel = {
			FlightStretchPerSpeed = 0.01,
			MaxFlightStretch = 0.16,
			ChargeSquash = 0.08,
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
	},

	-- Simplified hit capsule applied to every character (never per-limb).
	CharacterCapsule = {
		Height = 5,
		Radius = 1.2,
	},
}
