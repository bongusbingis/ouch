--!strict

-- Every feel-related tuning value for combat input and the combat camera.
--
-- This is the one file a designer should need to open. Nothing below is
-- referenced from more than one place, and no threshold is duplicated in a
-- module. If a value has to be changed in two places to change one behaviour,
-- that is a bug in this file, not in the caller.
--
-- Touch thresholds are expressed as a fraction of the viewport's smaller
-- dimension and then clamped to a pixel range. A phone and a tablet then need
-- roughly the same *physical* thumb travel, which raw pixel constants cannot
-- express: 40px is a flick on a phone and a twitch on a tablet.
--
-- Every value has a working default. Nothing here needs setup before playing,
-- but none of it is finished either -- these are starting points chosen to be
-- sane, and real numbers only come out of testing on real devices.

export type Scaled = {
	-- Fraction of the smaller viewport dimension.
	Fraction: number,
	-- Pixel floor and ceiling, so tiny and huge screens both stay usable.
	MinPixels: number,
	MaxPixels: number,
}

return {
	--==================================================================
	-- TAP -- the quick "throw now" gesture
	--==================================================================
	Tap = {
		-- Note: there is no tap duration here. Charge.HoldDelay already defines
		-- the window -- a touch still undecided at that point becomes a charge --
		-- so a second ceiling could only ever be unreachable or contradict it.

		-- How far the finger may drift and still count as a tap. Fingers are
		-- never still; this is tremor tolerance, not a target.
		-- Higher: forgiving of shaky hands and imprecise screens.
		-- Too high: small deliberate camera nudges become throws, which is the
		--   worst failure this system can have.
		-- Symptom to lower it: "I was just adjusting my aim and it threw".
		MaxDistance = { Fraction = 0.022, MinPixels = 10, MaxPixels = 26 } :: Scaled,
	},

	--==================================================================
	-- CAMERA -- when a touch stops being a possible attack
	--==================================================================
	Camera = {
		-- Movement past this hands the touch to the camera permanently. It is
		-- deliberately close to Tap.MaxDistance: the band between them is the
		-- ambiguous zone, and a narrow band means fewer touches sit in limbo.
		-- Higher: the camera feels sticky and slow to engage.
		-- Lower: camera engages eagerly, but taps get stolen mid-press.
		-- Symptom to lower it: dragging feels like it "catches" before moving.
		ClaimDistance = { Fraction = 0.028, MinPixels = 12, MaxPixels = 34 } :: Scaled,

		-- A fast movement claims the camera even before ClaimDistance, because
		-- speed alone is strong evidence of a drag. Pixels per second.
		-- Lower: flicks are recognised as camera sooner.
		-- Too low: the initial acceleration of a tap trips it and taps are lost.
		ClaimVelocity = { Fraction = 1.4, MinPixels = 500, MaxPixels = 2600 } :: Scaled,

		-- Note: there is no rebase setting. The camera consumes per-frame deltas
		-- and is never suppressed by classification, so a touch that becomes a
		-- drag has already been panning the whole time. There is no accumulated
		-- displacement waiting to be applied and therefore no jump to prevent.

		-- Multiplier while a charge is being held and the same finger is also
		-- aiming. Slightly under 1 helps fine adjustment without feeling heavy.
		-- Lower: steadier aim while charging, but sluggish if pushed far.
		ChargeSensitivityMultiplier = 0.9,

		-- Note: there is no post-charge deadzone either. Filtering the first few
		-- pixels would require intercepting the camera's own input, which this
		-- layer deliberately never does. The sensitivity multiplier above covers
		-- the same need without taking ownership of the camera.
	},

	--==================================================================
	-- CHARGE -- press and hold
	--==================================================================
	Charge = {
		-- How long a touch must be held before it becomes a charge. The single
		-- most important number for how mobile combat feels.
		-- Higher: taps are safer, but charging feels late and unresponsive.
		-- Lower: charge feels instant, but ordinary taps start charging.
		-- Symptom to raise it: taps sometimes charge. To lower it: holding
		--   feels like nothing is happening.
		HoldDelay = 0.18,

		-- How far the finger may wander before the hold threshold and still be
		-- allowed to become a charge. Larger than the tap slop, because holding
		-- still for a fifth of a second is harder than tapping.
		-- Too low: charging fails for players who cannot hold perfectly still.
		HoldSlop = { Fraction = 0.05, MinPixels = 18, MaxPixels = 60 } :: Scaled,
	},

	--==================================================================
	-- BOTTOM SWIPE -- alternate gesture for the same normal throw
	--==================================================================
	-- This is NOT a separate attack. It produces exactly the normal throw a tap
	-- produces. It exists so players who rest their thumb low on the screen have
	-- a natural way to attack without reaching for the middle.
	--
	-- It fires the moment it is recognised rather than on release, because a
	-- flick that waits for the finger to lift feels laggy.
	--
	-- While a swipe candidate is alive the camera stops taking touch rotation.
	-- Without that the flick throws *and* pans, which is exactly the confusion
	-- between attacking and looking that this whole layer exists to remove. The
	-- suppression is released the instant the candidate is ruled out, and because
	-- the camera consumes per-frame deltas there is nothing banked up to snap.
	BottomSwipe = {
		Enabled = true,

		-- Height of the activation strip, as a fraction of viewport height
		-- measured up from the bottom.
		-- Higher: easier to start a swipe; encroaches on the middle tap area.
		RegionHeightFraction = 0.28,

		-- Horizontal bounds of the strip, as fractions of viewport width. Full
		-- width: the movement stick and jump button register their real
		-- rectangles as exclusions, which is far more accurate than guessing at
		-- fractions. The old 0.28-0.78 strip sat in the middle of the screen,
		-- where no thumb rests -- a right thumb sits around 0.85-0.95.
		RegionMinXFraction = 0,
		RegionMaxXFraction = 1,

		-- Travel required before the direction of a swipe is judged at all.
		-- The first move sample is 1-5px and is mostly digitizer noise; judging
		-- direction on it rejected almost every real swipe.
		-- Higher: more forgiving of a thumb that starts its arc sideways.
		-- Too high: a sideways drag stays a swipe candidate for longer than it
		--   should before falling through to the camera.
		-- Small on purpose. The camera is suppressed while direction is unknown,
		-- so this is also the dead zone a sideways drag from the strip pays
		-- before the view starts moving. Big enough to clear digitizer noise,
		-- small enough not to be felt. Sane: 8-20px.
		DirectionSampleMinPixels = { Fraction = 0.012, MinPixels = 9, MaxPixels = 18 } :: Scaled,

		-- Minimum upward travel before the gesture counts.
		-- Higher: fewer accidental swipes; more thumb travel required.
		MinDistance = { Fraction = 0.09, MinPixels = 44, MaxPixels = 150 } :: Scaled,

		-- The gesture must complete within this long. A slow upward drag is a
		-- camera pan, not a flick.
		--
		-- This also bounds how long the camera can stay suppressed: the view is
		-- held still while a swipe candidate is alive, so a generous window here
		-- would let a slow upward pan freeze the camera. Sane: 0.2-0.35.
		MaxDuration = 0.28,

		-- Minimum speed, in pixels per second. Kept low enough that the gesture
		-- is not an execution test -- it is a convenience, not a skill check.
		-- This is now an honest number: the velocity estimate used to ramp from
		-- zero, so a swipe had to be ~14% faster than whatever was configured.
		MinVelocity = { Fraction = 0.7, MinPixels = 260, MaxPixels = 1400 } :: Scaled,

		-- How closely the movement must point up, as a dot product against
		-- screen-up. 1 is exactly vertical, 0 is a right angle.
		-- Higher: stricter, fewer false positives, more failed swipes.
		-- 0.72 is roughly a 44-degree cone either side of straight up, which a
		-- thumb arcing from the bottom of the screen can actually stay inside.
		--
		-- There is no separate horizontal-ratio limit: it encoded the identical
		-- cone, so it only ever doubled the chance of a rounding-edge rejection.
		DirectionDot = 0.72,
	},

	--==================================================================
	-- CONTROLLER
	--==================================================================
	Controller = {
		-- Analog trigger depth that counts as pressed / released. The gap
		-- between them is hysteresis: without it a trigger resting near the
		-- threshold chatters between states and spams throws.
		-- Press lower: lighter pulls register, less deliberate.
		TriggerPressThreshold = 0.55,
		TriggerReleaseThreshold = 0.35,
	},

	--==================================================================
	-- COMBAT CAMERA
	--==================================================================
	-- Defaults are deliberately OFF with a free cursor. The lobby is a menu and
	-- must keep its mouse; the arena turns combat on explicitly. Anything that
	-- needs the cursor back (shop, settings, results) asks for it through the
	-- Combat API rather than writing to UserInputService itself.
	CombatCamera = {
		-- Kill switch for the whole combat camera, for testing without touching
		-- game code. This is NOT what keeps the lobby's cursor free -- that comes
		-- from the runtime flag, which starts off until a place calls
		-- setCameraEnabled(true). Turning this off disables the camera
		-- everywhere, including the arena.
		Enabled = true,

		HideMouseCursor = true,
		LockMouseToCenter = true,

		-- Camera offset in character space: +X right, +Y up, +Z back. This is
		-- the over-the-right-shoulder framing. Roblox's own shift lock uses
		-- (1.75, 0, 0); slightly less lateral and a little height reads better
		-- with this game's chunky proportions and keeps the reticle off the
		-- character's head.
		-- Larger X: character sits further left, more of the world visible on
		--   the right; too far and aiming stops feeling connected to the body.
		ShoulderOffset = Vector3.new(1.5, 0.35, 0),

		-- Whether the character's body turns to follow where the camera looks.
		-- This is deliberately independent of the camera lock: turning it off
		-- keeps the locked, hidden-cursor, shoulder-offset camera exactly as it
		-- is and only stops the body yawing. Useful for strafe-style movement
		-- or when a pose system wants to own facing.
		CharacterFollowsCameraYaw = false,

		-- Note: there is deliberately no responsiveness value here. Body yaw uses
		-- Roblox's own RotationType.CameraRelative, the same path shift lock
		-- uses, so the engine remains the single owner of root rotation and its
		-- turn rate is engine-governed. A tunable spring would mean disabling
		-- Humanoid.AutoRotate and taking that ownership away, which buys a knob
		-- and costs a fight over who turns the character.

		-- Multiplier on mouse look while the combat camera owns the cursor.
		MouseSensitivityMultiplier = 1,
	},

	--==================================================================
	-- DEBUG
	--==================================================================
	Debug = {
		-- Draws touch regions and per-touch classification on screen.
		Enabled = false,
		-- Prints one line per classification decision. Off by default: this is
		-- several lines per second during normal play.
		LogClassification = false,
	},
}
