--[[
    Every progress and waiting indicator, at the widths they are used at.

    States:
      CandyProgressBar -- the plum-edged pink striped bar at 0, 0.35 and 1, a lime fill, and the
                          Animated variant whose stripes scroll while waiting (held still under
                          reduced motion).
      OuchProgressBar  -- the recessed pill track at 0, 0.6 and 1, with a cyan fill.
      VoteLoadingBar   -- the ballot countdown, filled from a server deadline 10 s out
                          (Fixtures.serverNow() + 10); it drains live and stops at 0.
      ActivityDots     -- the three waiting dots, active and idle.
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)
local Sheet = require(script.Parent.Sheet)

local React = StoryRoot.React
local Components = StoryRoot.Components
local T = StoryRoot.Tokens
local C = T.Colors
local c = React.createElement

local CandyProgressBar = require(Components:WaitForChild("CandyProgressBar"))
local OuchProgressBar = require(Components:WaitForChild("OuchProgressBar"))
local VoteLoadingBar = require(Components:WaitForChild("VoteLoadingBar"))
local ActivityDots = require(Components:WaitForChild("ActivityDots"))

local BAR = Vector2.new(320, 26)

local function Candy()
	local function bar(order: number, caption: string, props: { [string]: any }): any
		return Sheet.slot(
			order,
			caption,
			BAR,
			c(CandyProgressBar, Sheet.merge({ Native = { Size = UDim2.fromScale(1, 1) } }, props))
		)
	end
	return Sheet.sheet({
		bar(1, "0", { Progress = 0 }),
		bar(2, "0.35", { Progress = 0.35 }),
		bar(3, "1 (FULL)", { Progress = 1 }),
		bar(4, "LIME 0.6", { Progress = 0.6, Color = C.Lime }),
		bar(5, "ANIMATED 0.75", { Progress = 0.75, Animated = true }),
	})
end

local function Ouch()
	local function bar(order: number, caption: string, props: { [string]: any }): any
		return Sheet.slot(
			order,
			caption,
			Vector2.new(320, 20),
			c(OuchProgressBar, Sheet.merge({ Native = { Size = UDim2.fromScale(1, 1) } }, props))
		)
	end
	return Sheet.sheet({
		bar(1, "0", { Progress = 0 }),
		bar(2, "0.6", { Progress = 0.6 }),
		bar(3, "1", { Progress = 1 }),
		bar(4, "CYAN 0.4", { Progress = 0.4, Color = C.Cyan }),
	})
end

local function Waiting()
	return Sheet.sheet({
		Sheet.slot(
			1,
			"VOTELOADINGBAR · 10 S",
			Vector2.new(360, 56),
			c(VoteLoadingBar, {
				Active = true,
				EndsAt = Fixtures.serverNow() + 10,
				DurationSeconds = 10,
				Position = UDim2.new(),
				Size = UDim2.fromScale(1, 1),
			})
		),
		Sheet.slot(
			2,
			"ACTIVITYDOTS · ACTIVE",
			Vector2.new(120, 40),
			c(ActivityDots, { Active = true, Color = C.Ink, Native = { Size = UDim2.fromScale(1, 1) } })
		),
		Sheet.slot(
			3,
			"ACTIVITYDOTS · IDLE",
			Vector2.new(120, 40),
			c(ActivityDots, { Active = false, Color = C.Ink, Native = { Size = UDim2.fromScale(1, 1) } })
		),
	})
end

return StoryRoot.story({
	Title = "Progress",
	Summary = "CandyProgressBar, OuchProgressBar, the ballot VoteLoadingBar and ActivityDots.",
	States = {
		{
			Name = "CandyProgressBar",
			Note = "0 / 0.35 / 1 / lime / animated",
			Size = Vector2.new(1100, 150),
			Element = c(Candy),
		},
		{ Name = "OuchProgressBar", Note = "0 / 0.6 / 1 / cyan", Size = Vector2.new(1100, 140), Element = c(Ouch) },
		{
			Name = "Waiting",
			Note = "VoteLoadingBar drains from a deadline 10 s out",
			Size = Vector2.new(760, 130),
			Element = c(Waiting),
		},
	},
})
