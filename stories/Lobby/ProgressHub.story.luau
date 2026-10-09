--[[
    The Play page's progression hub (LobbyProgressHub): the SEASON / QUESTS / DAILY tabs with their
    ready-to-claim dots, each tab opened at the desktop panel size and the SEASON tab again in the
    compact layout the phone splash uses. Tabs are live, so any frame can be switched by hand.

    Below the hub, SeasonStatusCard on its own -- the card the SEASON tab is built around -- in its
    claimable, claim-pending, already-claimed and between-seasons states, so the card's footprint
    can be seen staying the same whether a season is running or not.

    Data: Fixtures.season (tier 3 of 30), Fixtures.quests("Mixed"), Fixtures.daily(3, 2).
    Migrated from LobbyProgressHub.story (Compact attribute -> the compact state).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local Components = StoryRoot.Components
local LobbyProgressHub = require(Components:WaitForChild("LobbyProgressHub"))
local SeasonStatusCard = require(Components:WaitForChild("SeasonStatusCard"))

local c = React.createElement
local log = Fixtures.log

local HUB = Vector2.new(440, 560)
local HUB_COMPACT = Vector2.new(340, 400)
local CARD = Vector2.new(420, 200)
local CARD_COMPACT = Vector2.new(320, 160)

local function Hub(props: { Tab: string, Compact: boolean? })
	local selected, setSelected = React.useState(props.Tab)
	return c(LobbyProgressHub, {
		Native = { Size = UDim2.fromScale(1, 1) },
		SelectedTab = selected,
		Compact = props.Compact,
		SeasonState = Fixtures.season(),
		QuestState = Fixtures.quests("Mixed"),
		DailyReward = Fixtures.daily(3, 2),
		PendingClaims = {},
		OnSelectTab = setSelected,
		OnClaimQuest = log("ProgressHub", "OnClaimQuest"),
		OnClaimSeason = log("ProgressHub", "OnClaimSeason"),
		OnViewDailyReward = log("ProgressHub", "OnViewDailyReward"),
		OnViewSeasonRewards = log("ProgressHub", "OnViewSeasonRewards"),
	})
end

local function card(state: any, extra: { [string]: any }?): any
	local props: { [string]: any } = {
		State = state,
		ShowClaim = true,
		Native = { Size = UDim2.fromScale(1, 1) },
		OnClaim = log("ProgressHub", "SeasonStatusCard.OnClaim"),
		OnViewRewards = log("ProgressHub", "SeasonStatusCard.OnViewRewards"),
	}
	for key, value in extra or {} do
		props[key] = value
	end
	return c(SeasonStatusCard, props)
end

return StoryRoot.story({
	Title = "Progression hub",
	Summary = "LobbyProgressHub on each tab (desktop + compact), then SeasonStatusCard in each claim state.",
	States = {
		{
			Name = "Season tab",
			Note = "Tier 3 of 30, one tier claimable.",
			Size = HUB,
			Element = c(Hub, { Tab = "SEASON" }),
		},
		{
			Name = "Quests tab",
			Note = "In progress / claimable / claimed.",
			Size = HUB,
			Element = c(Hub, { Tab = "QUESTS" }),
		},
		{ Name = "Daily tab", Note = "Day 3 ready to claim.", Size = HUB, Element = c(Hub, { Tab = "DAILY" }) },
		{
			Name = "Compact season",
			Note = "Phone splash layout.",
			Size = HUB_COMPACT,
			Element = c(Hub, { Tab = "SEASON", Compact = true }),
		},
		{ Name = "Card claimable", Size = CARD, Element = card(Fixtures.season()) },
		{ Name = "Card claim pending", Size = CARD, Element = card(Fixtures.season(), { Pending = true }) },
		{
			Name = "Card claimed",
			Note = "Nothing to claim: ShowClaim off.",
			Size = CARD,
			Element = card(Fixtures.season(), { ShowClaim = false }),
		},
		{ Name = "Between seasons", Size = CARD, Element = card(Fixtures.season({ active = false })) },
		{ Name = "Card compact", Size = CARD_COMPACT, Element = card(Fixtures.season(), { Compact = true }) },
	},
})
