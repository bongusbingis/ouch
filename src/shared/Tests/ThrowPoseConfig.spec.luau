--!strict

local T = require(script.Parent.TestKit)
local Animations = require(script.Parent.Parent.Parent.Config.Animations)
local ThrowPose = require(script.Parent.Parent.Parent.Config.ThrowPose)

-- Shape checks for the two config modules behind the throwing-arm pose.
--
-- These exist because the code that reads them runs only on a client, which the
-- headless suite never executes: a missing key there is not a test failure, it
-- is a nil index during a playtest. Asserting the shape here turns that class of
-- mistake back into something CI catches.
--
-- Deliberately about structure, not values. Tuning numbers are meant to change
-- freely, so these pin only what the code indexes and the few relationships that
-- would be wrong rather than merely different.

local STATES = { "Idle", "BallEquipped", "Aiming", "Charging", "Throwing", "FollowThrough", "Recovering" }

T.describe("ThrowPose config", function()
	T.it("declares every section the arm module indexes", function()
		for _, section in { "Arm", "Weights", "Motion", "Timing", "Remote" } do
			T.expect(typeof((ThrowPose :: any)[section])):toEqual("table")
		end
		T.expect(typeof(ThrowPose.Enabled)):toEqual("boolean")
	end)

	T.it("declares every arm value, with the offsets as three-component vectors", function()
		local arm = ThrowPose.Arm
		for _, key in { "ShoulderOffset", "WindupOffset", "PoleOffset" } do
			local offset = (arm :: any)[key]
			for _, axis in { "x", "y", "z" } do
				T.expect(typeof(offset[axis])):toEqual("number")
			end
		end
		for _, key in { "ReadyDistance", "ChargeStretch", "SmoothTime" } do
			T.expect(typeof((arm :: any)[key])):toEqual("number")
		end
	end)

	T.it("keeps the resting hold inside the arm's reach", function()
		-- R15 shoulder to hand is about 2.8 studs. Past that the target is
		-- unreachable and the solver locks the elbow straight.
		T.expect(ThrowPose.Arm.ReadyDistance < 2.8):toBeTruthy()
	end)

	T.it("winds the hand back rather than forward", function()
		-- Roblox characters face -Z, so a wind-up must be positive Z to be behind
		-- the shoulder. A negative value here would push the hand out in front,
		-- which is a present, not a coil.
		T.expect(ThrowPose.Arm.WindupOffset.z > 0):toBeTruthy()
	end)

	T.it("gives every visual state a weight", function()
		for _, state in STATES do
			local weight = (ThrowPose.Weights :: any)[state]
			T.expect(typeof(weight)):toEqual("number")
			T.expect(weight >= 0 and weight <= 1):toBeTruthy()
		end
	end)

	T.it("keeps every state within the ceiling", function()
		local weights = ThrowPose.Weights
		T.expect(weights.Max <= 1):toBeTruthy()
		for _, state in STATES do
			T.expect((weights :: any)[state] <= weights.Max):toBeTruthy()
		end
	end)

	T.it("yields the arm to the authored animation through the throw", function()
		-- The invariant that actually matters. Taking the arm while a ball is
		-- merely held is correct -- the only competing motion there is locomotion
		-- arm swing, which fights the pose. Taking it during the throw is not:
		-- that clip is the entire performance.
		local weights = ThrowPose.Weights
		T.expect(weights.Throwing < 0.3):toBeTruthy()
		T.expect(weights.Throwing < weights.Charging * 0.5):toBeTruthy()
	end)

	T.it("hands the arm back to the animation for the follow-through", function()
		-- The one weight with a correctness meaning rather than a taste meaning:
		-- anything above zero here drags the hand back toward its target during
		-- the most characterful part of the throw.
		T.expect(ThrowPose.Weights.FollowThrough):toEqual(0)
	end)

	T.it("weights the wind-up above the resting hold", function()
		T.expect(ThrowPose.Weights.Charging > ThrowPose.Weights.Aiming):toBeTruthy()
	end)

	T.it("collapses the weight through the throw", function()
		T.expect(ThrowPose.Weights.Throwing < ThrowPose.Weights.Charging):toBeTruthy()
	end)

	T.it("declares every motion value with positive frequencies", function()
		local motion = ThrowPose.Motion
		for _, key in
			{
				"WindupFrequency",
				"WindupDamping",
				"ReturnFrequency",
				"ReturnDamping",
				"WeightFrequency",
				"WeightDamping",
				"TouchFrequencyScale",
			}
		do
			T.expect((motion :: any)[key] > 0):toBeTruthy()
		end
	end)

	T.it("keeps the wind-up under-damped so the hand settles with a bounce", function()
		-- Damping at or above 1 removes the overshoot entirely, which is what
		-- makes the action read as mechanical.
		T.expect(ThrowPose.Motion.WindupDamping < 1):toBeTruthy()
	end)

	T.it("declares a timing for every post-release state", function()
		local timing = ThrowPose.Timing
		for _, key in { "ThrowingSeconds", "FollowThroughSeconds", "RecoveringSeconds" } do
			T.expect((timing :: any)[key] > 0):toBeTruthy()
		end
	end)

	T.it("declares a positive remote report rate", function()
		T.expect(ThrowPose.Remote.ReportHz > 0):toBeTruthy()
		T.expect(ThrowPose.Remote.MinReportDelta > 0):toBeTruthy()
	end)
end)

T.describe("Animations config", function()
	T.it("gives every clip the fields the loader reads", function()
		local count = 0
		for _, clips in Animations.Clips do
			for _, clip in clips do
				T.expect(typeof(clip.Name)):toEqual("string")
				T.expect(#clip.Name > 0):toBeTruthy()
				T.expect(typeof(clip.Required)):toEqual("boolean")
				T.expect(typeof(clip.Looped)):toEqual("boolean")
				T.expect(typeof(clip.Priority)):toEqual("string")
				T.expect(typeof(clip.Markers)):toEqual("table")
				count += 1
			end
		end
		T.expect(count > 0):toBeTruthy()
	end)

	T.it("keeps both weapons' attack clips required", function()
		T.expect(Animations.Clips.Dodgeball.Throw.Required):toEqual(true)
		T.expect(Animations.Clips.Hammer.Swing.Required):toEqual(true)
	end)

	T.it("declares the markers the combat code listens for", function()
		T.expect(table.find(Animations.Clips.Dodgeball.Throw.Markers, "Release") ~= nil):toBeTruthy()
		T.expect(table.find(Animations.Clips.Dodgeball.Charge.Markers, "Charged") ~= nil):toBeTruthy()
	end)

	T.it("declares a fade time for each way a clip is started", function()
		for _, key in { "Attack", "Hold", "Recover" } do
			T.expect((Animations.FadeTime :: any)[key] >= 0):toBeTruthy()
		end
	end)

	T.it("gives clip names that are unique within a weapon", function()
		for _, clips in Animations.Clips do
			local seen: { [string]: boolean } = {}
			for _, clip in clips do
				T.expect(seen[clip.Name]):toBeNil()
				seen[clip.Name] = true
			end
		end
	end)
end)

return true
