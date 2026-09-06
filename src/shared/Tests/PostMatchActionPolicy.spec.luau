-- Name: PostMatchActionPolicy.spec.luau
-- Author: Jack C.
-- Description: Spec for the reveal gate, leader-only party actions, and non-leader self-separation authorization.
-- Created: 2026-08-31

--!strict

local T = require(script.Parent.TestKit)
local PostMatchActionPolicy = require(script.Parent.Parent.Game.PostMatch.PostMatchActionPolicy)

T.describe("PostMatchActionPolicy", function()
	T.it("rejects every action until the shared reveal gate opens", function()
		local allowed, reason = PostMatchActionPolicy.validate("LeaveParty", 20, 10, 2, 4, 5)
		T.expect(allowed):toEqual(false)
		T.expect(reason):toEqual("reveal_in_progress")
	end)

	T.it("keeps replay and grouped return with the leader", function()
		for _, action in { "PlayAgain", "CancelPlayAgain", "ReturnToLobby", "FindMatch" } do
			T.expect(PostMatchActionPolicy.validate(action :: any, 10, 10, 2, 5, 5)):toBeTruthy()
			local allowed, reason = PostMatchActionPolicy.validate(action :: any, 20, 10, 2, 5, 5)
			T.expect(allowed):toEqual(false)
			T.expect(reason):toEqual("not_party_leader")
		end
	end)

	T.it("allows only a non-leader in a multi-member party to separate", function()
		T.expect(PostMatchActionPolicy.validate("LeaveParty", 20, 10, 2, 5, 5)):toBeTruthy()
		local leaderAllowed, leaderReason = PostMatchActionPolicy.validate("LeaveParty", 10, 10, 2, 5, 5)
		T.expect(leaderAllowed):toEqual(false)
		T.expect(leaderReason):toEqual("leave_party_unavailable")
		local soloAllowed = PostMatchActionPolicy.validate("LeaveParty", 10, 10, 1, 5, 5)
		T.expect(soloAllowed):toEqual(false)
	end)
end)

return true
