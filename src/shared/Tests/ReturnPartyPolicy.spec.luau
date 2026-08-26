-- Name: ReturnPartyPolicy.spec.luau
-- Author: Jack C.
-- Description: Spec for restoring a party returning from the arena: reviving the surviving record, accepting one an earlier arrival restored, and rejecting mismatched matches and outsiders.
-- Created: 2026-08-24

--!strict

local T = require(script.Parent.TestKit)
local ReturnPartyPolicy = require(script.Parent.Parent.Game.Matchmaking.ReturnPartyPolicy)

local payload = {
	matchId = "match-1",
	memberUserIds = { 10, 20 },
}

local function party(phase: string, matchId: string?)
	return {
		phase = phase,
		matchId = matchId,
		members = {
			{ userId = 10 },
			{ userId = 20 },
		},
	}
end

T.describe("ReturnPartyPolicy", function()
	T.it("restores the surviving assigned or teleporting party for its match", function()
		T.expect(ReturnPartyPolicy.resolve(party("Assigned", "match-1"), payload, 10)):toEqual("Restore")
		T.expect(ReturnPartyPolicy.resolve(party("Teleporting", "match-1"), payload, 20)):toEqual("Restore")
	end)

	T.it("keeps a party already restored by an earlier arrival", function()
		T.expect(ReturnPartyPolicy.resolve(party("Lobby", nil), payload, 10)):toEqual("Keep")
	end)

	T.it("rejects mismatched matches and players outside either roster", function()
		T.expect(ReturnPartyPolicy.resolve(party("Teleporting", "match-2"), payload, 10)):toBeNil()
		T.expect(ReturnPartyPolicy.resolve(party("Teleporting", "match-1"), payload, 30)):toBeNil()
		local missing = party("Teleporting", "match-1")
		table.remove(missing.members, 2)
		T.expect(ReturnPartyPolicy.resolve(missing, payload, 20)):toBeNil()
	end)
end)

return true
