--!strict

-- Every tunable for the touch input layer and the assists built on top of it.
-- One module on purpose: these numbers are tuned against each other, and the
-- A/B loop needs a single surface to point Roblox player configs at.
--
-- Each feature carries its own Enabled flag and a 0-1 Strength scalar. Strength
-- 0 must be behaviourally identical to Enabled = false, so a config rollback is
-- always a dial rather than a code path change.

return {
	-- Reference viewport height that pixel thresholds below were authored
	-- against. Thresholds scale by (actual height / this), so a phone and a
	-- tablet need the same physical thumb travel. Sane: leave at 1080.
	ReferenceViewportHeight = 1080,

	Zones = {
		-- Fraction of screen width given to the movement thumb. The remainder is
		-- the action zone. Sane: 0.3-0.5; below 0.3 the stick crowds the action
		-- area, above 0.5 there is not enough room to aim.
		MovementWidthFraction = 0.4,
		-- Mirrors the zones horizontally for left-handed players. Purely a zone
		-- layout flag; no gameplay behaviour changes.
		LeftHanded = false,
	},

	Gestures = {
		-- Movement past this promotes an undetermined touch to a drag. Authored
		-- in reference pixels. Sane: 8-20; below 8 a resting thumb jitters into
		-- a drag, above 20 taps feel like they need to be perfectly still.
		DragThresholdPixels = 12,
		-- A touch released before this, without moving, is a tap. Seconds.
		-- Sane: 0.18-0.35.
		TapMaxSeconds = 0.25,
		-- Held past this without moving, a touch becomes a charge. Matches
		-- TapMaxSeconds so there is no dead band between the two.
		HoldMinSeconds = 0.25,
		-- Charge reaches 1.0 this long after HoldMinSeconds. Seconds.
		-- Sane: 0.4-1.2.
		ChargeFullSeconds = 0.7,
		-- Second tap within this window of the first counts as a double tap.
		-- Seconds. Sane: 0.2-0.4.
		DoubleTapMaxSeconds = 0.3,
		-- A swipe needs at least this much travel, in reference pixels.
		-- Sane: 60-160.
		SwipeMinPixels = 90,
		-- And must complete within this long, in seconds. Sane: 0.2-0.5.
		SwipeMaxSeconds = 0.35,
		-- Half-angle tolerance around a cardinal direction, in degrees. A sloppy
		-- diagonal still registers. Sane: 25-45; above 45 directions overlap.
		SwipeAngleToleranceDeg = 35,
	},

	-- A tap near an enemy selects them directly. This is an input the player
	-- performs, not a decision made for them, so it is on by default.
	TapToTarget = {
		Enabled = true,
		Strength = 1,
		-- Selection radius as a multiple of the target's apparent on-screen
		-- height, so distant enemies need a more accurate tap. Sane: 0.6-1.8.
		RadiusScale = 1.1,
		-- Floor and ceiling on that radius in reference pixels, so a very far or
		-- very close target stays tappable without swallowing the screen.
		MinRadiusPixels = 44,
		MaxRadiusPixels = 220,
		-- Weight applied to world distance when scoring, relative to screen
		-- distance. Higher favours nearer enemies when two are equally close to
		-- the finger. Sane: 0-0.6.
		WorldDistanceWeight = 0.25,
	},

	-- Taps arriving during a cooldown or animation fire the moment the action
	-- becomes legal, instead of being dropped. Applied on every device so feel
	-- is consistent, but the window is short enough not to change PC timing.
	Buffer = {
		Enabled = true,
		-- Seconds an unfulfilled input waits. Sane: 0.1-0.25; above 0.25 inputs
		-- fire late enough that players notice the delay.
		WindowSeconds = 0.15,
	},

	-- Aim assists. Each one's on/off and 0-1 strength are per player and live in
	-- Config.PlayerAssist; these are the shapes those scalars act on.
	Assist = {
		-- Hardest limit on lead prediction: however fast a target moves, the
		-- throw can never leave the player's aim by more than this. Degrees.
		-- Sane: 6-20; past 20 the ball visibly does not go where you pointed.
		MaxLeadAngleDeg = 12,
		-- Rolling window of target velocity samples used to judge how steadily
		-- it is moving. Sane: 5-15; shorter reacts faster but is noisier.
		VelocitySamples = 8,
		-- Ceiling on camera adhesion, in degrees per second of pull. Must stay
		-- sub-conscious: if the player can feel the camera moving itself it
		-- reads as losing control. Sane: 10-40.
		AdhesionMaxDegPerSecond = 25,
		-- Largest fraction of drag speed friction may remove while over a
		-- target. Sane: 0.1-0.25; above 0.25 the camera feels stuck.
		FrictionMaxReduction = 0.18,
		-- Fraction of the cone at which assists begin fading to zero, so there
		-- is no discontinuity at the edge. Sane: 0.5-0.85.
		ConeFadeStartFraction = 0.6,

		-- Melee. The hammer's own Range and Width still decide what a swing
		-- actually hits; these only decide what the assists aim at.
		--
		-- Acquisition reach as a multiple of the hammer's range. Above 1 so
		-- there is someone to lunge at -- at exactly 1 the assist can only ever
		-- see targets already in range, and lunging becomes pointless.
		-- Sane: 1.2-2.0.
		MeleeAcquireRangeScale = 1.5,
		-- Acquisition half-angle for melee, in degrees. Wider than the ranged
		-- cone because a swing is a wide arc, not a line. Sane: 30-70.
		MeleeConeDeg = 50,
		-- Hardest limit on how far auto-face may rotate a swing away from the
		-- direction the player aimed. Degrees. Sane: 10-35; past 35 the swing
		-- visibly turns on its own and reads as losing control of the character.
		AutoFaceMaxAngleDeg = 22,
		-- Studs per second added to the swing dash at full lunge, on top of the
		-- hammer's DashSpeed. Sane: 0-30; above 30 the dash overshoots the
		-- target and the swing whiffs past them.
		LungeMaxExtraSpeed = 18,
	},

	-- With no ball held, a tap is ambiguous between swinging the hammer and
	-- catching an incoming ball. Catch wins only when one is genuinely inbound,
	-- so the hammer stays the default.
	ContextualCatch = {
		Enabled = true,
		-- How far ahead a ball's current velocity is projected when deciding it
		-- is inbound. Seconds. Sane: 0.3-1.0.
		LookaheadSeconds = 0.6,
		-- How close that projection must pass to the player, in studs.
		-- Sane: 6-16.
		ApproachRadiusStuds = 10,
	},
}
