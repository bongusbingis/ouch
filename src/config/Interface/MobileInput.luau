--!strict

-- Touch input and assist tuning.

local Combat = require(script.Parent.Parent.Gameplay.Combat)

return {
	-- Reference viewport height for pixel thresholds.
	ReferenceViewportHeight = 1080,

	Zones = {
		-- Fraction of screen width given to the movement thumb.
		MovementWidthFraction = 0.4,
		-- Mirrors the zones horizontally for left-handed players. Purely a zone
		-- layout flag; no gameplay behaviour changes.
		LeftHanded = false,
	},

	Gestures = {
		-- Movement threshold in reference pixels.
		DragThresholdPixels = 12,
		-- A stationary touch released before this is a tap. Seconds.
		TapMaxSeconds = 0.25,
		-- Held past this without moving, a touch becomes a charge. Matches
		-- TapMaxSeconds so there is no dead band between the two.
		HoldMinSeconds = 0.25,
		ChargeFullSeconds = Combat.Dodgeball.Charge.FullSeconds,
		-- Double-tap interval. Seconds.
		DoubleTapMaxSeconds = 0.3,
		-- Minimum swipe travel in reference pixels.
		SwipeMinPixels = 90,
		-- Maximum swipe duration. Seconds.
		SwipeMaxSeconds = 0.35,
		-- Half-angle tolerance around a cardinal direction, in degrees.
		SwipeAngleToleranceDeg = 35,
	},

	-- A tap near an enemy selects them directly. This is an input the player
	-- performs, not a decision made for them, so it is on by default.
	TapToTarget = {
		Enabled = true,
		Strength = 1,
		-- Selection radius as a multiple of the target's apparent on-screen height.
		RadiusScale = 1.1,
		-- Floor and ceiling on that radius in reference pixels, so a very far or
		-- very close target stays tappable without swallowing the screen.
		MinRadiusPixels = 44,
		MaxRadiusPixels = 220,
		-- Weight applied to world distance when scoring, relative to screen
		-- Weight for world distance when screen distances are similar.
		WorldDistanceWeight = 0.25,
	},

	-- Taps during a cooldown or animation wait until the action is legal.
	Buffer = {
		Enabled = true,
		-- Seconds an unfulfilled input waits.
		WindowSeconds = 0.15,
	},

	-- Aim assists. Each one's on/off and 0-1 strength are per player and live in
	-- Config.PlayerAssist; these are the shapes those scalars act on.
	Assist = {
		-- Maximum lead-prediction angle, in degrees.
		MaxLeadAngleDeg = 12,
		-- Number of target velocity samples used for prediction.
		VelocitySamples = 8,
		-- Maximum camera adhesion speed, in degrees per second.
		AdhesionMaxDegPerSecond = 25,
		-- Maximum fraction of drag speed removed over a target.
		FrictionMaxReduction = 0.18,
		-- Cone fraction at which assist strength begins fading.
		ConeFadeStartFraction = 0.6,

		-- Melee. The hammer's own Range and Width still decide what a swing
		-- actually hits; these only decide what the assists aim at.
		--
		-- Acquisition reach as a multiple of the hammer's range.
		MeleeAcquireRangeScale = 1.5,
		-- Acquisition half-angle for melee, in degrees.
		MeleeConeDeg = 50,
		-- Maximum auto-facing angle from the player's aim, in degrees.
		AutoFaceMaxAngleDeg = 22,
		-- Extra swing dash speed at full lunge, in studs per second.
		LungeMaxExtraSpeed = 18,
	},

	-- With no ball held, a tap is ambiguous between swinging the hammer and
	-- catching an incoming ball. Catch wins only when one is genuinely inbound,
	-- so the hammer stays the default.
	ContextualCatch = {
		Enabled = true,
		-- Ball velocity lookahead when checking whether it is inbound. Seconds.
		LookaheadSeconds = 0.6,
		-- Maximum projected approach distance, in studs.
		ApproachRadiusStuds = 10,
	},
}
