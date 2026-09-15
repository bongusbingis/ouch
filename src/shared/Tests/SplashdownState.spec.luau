-- Name: SplashdownState.spec.luau
-- Author: Jack C.
-- Description: Spec for the replicated Splashdown snapshot: the idle shape, sanitizing a decoded table with defaults, dropping malformed entries, and rejecting a foreign schema.
-- Created: 2026-09-14

--!strict

local T = require(script.Parent.TestKit)
local SplashdownState = require(script.Parent.Parent.Game.Splashdown.SplashdownState)

T.describe("SplashdownState", function()
	T.it("starts idle", function()
		local idle = SplashdownState.idle()
		T.expect(idle.phase):toEqual("Idle")
		T.expect(idle.roundIndex):toEqual(0)
		T.expect(#idle.sequence):toEqual(0)
		T.expect(idle.lastRound):toBeNil()
	end)

	T.it("sanitizes a decoded snapshot and drops malformed entries", function()
		local snapshot = SplashdownState.sanitize({
			schemaVersion = SplashdownState.SchemaVersion,
			revision = 4,
			roundIndex = 2,
			roundCount = 3,
			courseId = "WhirlPool",
			courseName = "WHIRL POOL",
			checkpointCount = 3,
			phase = "Racing",
			phaseEndsAt = 0 / 0,
			raceStartedAt = 100,
			closesAt = 220,
			sequence = { "WhirlPool", 5, "DiscJockey" },
			placements = {
				{ playerId = "1", time = 40, placement = 1, points = 30 },
				{ playerId = "2", time = "soon", placement = 2, points = 29 },
			},
			standings = { { playerId = "1", points = 30, time = 40 }, { playerId = 2 } },
			lastRound = { courseName = "KNOCK KNOCK", placements = {}, dnf = { "3" } },
		})
		T.expect(snapshot ~= nil):toBeTruthy()
		local value = snapshot :: any
		T.expect(value.revision):toEqual(4)
		T.expect(value.phase):toEqual("Racing")
		T.expect(value.phaseEndsAt):toEqual(0)
		T.expect(table.concat(value.sequence, ",")):toEqual("WhirlPool,DiscJockey")
		T.expect(#value.placements):toEqual(1)
		T.expect(#value.standings):toEqual(1)
		T.expect(value.lastRound.courseName):toEqual("KNOCK KNOCK")
		T.expect(value.lastRound.dnf[1]):toEqual("3")
	end)

	T.it("falls back to idle values for an unknown phase and rejects other schemas", function()
		local snapshot = SplashdownState.sanitize({ schemaVersion = SplashdownState.SchemaVersion, phase = "Flying" })
		T.expect((snapshot :: any).phase):toEqual("Idle")
		T.expect(SplashdownState.sanitize({ schemaVersion = 99 })):toBeNil()
		T.expect(SplashdownState.sanitize("nope")):toBeNil()
	end)
end)

return true
