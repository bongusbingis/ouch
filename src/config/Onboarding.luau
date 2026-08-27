--!strict

-- First-session onboarding. Every tuning value the experience is iterated on
-- lives here so timing, difficulty and assistance can be adjusted from
-- analytics without touching flow code.

-- Version gates re-entry: bumping it does NOT force old players back through
-- onboarding. Migration is deliberate -- OnboardingState.eligibility only ever
-- reads Status, never Version, so raising this is safe by default.
local CURRENT_VERSION = 1

return {
	Version = CURRENT_VERSION,

	-- Projected by the server onto a live training dummy, carrying the id of the
	-- player it belongs to. The client draws its target marker from this, so the
	-- name lives here where both sides already read.
	TargetAttribute = "OnboardingTarget",

	Eligibility = {
		AutoStartEnabled = true,
		ResumeEnabled = true,
		SkipEnabled = true,
		-- How long the client waits for profile-backed onboarding state before
		-- failing open to the normal lobby rather than stranding the player.
		ResolveTimeoutSeconds = 8,
	},

	Timing = {
		IntroSeconds = 1.1,
		PromptDelaySeconds = 0.25,
		SuccessHoldSeconds = 0.7,
		InactivityHintSeconds = 6,
		EscalatedHintSeconds = 13,
		CelebrationSeconds = 2.4,
		TransitionSeconds = 1.0,
	},

	Training = {
		-- Distances out from MapOrigin along the player's approach axis, in studs.
		-- The inner island ends at ~82, so anything below that stands on it and
		-- anything above is out over the bridge or the elimination ring.
		ThrowDummyDistance = 70,
		ThrowDummyWalkSpeed = 7,
		BridgeWaypointDistance = 82,
		BonkDummyDistance = 60,
		BonkDummyWalkSpeed = 15,
		ChargeDummyDistance = 22,
		BrawlDummyCount = 4,
		BrawlRingRadius = 38,
		BrawlDummyWalkSpeed = 11,
		-- Dropped from this far above the surface so a dummy always lands on the
		-- floor rather than spawning part-buried in it.
		DummySpawnClearanceStuds = 3,
		-- How close a dummy closes before holding position, and how often it
		-- re-aims. Humanoid:MoveTo gives up on its own after a while, so the
		-- repath is what keeps a dummy following rather than stalling short.
		DummyStandoffStuds = 5,
		DummyRepathSeconds = 0.35,
		-- Hit radius added around a dummy's own size. Generous on purpose: a
		-- near miss during the first lesson should still read as a hit.
		TargetLeniencyStuds = 5,
		EscalatedLeniencyStuds = 9,
		MinimumChargeAlpha = 0.35,
	},

	Assist = {
		-- Training throws curve toward the dummy so a first attempt lands. The
		-- cone keeps it honest: a throw the player clearly did not aim near the
		-- target is left alone rather than yanked across the arena.
		TurnRateDegPerSecond = 260,
		AcquireConeDeg = 55,
		MaxRangeStuds = 140,
	},

	World = {
		-- Every learner trains in their own clone of the authored arena, spaced
		-- far enough apart on a ring that no two sessions can see or reach one
		-- another, and far below the lobby so neither collides with the other.
		ArenaOrigin = Vector3.new(0, -900, 0),
		ArenaSpacingStuds = 700,
		ArenasPerRing = 8,
		-- MapOrigin is authored at the centre of the tower, well above the ground
		-- the player actually walks on. This is the drop from marker to surface.
		SurfaceOffsetY = -30.5,
		-- The pink elimination ring, described as a radial band out from
		-- MapOrigin with the bridge corridor carved out of it. Expressed as
		-- geometry rather than named parts so re-exporting the map cannot break it.
		RingInnerRadius = 84,
		RingOuterRadius = 118,
		BridgeInnerRadius = 82,
		BridgeOuterRadius = 128,
		BridgeHalfWidth = 16,
		-- Depth below the walking surface at which a player counts as fallen.
		FallRecoveryDepth = 60,
	},

	Dummy = {
		-- This is read on small, cheap screens by players who may not know what
		-- they are looking for, so a target never relies on one signal. The body
		-- is flattened to a single loud colour and a solid marker floats over the
		-- head -- both plain geometry that renders at any graphics quality -- and
		-- the highlight is a bonus on top for devices that do draw it.
		BodyColor = Color3.fromRGB(255, 0, 64),
		FillColor = Color3.fromRGB(255, 0, 64),
		OutlineColor = Color3.new(1, 1, 1),
		FillTransparency = 0.25,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		-- The marker is drawn by the client so it can turn to face whoever is
		-- looking at it: a flat arrow mesh only reads from some angles, and the
		-- player circles these dummies constantly during the mini-fight. Tinted
		-- so it never reads as the waypoint arrow.
		MarkerColor = Color3.fromRGB(255, 238, 0),
		MarkerScale = 2.2,
		MarkerHeightStuds = 5.5,
		MarkerBobStuds = 0.7,
		MarkerBobFrequency = 3.2,
	},

	Impact = {
		RingColor = Color3.fromRGB(255, 238, 0),
		RingThickness = 0.6,
		RingStartStuds = 3,
		RingEndStuds = 26,
		RingSeconds = 0.45,
		ConfettiCount = 14,
		ConfettiColors = {
			Color3.fromRGB(255, 0, 64),
			Color3.fromRGB(255, 238, 0),
			Color3.fromRGB(97, 255, 237),
			Color3.fromRGB(142, 31, 232),
		},
		ConfettiSize = Vector3.new(0.9, 0.9, 0.9),
		ConfettiSeconds = 0.9,
		ConfettiSpeed = 9,
		ConfettiRise = 7,
	},

	Waypoint = {
		-- The arrow floats in front of the player and turns to point the way. It
		-- is presentation only and never gates progress.
		DistanceStuds = 7,
		HeightStuds = 3,
		ArriveRadiusStuds = 10,
		-- A dummy is released from the arrow once the player is close enough to
		-- swing at it, which is a shorter reach than arriving at a place.
		MeleeArriveRadiusStuds = 9,
		BobAmplitudeStuds = 0.6,
		BobFrequency = 2.2,
		TurnResponsiveness = 12,
	},

	Effects = {
		CameraImpulse = 0.55,
		HapticIntensity = 0.55,
		ParticleIntensity = 1,
	},

	Analytics = {
		Funnel = "Onboarding",
		Steps = {
			Started = { step = 1, name = "Started" },
			NormalThrow = { step = 2, name = "NormalThrow" },
			Hammer = { step = 3, name = "Hammer" },
			ChargedThrow = { step = 4, name = "ChargedThrow" },
			Practice = { step = 5, name = "Practice" },
			Completed = { step = 6, name = "Completed" },
		},
	},
}
