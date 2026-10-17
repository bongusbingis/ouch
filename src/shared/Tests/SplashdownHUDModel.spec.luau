-- Name: SplashdownHUDModel.spec.luau
-- Author: Jack C.
-- Description: Spec for the Splashdown HUD copy: ordinals and clock formatting, countdown and GO, checkpoint progress, the closing window, the finish banner, and the round-results toast with the local racer always present.
-- Created: 2026-09-14

--!strict

local T = require(script.Parent.TestKit)
local Model = require(script.Parent.Parent.UI.Models.SplashdownHUDModel)
local SplashdownState = require(script.Parent.Parent.Game.Splashdown.SplashdownState)

local function snapshot(overrides: { [string]: any })
	local base: any = SplashdownState.idle()
	base.roundIndex = 2
	base.roundCount = 3
	base.courseId = "DiscJockey"
	base.courseName = "DISC JOCKEY"
	base.checkpointCount = 4
	base.sequence = { "WhirlPool", "DiscJockey", "KnockKnock" }
	for key, value in overrides do
		base[key] = value
	end
	return base
end

T.describe("SplashdownHUDModel", function()
	T.it("spells ordinals including the teens", function()
		T.expect(Model.ordinal(1)):toEqual("1ST")
		T.expect(Model.ordinal(2)):toEqual("2ND")
		T.expect(Model.ordinal(3)):toEqual("3RD")
		T.expect(Model.ordinal(4)):toEqual("4TH")
		T.expect(Model.ordinal(11)):toEqual("11TH")
		T.expect(Model.ordinal(12)):toEqual("12TH")
		T.expect(Model.ordinal(13)):toEqual("13TH")
		T.expect(Model.ordinal(21)):toEqual("21ST")
		T.expect(Model.ordinal(22)):toEqual("22ND")
		T.expect(Model.ordinal(23)):toEqual("23RD")
		T.expect(Model.ordinal(30)):toEqual("30TH")
	end)

	T.it("formats a race clock to tenths", function()
		T.expect(Model.formatTime(0)):toEqual("0:00.0")
		T.expect(Model.formatTime(62.34)):toEqual("1:02.3")
		T.expect(Model.formatTime(59.96)):toEqual("1:00.0")
		T.expect(Model.formatTime(-3)):toEqual("0:00.0")
	end)

	T.it("stays hidden while the race is idle", function()
		local view = Model.build({ snapshot = SplashdownState.idle(), localPlayerId = "1" }, 100)
		T.expect(view.visible):toEqual(false)
		T.expect(view.roundLabel):toEqual("GET READY")
		T.expect(view.title):toEqual("SPLASHDOWN")
	end)

	T.it("counts down whole seconds and shows GO for the first moments of the race", function()
		local counting = Model.build({
			snapshot = snapshot({ phase = "Countdown", phaseEndsAt = 103 }),
			localPlayerId = "1",
		}, 100.4)
		T.expect(counting.countdown):toEqual("3")
		T.expect(counting.visible):toEqual(true)
		local last = Model.build({
			snapshot = snapshot({ phase = "Countdown", phaseEndsAt = 103 }),
			localPlayerId = "1",
		}, 102.9)
		T.expect(last.countdown):toEqual("1")
		local go = Model.build({
			snapshot = snapshot({ phase = "Racing", raceStartedAt = 103 }),
			localPlayerId = "1",
		}, 103.5)
		T.expect(go.countdown):toEqual("GO!")
		local running = Model.build({
			snapshot = snapshot({ phase = "Racing", raceStartedAt = 103 }),
			localPlayerId = "1",
		}, 110)
		T.expect(running.countdown):toBeNil()
		T.expect(running.clock):toEqual("0:07.0")
		T.expect(running.roundLabel):toEqual("ROUND 2 OF 3")
		T.expect(running.title):toEqual("DISC JOCKEY")
	end)

	T.it("reports checkpoint progress and the finish banner", function()
		local midway = Model.build({
			snapshot = snapshot({ phase = "Racing", raceStartedAt = 100 }),
			localPlayerId = "1",
			checkpoint = 2,
		}, 120)
		T.expect(midway.checkpointLabel):toEqual("CHECKPOINT 2 / 4")
		T.expect(midway.checkpointProgress):toBeNear(0.5, 1e-9)
		T.expect(midway.finished):toEqual(false)
		T.expect(midway.closing):toBeNil()

		local done = Model.build({
			snapshot = snapshot({
				phase = "Racing",
				raceStartedAt = 100,
				closesAt = 160,
				placements = {
					{ playerId = "2", time = 40, placement = 1, points = 30 },
					{ playerId = "1", time = 45.25, placement = 2, points = 29 },
				},
			}),
			localPlayerId = "1",
			checkpoint = 4,
			finishTime = 45.25,
		}, 150)
		T.expect(done.finished):toEqual(true)
		T.expect(done.finishLabel):toEqual("FINISHED 2ND")
		T.expect(done.checkpointLabel):toEqual("FINISHED")
		T.expect(done.checkpointProgress):toEqual(1)
		T.expect(done.clock):toEqual("0:45.3")
		T.expect(done.closing):toEqual("RACE ENDS IN 10")
		T.expect(done.finishedCount):toEqual(2)
	end)

	T.it("builds the round toast with the local racer appended below the cut", function()
		local placements = {}
		for index = 1, 8 do
			table.insert(
				placements,
				{ playerId = tostring(index), time = 30 + index, placement = index, points = 31 - index }
			)
		end
		local view = Model.build({
			snapshot = snapshot({
				phase = "RoundOver",
				lastRound = { courseName = "WHIRL POOL", placements = placements, dnf = { "9" } },
			}),
			localPlayerId = "7",
			names = { ["1"] = "Ada", ["2"] = "Bo" },
		}, 200)
		local toast = assert(view.toast, "round over needs a toast")
		T.expect(toast.title):toEqual("ROUND 2 RESULTS")
		T.expect(toast.subtitle):toEqual("WHIRL POOL")
		T.expect(#toast.rows):toEqual(6)
		T.expect(toast.rows[1].name):toEqual("Ada")
		T.expect(toast.rows[3].name):toEqual("PLAYER LEFT")
		T.expect(toast.rows[1].time):toEqual("0:31.0")
		T.expect(toast.rows[6].isLocal):toEqual(true)
		T.expect(toast.rows[6].name):toEqual("YOU")
		T.expect(toast.summary):toEqual("YOU FINISHED 7TH • +24 POINTS")

		local dnf = Model.build({
			snapshot = snapshot({
				phase = "RoundOver",
				lastRound = { courseName = "WHIRL POOL", placements = placements, dnf = { "9" } },
			}),
			localPlayerId = "9",
		}, 200)
		T.expect(assert(dnf.toast).summary):toEqual("YOU DID NOT FINISH • +0 POINTS")
		T.expect(#assert(dnf.toast).rows):toEqual(5)

		local racing = Model.build({ snapshot = snapshot({ phase = "Racing" }), localPlayerId = "1" }, 200)
		T.expect(racing.toast):toBeNil()
	end)
end)

return true
