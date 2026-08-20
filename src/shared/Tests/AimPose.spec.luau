--!strict

local T = require(script.Parent.TestKit)
local AimPose = require(script.Parent.Parent.Game.Pose.AimPose)

T.describe("AimPose", function()
	T.it("passes a state weight through unchanged when uncharged", function()
		T.expect(AimPose.weight(0.3, 0, 0.2, 0.65)):toBeNear(0.3, 1e-9)
	end)

	T.it("raises the weight with charge but never to full control", function()
		local charged = AimPose.weight(0.3, 1, 0.2, 0.65)
		T.expect(charged):toBeNear(0.5, 1e-9)
		T.expect(charged < 1):toBeTruthy()
	end)

	T.it("never exceeds the configured ceiling however high the inputs go", function()
		T.expect(AimPose.weight(0.9, 1, 0.9, 0.65)):toBeNear(0.65, 1e-9)
	end)

	T.it("keeps a zero state weight at zero when uncharged", function()
		T.expect(AimPose.weight(0, 0, 0.2, 0.65)):toEqual(0)
	end)

	T.it("ignores an out-of-range charge rather than overshooting the cap", function()
		T.expect(AimPose.weight(0.3, 5, 0.2, 0.65)):toBeNear(0.5, 1e-9)
		T.expect(AimPose.weight(0.3, -5, 0.2, 0.65)):toBeNear(0.3, 1e-9)
	end)

	T.it("reaches the full wind-up immediately at no charge", function()
		-- The coil is a committed action, not something that creeps outward from
		-- nothing, so an uncharged wind-up is still a full one.
		T.expect(AimPose.windupReach(0, 0.35)):toBeNear(1, 1e-9)
	end)

	T.it("stretches the wind-up further as charge builds", function()
		T.expect(AimPose.windupReach(1, 0.35)):toBeNear(1.35, 1e-9)
		T.expect(AimPose.windupReach(0.5, 0.35)):toBeNear(1.175, 1e-9)
	end)

	T.it("collapses to a constant reach when the stretch is disabled", function()
		T.expect(AimPose.windupReach(1, 0)):toBeNear(1, 1e-9)
	end)

	T.it("never pulls the wind-up inward on a negative stretch", function()
		T.expect(AimPose.windupReach(1, -2)):toBeNear(1, 1e-9)
	end)

	T.it("clamps an out-of-range charge when stretching", function()
		T.expect(AimPose.windupReach(4, 0.35)):toBeNear(1.35, 1e-9)
	end)
end)

return true
