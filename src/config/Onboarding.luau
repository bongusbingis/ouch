--!strict

-- Every tunable the first-session onboarding reads. Values here are the ones
-- worth iterating on against the funnel in Config.Analytics; nothing else in
-- the onboarding code carries a magic number.

export type TargetSpec = {
	-- Offset from the player's spawn, in studs: +Z is the direction they face on
	-- arrival. Native vectors rather than Vector3 so the pure layout module that
	-- reads them stays runnable headlessly.
	Offset: vector,
	-- Extra hit forgiveness added to the dummy's capsule radius for this step.
	Forgiveness: number,
}

return {
	-- Bumping this is how a redesigned onboarding is rolled out. Players whose
	-- stored state belongs to an older version are NOT dragged back through it;
	-- OnboardingState.migrate decides that deliberately, per version.
	Version = 1,

	Eligibility = {
		-- The master switch. Off routes every player straight to the lobby.
		AutoStartEnabled = true,
		-- Resume from the last stored checkpoint instead of restarting at zero.
		ResumeEnabled = true,
		SkipEnabled = true,
		-- A second Skip press is required inside this window; a single stray tap
		-- never costs a player the tutorial.
		SkipConfirmSeconds = 6,
		-- How long the client waits for the server's eligibility answer before
		-- failing open to the normal lobby. A player must never be stranded
		-- behind a loading screen because a profile did not load.
		ResolveTimeoutSeconds = 8,
	},

	Timing = {
		-- Delay between arriving in the ring and the first prompt appearing.
		-- Short: the player already has control, this is only the beat that
		-- lets the camera settle.
		FirstPromptSeconds = 0.35,
		-- Quiet time before the prompt re-animates and the target pulses.
		InactivityHintSeconds = 6,
		-- Quiet time before the stronger hint (highlight, wider forgiveness).
		EscalatedHintSeconds = 12,
		-- Failed attempts before assistance escalates, independent of time.
		EscalateAfterAttempts = 3,
		-- Gap between a step succeeding and the next prompt. Kept under a second
		-- so momentum never drops.
		StepAdvanceSeconds = 0.55,
		-- The whole celebration, from the last bot falling to the lobby reveal.
		CelebrationSeconds = 2.4,
		-- A dummy that was knocked out returns after this long, so a missed
		-- follow-up throw is never a dead end.
		DummyRespawnSeconds = 1.6,
		-- The ball is handed back this long after it comes to rest, so a miss
		-- costs a beat rather than a walk.
		BallReturnSeconds = 0.9,
		-- Hard ceiling on one onboarding session. Past this the player is let
		-- into the lobby with whatever progress they have, so no bug can trap
		-- them in training.
		SessionTimeoutSeconds = 420,
	},

	Training = {
		-- Ring geometry, in studs.
		RingRadius = 40,
		WallHeight = 14,
		FloorThickness = 2,
		-- Onboarding rings are laid out on a grid far from the lobby proper so
		-- two new players never see or interfere with each other.
		Origin = vector.create(0, 1200, 0),
		SlotSpacing = 180,
		SlotsPerRow = 4,
		-- Anything below this height relative to the ring floor is a fall, and
		-- the player is returned to their spawn with progress intact.
		FallRecoveryDepth = 25,
		-- Where each lesson's dummy stands. Close enough that the first throw is
		-- a gimme; the charge target is far enough that a tap throw falls short.
		Targets = {
			NormalThrow = { Offset = vector.create(0, 0, 18), Forgiveness = 1.5 } :: TargetSpec,
			Hammer = { Offset = vector.create(0, 0, 7), Forgiveness = 0.5 } :: TargetSpec,
			ChargedThrow = { Offset = vector.create(0, 6, 44), Forgiveness = 2 } :: TargetSpec,
		},
		-- Extra forgiveness added once assistance has escalated.
		EscalatedForgiveness = 2.5,
		-- The hammer dummy walks toward the player and stops here.
		HammerApproachStuds = 7,
		DummyWalkSpeed = 7,
		PracticeBotCount = 2,
		PracticeBotWalkSpeed = 9,
		-- Practice ends on either condition, whichever lands first.
		PracticeKnockouts = 2,
		PracticeMaxSeconds = 18,
		-- The charge lesson only accepts a throw released above this alpha, so
		-- "hold for power" is actually demonstrated rather than tapped past.
		MinimumChargeAlpha = 0.45,
	},

	UI = {
		-- How long the success beat stays on the panel before the next prompt.
		PromptSuccessHoldSeconds = 0.45,
		-- Skip stays discoverable without competing with the world.
		SkipCornerInset = 0.02,

		-- The instruction panel, in the game's own nine-slice treatment. It sits
		-- in the top band so it clears the reticle, every touch region and the
		-- centre where the confirmation modal appears.
		Panel = {
			TopScale = 0.045,
			WidthScale = 0.44,
			HeightScale = 0.16,
			AspectRatio = 3.4,
			MaxPixels = Vector2.new(760, 224),
			MinPixels = Vector2.new(300, 88),
		},

		-- The floating input indicator. Its position is computed from the real
		-- touch regions rather than set here; these are only its size, colour and
		-- the gap it keeps from the reticle and the swipe region.
		Gesture = {
			SizeScale = 0.07,
			MinPixels = 44,
			MaxPixels = 68,
			-- Gap the indicator keeps from the reticle above it and the swipe
			-- region below it. Widening this past the room a laptop viewport has
			-- pushes the indicator to sit beside the reticle instead.
			ClearancePixels = 16,
			-- Height of the word under the glyph, as a fraction of the glyph.
			LabelScale = 0.55,
			Color = Color3.fromRGB(255, 224, 78),
			InkColor = Color3.fromRGB(24, 41, 48),
		},
	},

	Effects = {
		-- Scales every onboarding-owned camera impulse, particle burst, and
		-- haptic pulse in one place, so intensity is tunable and reduced-motion
		-- can drop it to zero without hunting through call sites.
		Intensity = 1,
		CameraImpulseStuds = 0.55,
		HapticStrength = {
			Hit = 0.35,
			Bonk = 0.6,
			ChargeTick = 0.2,
			FullCharge = 0.45,
			Complete = 0.8,
		},
	},

	-- Prototype-only. Named here so the replacement pass has one list to work
	-- from; see docs/onboarding.md.
	Prototype = {
		FloorColor = Color3.fromRGB(255, 214, 92),
		AccentColor = Color3.fromRGB(102, 232, 255),
		WallColor = Color3.fromRGB(255, 116, 158),
		ColumnColor = Color3.fromRGB(146, 118, 255),
		PortalColor = Color3.fromRGB(122, 255, 178),
		DummyColor = Color3.fromRGB(255, 176, 59),
		SpotlightBrightness = 6,
	},
}
