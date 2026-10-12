--[[
    The arena's pre-round ballot: GameModeSelect with the mode cards and the map dock, plus its two
    building blocks (GameModeCard, MapVoteChip) on their own.

    Why: the ballot is the first thing every arena round shows, and its dock changes shape with the
    number of maps -- so every map count is on screen at once instead of behind a cycling button.

    States
      2 MAPS        CANDY BOWL + the long third title swapped onto map two, so truncation is
                    always visible (the old story's default variant).
      NO MAPS       the mode-only ballot (GameModeSelect hides the dock below two maps).
      3 MAPS        CANDY BOWL / BAMBOO ISLE / the long name -- the widest dock.
      MODE CARDS    GameModeCard landscape: default, VOTED (selected), disabled (ballot closed).
      COMPACT CARDS the short-landscape card (Compact) used on phones.
      PORTRAIT      the portrait card (Portrait + CardHeight), stacked.
      MAP CHIPS     MapVoteChip at the desktop size and the compact size, selected / unselected /
                    disabled.

    GameModeSelect lays itself out from the camera viewport, so the three ballot states are Screen
    frames; switch Studio's Device emulator to a phone to see the short/portrait dock. Votes are
    live local state (click a card or a chip); nothing is sent. Mode thumbnails are blank ("") so
    the cards show their accent art fallback, as on a fresh server before thumbnails load.
]]

--!strict

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local Components = StoryRoot.Components
local GameModeSelect = require(Components:WaitForChild("GameModeSelect"))
local GameModeCard = require(Components:WaitForChild("GameModeCard"))
local MapVoteChip = require(Components:WaitForChild("MapVoteChip"))
local M = StoryRoot.Tokens.MapVote

local c = React.createElement

local function Ballot(props: { MapCount: number, LongSecond: boolean? })
	local mode, setMode = React.useState("FFA")
	local map, setMap = React.useState("Bowl")
	local maps = Fixtures.ballotMaps(props.MapCount, map, props.LongSecond)
	return c(GameModeSelect, {
		Active = true,
		EndsAt = Fixtures.serverNow() + 10,
		DurationSeconds = 10,
		Modes = Fixtures.ballotModes(mode),
		OnVote = setMode,
		Maps = maps,
		OnVoteMap = if maps then setMap else nil,
	})
end

local function row(children: { [string]: any }, vertical: boolean?): any
	children.Layout = c("UIListLayout", {
		FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 18),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, children)
end

local function Cards(props: { Compact: boolean?, Portrait: boolean? })
	local selected, setSelected = React.useState("TDM")
	local modes = Fixtures.ballotModes(selected)
	local children = {}
	for index, mode in modes do
		children[mode.Id] = c(GameModeCard, {
			Mode = mode,
			-- The third card is the closed-ballot (disabled) state.
			Enabled = index ~= 3,
			OnVote = setSelected,
			Compact = props.Compact,
			Portrait = props.Portrait,
			CardHeight = if props.Portrait then 260 else nil,
		})
	end
	return row(children, props.Portrait)
end

local function Chips(props: { Compact: boolean })
	local selected, setSelected = React.useState("Bowl")
	local maps = Fixtures.ballotMaps(3, selected) :: { any }
	local children = {}
	for index, map in maps do
		children[map.Id] = c(MapVoteChip, {
			Map = map,
			Enabled = index ~= 3,
			OnVote = setSelected,
			Width = if props.Compact then M.CompactChipWidth else M.ChipWidthMax,
			Height = if props.Compact then M.CompactChipHeight else M.ChipHeightMax,
			Compact = props.Compact,
			LayoutOrder = index,
		})
	end
	return row(children)
end

return StoryRoot.story({
	Title = "Ballot",
	Summary = "GameModeSelect (mode cards + map dock) at every map count, then GameModeCard and MapVoteChip alone. "
		.. "Click to vote; the third card / chip is disabled.",
	States = {
		{
			Name = "2 Maps",
			Note = "Long second title exercises truncation",
			Screen = true,
			Fit = 0.5,
			Element = c(Ballot, { MapCount = 2, LongSecond = true }),
		},
		{
			Name = "No Maps",
			Note = "Mode-only ballot",
			Screen = true,
			Fit = 0.5,
			Element = c(Ballot, { MapCount = 0 }),
		},
		{ Name = "3 Maps", Note = "Widest dock", Screen = true, Fit = 0.5, Element = c(Ballot, { MapCount = 3 }) },
		{
			Name = "Mode cards",
			Note = "Default · VOTED · disabled",
			Size = Vector2.new(1100, 380),
			Element = c(Cards),
		},
		{
			Name = "Compact cards",
			Note = "Short landscape (phone)",
			Size = Vector2.new(844, 300),
			Element = c(Cards, { Compact = true }),
		},
		{
			Name = "Portrait cards",
			Note = "Portrait, CardHeight 260",
			Size = Vector2.new(390, 860),
			Element = c(Cards, { Portrait = true }),
		},
		{
			Name = "Map chips",
			Note = "Desktop size · selected / open / disabled",
			Size = Vector2.new(1080, 140),
			Element = c(Chips, { Compact = false }),
		},
		{
			Name = "Map chips compact",
			Note = "Compact size",
			Size = Vector2.new(660, 100),
			Element = c(Chips, { Compact = true }),
		},
	},
})
