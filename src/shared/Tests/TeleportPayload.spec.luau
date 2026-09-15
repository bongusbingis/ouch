-- Description: Spec for the lobby-to-arena teleport payload: carrying the queue and either a ballot or a fixed mode, correct parsing and copying, and rejection of malformed and obsolete payloads.

--!strict

local T = require(script.Parent.TestKit)
local TeleportPayload = require(script.Parent.Parent.Game.Matchmaking.TeleportPayload)

local function voteRecord()
	return {
		matchId = "match-1",
		queueId = "Arena",
		expectedUserIds = { 1, 2, 3 },
		parties = {
			{ partyId = "party-1", leaderUserId = 1, memberUserIds = { 1, 2 } },
		},
		modeSelection = {
			strategy = "Vote",
			options = { "FFA", "TDM" },
		},
	}
end

T.describe("TeleportPayload", function()
	T.it("hands mode selection to the arena ballot for a vote queue", function()
		local payload = TeleportPayload.build(voteRecord(), "party-1")

		T.expect(payload.schemaVersion):toEqual(3)
		T.expect(payload.matchId):toEqual("match-1")
		T.expect(payload.partyId):toEqual("party-1")
		T.expect(payload.queueId):toEqual("Arena")
		T.expect(payload.expectedPlayerCount):toEqual(3)
		T.expect(payload.modeSelection.strategy):toEqual("Vote")
		T.expect(table.concat((payload.modeSelection :: any).options, ",")):toEqual("FFA,TDM")
		T.expect((payload.party :: any).leaderUserId):toEqual(1)
		T.expect(table.concat((payload.party :: any).memberUserIds, ",")):toEqual("1,2")
	end)

	T.it("carries a fixed mode for a fixed queue", function()
		local record = voteRecord()
		record.queueId = "Splashdown"
		record.modeSelection = { strategy = "Fixed", modeId = "Splashdown" } :: any
		local payload = TeleportPayload.build(record, "party-1")

		T.expect(payload.queueId):toEqual("Splashdown")
		T.expect(payload.modeSelection.strategy):toEqual("Fixed")
		T.expect((payload.modeSelection :: any).modeId):toEqual("Splashdown")
		T.expect((payload.modeSelection :: any).options):toBeNil()
	end)

	T.it("parses and copies the arena session payload", function()
		local options = { "FFA", "TDM" }
		local payload, reason = TeleportPayload.parse({
			schemaVersion = TeleportPayload.SchemaVersion,
			matchId = "match-1",
			partyId = "party-1",
			queueId = "Arena",
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
		T.expect((payload :: any).queueId):toEqual("Arena")
		T.expect(table.concat((payload :: any).modeSelection.options, ",")):toEqual("FFA,TDM")
		options[1] = "changed"
		T.expect((payload :: any).modeSelection.options[1]):toEqual("FFA")
		T.expect((payload :: any).party.leaderUserId):toEqual(1)

		local fixed = TeleportPayload.parse({
			schemaVersion = TeleportPayload.SchemaVersion,
			matchId = "match-2",
			partyId = "party-2",
			queueId = "Splashdown",
			expectedPlayerCount = 30,
			modeSelection = { strategy = "Fixed", modeId = "Splashdown" },
		})
		T.expect(fixed ~= nil):toBeTruthy()
		T.expect((fixed :: any).modeSelection.modeId):toEqual("Splashdown")
	end)

	T.it("rejects malformed and obsolete payloads", function()
		local base = {
			schemaVersion = TeleportPayload.SchemaVersion,
			matchId = "match-1",
			partyId = "party-1",
			queueId = "Arena",
			expectedPlayerCount = 3,
			modeSelection = {
				strategy = "Vote",
				options = { "FFA", "TDM" },
			},
		}

		T.expect(TeleportPayload.parse(nil)):toBeNil()
		local obsolete = table.clone(base)
		obsolete.schemaVersion = 2
		T.expect(TeleportPayload.parse(obsolete)):toBeNil()
		local missingQueue = table.clone(base)
		missingQueue.queueId = nil :: any
		T.expect(TeleportPayload.parse(missingQueue)):toBeNil()
		local invalidCount = table.clone(base)
		invalidCount.expectedPlayerCount = 0
		T.expect(TeleportPayload.parse(invalidCount)):toBeNil()
		local duplicateOptions = table.clone(base)
		duplicateOptions.modeSelection = { strategy = "Vote", options = { "FFA", "FFA" } }
		T.expect(TeleportPayload.parse(duplicateOptions)):toBeNil()
		local emptyFixed = table.clone(base)
		emptyFixed.modeSelection = { strategy = "Fixed", modeId = "" } :: any
		T.expect(TeleportPayload.parse(emptyFixed)):toBeNil()
		local unknownStrategy = table.clone(base)
		unknownStrategy.modeSelection = { strategy = "Random" } :: any
		T.expect(TeleportPayload.parse(unknownStrategy)):toBeNil()
		local invalidParty = table.clone(base)
		invalidParty.party = { leaderUserId = 9, memberUserIds = { 1, 2 } }
		T.expect(TeleportPayload.parse(invalidParty)):toBeNil()
	end)
end)

return true
