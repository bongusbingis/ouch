--!strict

-- Throwing-arm pose tuning. The procedural layer owns the arm while a ball is
-- held; the authored animation owns the rest of the character.

return {
	Enabled = true,

	Arm = {
		-- Where the shoulder sits relative to the character's root, in studs
		-- (right, up, forward). Deliberately a constant rather than read from the
		-- animated limb: reading the real shoulder would feed the solver's own
		-- output back into its input and make the pose crawl.
		-- Measure once for your rig and leave it.
		ShoulderOffset = vector.create(1.5, 1, 0),

		-- Resting hand distance from the shoulder along aim, in studs.
		ReadyDistance = 2.2,

		-- Wind-up position relative to the shoulder (right, up, back).
		WindupOffset = vector.create(0.5, 0.75, 2),

		-- Additional wind-up distance at full charge, as a fraction.
		ChargeStretch = 0.35,

		-- Elbow pole, in character space relative to the shoulder (right, up,
		-- back). Keeps the elbow flaring out and back instead of folding through
		-- the torso or snapping inside out. Tune with Debug.PoseElbowPole on.
		PoleOffset = vector.create(2.2, -0.4, 1.4),

		-- Solver smoothing in seconds. Small, because the springs below already
		-- The springs provide the primary shaping; avoid stacking smoothers.
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
		-- How fast the hand travels to the wind-up spot.
		WindupFrequency = 11,
		-- Underdamped wind-up motion.
		WindupDamping = 0.62,
		-- Returning to the resting hold. Calmer, no bounce wanted here.
		ReturnFrequency = 9,
		ReturnDamping = 1,
		-- Weight transitions. Fast, because the drop at release has to land
		-- within a couple of frames or the solver fights the throw.
		WeightFrequency = 14,
		WeightDamping = 1,
		-- Multiplier applied to the frequencies above on touch, where finger
		-- Frequency multiplier for touch input.
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
		-- Charge reports per second from each client.
		ReportHz = 12,
		-- Smallest charge change worth a report, so a still player stops sending.
		MinReportDelta = 0.05,
	},
}
