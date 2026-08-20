--!strict

-- Tuning for the throwing-arm pose: the wind-up, the pause at the top of it, and
-- the hand-off back to the authored throw.
--
-- Scope is deliberately narrow. Nothing here moves the torso, head or facing,
-- and nothing is driven by the camera except the direction the ball is presented
-- along. The character's body is the animation's business; this layer owns one
-- arm, and only while a ball is in hand.
--
-- The wind-up is expressed in the character's own space rather than in camera
-- space, so the hand draws back to the same readable spot every time regardless
-- of where the player is looking. That predictability is what makes a charged
-- throw feel like a committed action instead of a cursor.

return {
	Enabled = true,

	Arm = {
		-- Where the shoulder sits relative to the character's root, in studs
		-- (right, up, forward). Deliberately a constant rather than read from the
		-- animated limb: reading the real shoulder would feed the solver's own
		-- output back into its input and make the pose crawl.
		-- Measure once for your rig and leave it.
		ShoulderOffset = vector.create(1.5, 1, 0),

		-- Resting hold: how far in front of the shoulder the hand presents the
		-- ball, in studs, along aim. R15 shoulder-to-hand is about 2.8 studs
		-- fully extended, so staying under that keeps a bend in the elbow
		-- instead of locking it straight. Sane: 1.8-2.5.
		ReadyDistance = 2.2,

		-- The wind-up spot, in character space relative to the shoulder
		-- (right, up, back). This is the pose the hand pauses at while the
		-- player holds charge, so it is the single most important value here for
		-- how a charged throw reads. Back and up gives a classic overhand coil.
		WindupOffset = vector.create(0.5, 0.75, 2),

		-- How much further the wind-up reaches at full charge, as a fraction.
		-- This is the cartoon dial: 0 means a full charge looks like a light one,
		-- 0.5 means it visibly winds up half again as far. Sane: 0.15-0.6.
		ChargeStretch = 0.35,

		-- Elbow pole, in character space relative to the shoulder (right, up,
		-- back). Keeps the elbow flaring out and back instead of folding through
		-- the torso or snapping inside out. Tune with Debug.PoseElbowPole on.
		PoleOffset = vector.create(2.2, -0.4, 1.4),

		-- Solver smoothing in seconds. Small, because the springs below already
		-- do the shaping and stacking two smoothers reads as lag.
		SmoothTime = 0.04,
	},

	-- Blend weight per visual state.
	--
	-- The split that matters is not high versus low, it is which animation the
	-- solver is competing with. While a ball is simply held, the only thing
	-- animating that arm is the default locomotion -- an idle sway and a running
	-- arm swing -- and that is motion we actively want gone: it drags the ball
	-- around and fights the pose. So the solver takes the arm almost completely
	-- in those states.
	--
	-- Through the throw the opposite is true. The authored clip is the whole
	-- point, so the weight collapses and the solver gets out of its way.
	Weights = {
		-- Nothing in hand, nothing to pose. Locomotion keeps its arm.
		Idle = 0,
		-- Ball in hand outside an active match.
		BallEquipped = 0.9,
		-- Carrying a ball, ready to throw. High enough that a running arm swing
		-- does not shake the ball out of the hand.
		Aiming = 0.95,
		-- Winding up. Full control: the pause at the top has to be rock steady,
		-- and there is no authored arm motion here worth blending toward.
		Charging = 1,
		-- Collapsing fast so the authored throw owns the fast part of the motion.
		Throwing = 0.15,
		-- Zero. Pulling the hand back toward a target during the follow-through
		-- is the single thing that makes a throw look robotic.
		FollowThrough = 0,
		-- A little, to catch the hand and settle it back to the hold.
		Recovering = 0.35,
		-- Ceiling applied to every state and to the charge boost on top.
		Max = 1,
	},

	-- Spring shaping. Frequency is in Hz; damping at 1 settles without overshoot,
	-- below 1 overshoots and springs back.
	Motion = {
		-- How fast the hand travels to the wind-up spot. Sane: 6-16.
		WindupFrequency = 11,
		-- Deliberately under 1 so the hand overshoots the wind-up slightly and
		-- settles back into it. That small bounce is most of what makes the
		-- action read as cartoony rather than mechanical. Sane: 0.55-0.9.
		WindupDamping = 0.62,
		-- Returning to the resting hold. Calmer, no bounce wanted here.
		ReturnFrequency = 9,
		ReturnDamping = 1,
		-- Weight transitions. Fast, because the drop at release has to land
		-- within a couple of frames or the solver fights the throw.
		WeightFrequency = 14,
		WeightDamping = 1,
		-- Multiplier applied to the frequencies above on touch, where finger
		-- noise would otherwise show up in the arm. Sane: 0.6-1.
		TouchFrequencyScale = 0.8,
	},

	-- How long the states after a release last, in seconds. Fallbacks only: when
	-- the throw animation carries a Release marker the state machine follows the
	-- marker instead, so none of these should be tuned to match a clip's length.
	Timing = {
		ThrowingSeconds = 0.09,
		FollowThroughSeconds = 0.35,
		RecoveringSeconds = 0.25,
	},

	-- Remote characters wind up too, so an opponent's charge is readable as
	-- counterplay. Their charge arrives as a replicated attribute; they get the
	-- wind-up pose but no aim tracking, since the coil is the part that matters
	-- at a distance.
	Remote = {
		Enabled = true,
		-- Charge reports per second from each client. Sane: 8-15.
		ReportHz = 12,
		-- Smallest charge change worth a report, so a still player stops sending.
		MinReportDelta = 0.05,
	},
}
