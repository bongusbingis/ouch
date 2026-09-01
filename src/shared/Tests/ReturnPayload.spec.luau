-- Name: ReturnPayload.spec.luau
-- Author: Jack C.
-- Description: Spec for grouped and self-separating arena return payloads, including legacy grouped payload compatibility.
-- Created: 2026-08-31

--!strict

local T = require(script.Parent.TestKit)
local ReturnPayload = require(script.Parent.Parent.Game.Matchmaking.ReturnPayload)

T.describe("ReturnPayload", function()
	T.it("round trips the party it was built from", function()
		local built = ReturnPayload.build("party-1", "match-1", { 10, 20, 30 })
		local parsed = ReturnPayload.parse(built)
		T.expect((parsed :: any).partyId):toEqual("party-1")
		T.expect((parsed :: any).matchId):toEqual("match-1")
		T.expect(table.concat((parsed :: any).memberUserIds, ",")):toEqual("10,20,30")
	end)

	T.it("does not alias the caller's member list", function()
		local members = { 10, 20 }
		local built = ReturnPayload.build("party-1", "match-1", members)
		table.insert(members, 30)
		T.expect(#built.memberUserIds):toEqual(2)
	end)

	T.it("round-trips an explicit self-separating return", function()
		local parsed = ReturnPayload.parse(ReturnPayload.build("party", "match", { 10, 20 }, "Separate"))
		T.expect((parsed :: any).returnMode):toEqual("Separate")
		T.expect((parsed :: any).memberUserIds[1]):toEqual(10)
		T.expect((parsed :: any).memberUserIds[2]):toEqual(20)
	end)

	T.it("defaults legacy and newly built grouped returns to Party", function()
		local built = ReturnPayload.build("party", "match", { 10 })
		T.expect(built.returnMode):toEqual("Party")
		local parsed = ReturnPayload.parse({
			schemaVersion = ReturnPayload.SchemaVersion,
			partyId = "party",
			matchId = "match",
			memberUserIds = { 10 },
		})
		T.expect((parsed :: any).returnMode):toEqual("Party")
	end)

	T.it("rejects an unknown return mode", function()
		local parsed, reason = ReturnPayload.parse({
			schemaVersion = ReturnPayload.SchemaVersion,
			partyId = "party",
			matchId = "match",
			memberUserIds = { 10 },
			returnMode = "EveryoneElse",
		})
		T.expect(parsed):toBeNil()
		T.expect(reason):toEqual("invalid_return_mode")
	end)

	T.it("rejects a payload from a different schema", function()
		local built = ReturnPayload.build("party-1", "match-1", { 10 })
		built.schemaVersion = 99
		T.expect((ReturnPayload.parse(built))):toBeNil()
	end)

	T.it("rejects missing or malformed identity", function()
		T.expect((ReturnPayload.parse(nil))):toBeNil()
		T.expect((ReturnPayload.parse("nope"))):toBeNil()
		local built = ReturnPayload.build("party-1", "match-1", { 10 })
		built.partyId = ""
		T.expect((ReturnPayload.parse(built))):toBeNil()
	end)

	T.it("rejects member lists that are empty, duplicated, or not user ids", function()
		local function withMembers(members: any): any
			local built = ReturnPayload.build("party-1", "match-1", { 10 })
			built.memberUserIds = members
			return ReturnPayload.parse(built)
		end
		T.expect(withMembers({})):toBeNil()
		T.expect(withMembers({ 10, 10 })):toBeNil()
		T.expect(withMembers({ 10, -1 })):toBeNil()
		T.expect(withMembers({ 10, 1.5 })):toBeNil()
		T.expect(withMembers({ 10, "20" })):toBeNil()
		T.expect(withMembers({ [1] = 10, [3] = 20 })):toBeNil()
	end)
end)

return true
