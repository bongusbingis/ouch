--[[
    The Splashdown course intro (SplashdownIntro): the candy instruction card shown over the
    three-shot course cinematic -- round label, course title, the authored description, and the
    shot progress segments that fill as the intro runs.

    Why: every course in the live rotation has its own authored copy and shot list
    (Config.Interface.SplashdownIntro), so the story draws one intro per course in
    Config.Gameplay.Splashdown.CourseOrder (via Fixtures.courses()) -- a new course shows up here
    automatically, and a course missing intro config shows as an error frame.

    States: one per course (BALL BARRAGE, WHIRLPOOL WALTZ, DOOR DASH, PISTON PEAK at the time of
    writing), round label ROUND n / total, deadline 9 s after mount (the bar fills, then holds).
    The old story used CourseId "WhirlPool", which is not a course id; these use the real ids.
    Screen frames: the card sizes from the safe area (narrow / short layouts via Device emulator).
]]

--!strict

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local SplashdownIntro = require(StoryRoot.Components:WaitForChild("SplashdownIntro"))

local c = React.createElement

local courses = Fixtures.courses()
local states = {}
for index, course in courses do
	table.insert(states, {
		Name = course.DisplayName,
		Note = `CourseId {course.Id}`,
		Screen = true,
		Fit = 0.5,
		Element = c(SplashdownIntro, {
			CourseId = course.Id,
			RoundLabel = `ROUND {index} / {#courses}`,
			Title = course.DisplayName,
			EndsAt = Fixtures.serverNow() + 9,
		}),
	})
end

return StoryRoot.story({
	Title = "Splashdown Intro",
	Summary = "SplashdownIntro for every course in the live rotation, with its authored description and shot progress.",
	States = states,
})
