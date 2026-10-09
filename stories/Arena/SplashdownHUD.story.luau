--[[
    The Splashdown race HUD (SplashdownHUD): the race band (round + course, clock, checkpoint
    progress), the countdown / GO, the closing-window warning, the finish banner, the round-results
    toast, and -- when a match view is passed -- the shared standings strip and SCORES button.

    Why: the race HUD changes through a whole round; every phase is laid out side by side, each
    built by the real SplashdownHUDModel.build from a hand-made race snapshot (course names from
    Fixtures.courses(), racers from Fixtures.Players), so the copy is exactly what the model makes.

    States
      Intro          phase Intro: the HUD band hides and the course intro card shows.
      Countdown      "3" before the start.
      GO!            the first 1.2 s of Racing.
      Racing         checkpoint 3 / 5, clock running (the old story's band).
      Closing        someone finished: RACE ENDS IN 42, clock turns pink.
      Finished       local player finished 2nd: FINISHED 2ND banner.
      Round results  phase RoundOver with the results toast (old story's toast, now model-built).
      Did not finish RoundOver where the local racer DNF'd: "YOU DID NOT FINISH".
      With standings Racing with a match view: standings strip + SCORES (FFA fixture match).

    Screen frames (it lays out from the safe area / arena HUD geometry).
]]

--!strict

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local SplashdownHUD = require(StoryRoot.Components:WaitForChild("SplashdownHUD"))
local Model = require(StoryRoot.Models:WaitForChild("SplashdownHUDModel"))

local c = React.createElement

local LOCAL = tostring(Fixtures.LocalUserId)

local function names(): { [string]: string }
	local map = {}
	for _, player in Fixtures.Players do
		map[tostring(player.userId)] = player.displayName
	end
	return map
end

local function view(options: {
	phase: string,
	started: number?,
	checkpoint: number?,
	finishTime: number?,
	placements: { any }?,
	lastRound: any?,
}): any
	local now = Fixtures.serverNow()
	local courses = Fixtures.courses()
	local course = courses[2] or courses[1]
	local snapshot = {
		phase = options.phase,
		checkpointCount = 5,
		phaseEndsAt = now + 3,
		raceStartedAt = now - (options.started or 84.6),
		placements = options.placements or {},
		closesAt = if options.placements then now + 42 else 0,
		courseName = course.DisplayName,
		courseId = course.Id,
		roundIndex = 2,
		roundCount = 3,
		sequence = {},
		lastRound = options.lastRound,
	}
	for _, entry in courses do
		table.insert(snapshot.sequence, entry.Id)
	end
	return Model.build({
		snapshot = snapshot,
		localPlayerId = LOCAL,
		checkpoint = options.checkpoint or 3,
		finishTime = options.finishTime,
		names = names(),
	}, now)
end

local function lastRound(localFinished: boolean): any
	local placements = {
		{ playerId = "2", placement = 1, time = 79.2, points = 10 },
		{ playerId = "3", placement = 2, time = 83.9, points = 8 },
	}
	if localFinished then
		placements[2].playerId = LOCAL
		placements[2].time = 84.6
		table.insert(placements, { playerId = "3", placement = 3, time = 88.1, points = 6 })
	end
	table.insert(placements, { playerId = "5", placement = #placements + 1, time = 95.4, points = 5 })
	return {
		placements = placements,
		dnf = if localFinished then {} else { LOCAL },
		courseName = Fixtures.courses()[1].DisplayName,
	}
end

local function hud(snapshot: any, match: any?): any
	return c(SplashdownHUD, {
		Visible = true,
		Snapshot = snapshot,
		Match = match,
		OnToggleScores = Fixtures.log("SplashdownHUD", "scores toggled"),
		OnCloseScores = Fixtures.log("SplashdownHUD", "scores closed"),
	})
end

local FINISHERS = { { playerId = "2", placement = 1 } }

local function state(name: string, note: string, element: any): StoryRoot.State
	return { Name = name, Note = note, Screen = true, Fit = 0.5, Element = element }
end

return StoryRoot.story({
	Title = "Splashdown HUD",
	Summary = "SplashdownHUD through a round -- intro, countdown, GO, racing, closing, finished, results -- "
		.. "each built by SplashdownHUDModel from a fixture race.",
	States = {
		state("Intro", "Course intro card", hud(view({ phase = "Intro" }))),
		state("Countdown", "3…", hud(view({ phase = "Countdown", checkpoint = 0 }))),
		state("GO!", "First 1.2 s of racing", hud(view({ phase = "Racing", started = 0.4, checkpoint = 0 }))),
		state("Racing", "Checkpoint 3 / 5", hud(view({ phase = "Racing" }))),
		state("Closing", "RACE ENDS IN 42", hud(view({ phase = "Racing", placements = FINISHERS }))),
		state(
			"Finished",
			"FINISHED 2ND",
			hud(view({
				phase = "Racing",
				finishTime = 84.6,
				placements = { FINISHERS[1], { playerId = LOCAL, placement = 2 } },
			}))
		),
		state(
			"Round results",
			"Results toast",
			hud(view({ phase = "RoundOver", finishTime = 84.6, lastRound = lastRound(true) }))
		),
		state("Did not finish", "DNF toast", hud(view({ phase = "RoundOver", lastRound = lastRound(false) }))),
		state("With standings", "Strip + SCORES", hud(view({ phase = "Racing" }), Fixtures.matchHUD("FFA"))),
	},
})
