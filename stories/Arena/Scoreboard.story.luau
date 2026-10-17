--[[
    The match standings pieces on their own: the StandingsStrip (top-right mini leaderboard) and
    the MatchScoreboard overlay, for team and free-for-all matches.

    Why: MatchHUD composes both, but their row layouts (team colouring, local-player highlight,
    the local row appended below the cut, the short one-row strip) are easiest to judge alone.

    States
      Strip TDM / Strip FFA       the full strip (top rows + local row), team accents vs none.
      Strip short                 the short-screen strip (Short = true): one row.
      Strip local below cut       local player last in score, so the strip appends "YOU".
      Scoreboard TDM / FFA        the overlay, Screen frames (it sizes from the safe area).

    TeammateMarkers (allied name tags) are BillboardGuis adorned to character heads; they need
    world parts and are not stubbable in a story.
]]

--!strict

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local Arena = StoryRoot.Components:WaitForChild("Arena")
local StandingsStrip = require(Arena:WaitForChild("StandingsStrip"))
local MatchScoreboard = require(Arena:WaitForChild("MatchScoreboard"))

local c = React.createElement

local function strip(kind: string, short: boolean, lastPlace: boolean?): any
	local view = Fixtures.matchHUD(kind)
	if lastPlace then
		for _, entry in view.entries do
			if entry.isLocal then
				entry.score = 0
			end
		end
		local MatchHUDModel = require(StoryRoot.Models:WaitForChild("MatchHUDModel"))
		view.entries = MatchHUDModel.standings(view.entries)
	end
	return c(StandingsStrip, {
		Snapshot = view,
		Short = short,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		OnActivated = Fixtures.log("Scoreboard", "strip pressed"),
	})
end

local function board(kind: string): any
	return c(MatchScoreboard, {
		Visible = true,
		Snapshot = Fixtures.matchHUD(kind),
		OnClose = Fixtures.log("Scoreboard", "close pressed"),
	})
end

local STRIP = Vector2.new(360, 300)

return StoryRoot.story({
	Title = "Scoreboard",
	Summary = "StandingsStrip (full / short / local-below-cut) and the MatchScoreboard overlay for team and FFA matches.",
	States = {
		{ Name = "Strip TDM", Note = "Team accents", Size = STRIP, Element = strip("TDM", false) },
		{ Name = "Strip FFA", Note = "No teams", Size = STRIP, Element = strip("FFA", false) },
		{
			Name = "Strip short",
			Note = "Short screen: one row",
			Size = Vector2.new(360, 120),
			Element = strip("TDM", true),
		},
		{
			Name = "Strip local below cut",
			Note = "YOU appended under the top rows",
			Size = STRIP,
			Element = strip("FFA", false, true),
		},
		{ Name = "Scoreboard TDM", Screen = true, Fit = 0.5, Element = board("TDM") },
		{ Name = "Scoreboard FFA", Screen = true, Fit = 0.5, Element = board("FFA") },
	},
})
