-- Description: Spec for the lobby-to-arena teleport payload: leaving mode selection to the arena ballot, correct parsing and copying, and rejection of malformed and obsolete payloads.

--!strict

local T = require(script.Parent.TestKit)
local TeleportPayload = require(script.Parent.Parent.Game.Matchmaking.TeleportPayload)

T.describe("TeleportPayload", function()
	T.it("hands mode selection to the arena vote without preselecting a mode or map", function()
		local payload = TeleportPayload.build({
			matchId = "match-1",
			expectedUserIds = { 1, 2, 3 },
			parties = {
				{ partyId = "party-1", leaderUserId = 1, memberUserIds = { 1, 2 } },
			},
			modeSelection = {
				strategy = "Vote",
				options = { "FFA", "TDM" },
			},
		}, "party-1")

		T.expect(payload.schemaVersion):toEqual(2)
		T.expect(payload.matchId):toEqual("match-1")
		T.expect(payload.partyId):toEqual("party-1")
		T.expect(payload.expectedPlayerCount):toEqual(3)
		T.expect(payload.modeSelection.strategy):toEqual("Vote")
		T.expect(table.concat(payload.modeSelection.options, ",")):toEqual("FFA,TDM")
		T.expect((payload.party :: any).leaderUserId):toEqual(1)
		T.expect(table.concat((payload.party :: any).memberUserIds, ",")):toEqual("1,2")
		T.expect((payload :: any).mode):toBeNil()
		T.expect((payload :: any).mapKey):toBeNil()
	end)

	T.it("parses and copies the arena session payload", function()
		local options = { "FFA", "TDM" }
		local payload, reason = TeleportPayload.parse({
			schemaVersion = TeleportPayload.SchemaVersion,
			matchId = "match-1",
			partyId = "party-1",
			expectedPlayerCount = 3,
			modeSelection = {
				strategy = "Vote",
				options = options,
			},
			party = {
				leaderUserId = 1,
				memberUserIds = { 1, 2 },
			},
		})

		T.expect(reason):toBeNil()
		T.expect(payload ~= nil):toBeTruthy()
		T.expect(table.concat((payload :: any).modeSelection.options, ",")):toEqual("FFA,TDM")
		options[1] = "changed"
		T.expect((payload :: any).modeSelection.options[1]):toEqual("FFA")
		T.expect((payload :: any).party.leaderUserId):toEqual(1)
	end)

	T.it("rejects malformed and obsolete payloads", function()
		local base = {
			schemaVersion = TeleportPayload.SchemaVersion,
			matchId = "match-1",
			partyId = "party-1",
			expectedPlayerCount = 3,
			modeSelection = {
				strategy = "Vote",
				options = { "FFA", "TDM" },
			},
		}

		T.expect(TeleportPayload.parse(nil)):toBeNil()
		local obsolete = table.clone(base)
		obsolete.schemaVersion = 1
		T.expect(TeleportPayload.parse(obsolete)):toBeNil()
		local invalidCount = table.clone(base)
		invalidCount.expectedPlayerCount = 0
		T.expect(TeleportPayload.parse(invalidCount)):toBeNil()
		local duplicateOptions = table.clone(base)
		duplicateOptions.modeSelection = { strategy = "Vote", options = { "FFA", "FFA" } }
		T.expect(TeleportPayload.parse(duplicateOptions)):toBeNil()
		local invalidParty = table.clone(base)
		invalidParty.party = { leaderUserId = 9, memberUserIds = { 1, 2 } }
		T.expect(TeleportPayload.parse(invalidParty)):toBeNil()
	end)
end)

return true
