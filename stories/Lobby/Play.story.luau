--[[
    The Play page (SplashPage): the PLAY button, mode button, party buttons and the progression hub
    beside them, in the party/matchmaking states LobbyViewModel.partyPresentation produces. The page
    lays out from the camera viewport, so every state is a Screen frame, two per row.

    States: READY (leader, Splashdown picked, PLAY SPLASHDOWN), NO MODE (nothing picked yet, the
    pink SELECT MODE button), MATCHMAKING (CANCEL + the searching status line), WAITING FOR LEADER
    (a member: PLAY disabled, mode locked), FRESH DAY (quests empty, daily already claimed, season
    between seasons) and LOADING (no daily/season/quest projections yet).

    Migrated from SplashPage.story; its OnSelectQueue prop no longer exists (the mode button now
    opens the QueuePickerModal through OnOpenModes, see ModePicker.story).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local SplashPage = require(StoryRoot.Components:WaitForChild("SplashPage"))

local c = React.createElement
local log = Fixtures.log

--> Marks a prop a state leaves out (nil cannot live in an overrides table).
local NONE = table.freeze({})

local function queueOptions(): { any }
	local list = {}
	for _, option in Fixtures.QueueOptions do
		table.insert(list, table.clone(option))
	end
	return list
end

local function page(overrides: { [string]: any }): any
	local props: { [string]: any } = {
		PartyState = "",
		ShowMatchmakingActivity = false,
		PlayText = "PLAY",
		PlayEnabled = true,
		QueueOptions = queueOptions(),
		SelectedQueueId = "Splashdown",
		QueueEnabled = true,
		OnOpenModes = log("Play", "OnOpenModes"),
		OnPlay = log("Play", "OnPlay"),
		OnInvite = log("Play", "OnInvite"),
		OnJoinCode = log("Play", "OnJoinCode"),
		DailyReward = Fixtures.daily(2, 1),
		OnViewDailyReward = log("Play", "OnViewDailyReward"),
		OnViewSeasonRewards = log("Play", "OnViewSeasonRewards"),
		SeasonState = Fixtures.season(),
		QuestState = Fixtures.quests("Mixed"),
		PendingClaims = {},
		OnClaimQuest = log("Play", "OnClaimQuest"),
		OnClaimSeason = log("Play", "OnClaimSeason"),
	}
	for key, value in overrides do
		props[key] = if value == NONE then nil else value
	end
	return c(SplashPage, props)
end

return StoryRoot.story({
	Title = "Play page",
	Summary = "SplashPage in each party state, with the season / quests / daily hub filled from Fixtures.",
	States = {
		{ Name = "Ready", Note = "Leader with Splashdown picked.", Screen = true, Fit = 0.5, Element = page({}) },
		{
			Name = "No mode",
			Note = "Nothing picked: pink SELECT MODE.",
			Screen = true,
			Fit = 0.5,
			Element = page({ SelectedQueueId = NONE }),
		},
		{
			Name = "Matchmaking",
			Note = "Searching: CANCEL and the status line.",
			Screen = true,
			Fit = 0.5,
			Element = page({
				PartyState = "MATCHMAKING IN PROGRESS — SEARCHING FOR PLAYERS",
				PlayText = "CANCEL",
				QueueEnabled = false,
				ShowMatchmakingActivity = true,
			}),
		},
		{
			Name = "Waiting for leader",
			Note = "Party member: PLAY disabled, mode locked.",
			Screen = true,
			Fit = 0.5,
			Element = page({ PartyState = "WAITING FOR PARTY LEADER", PlayEnabled = false, QueueEnabled = false }),
		},
		{
			Name = "Fresh day",
			Note = "Quests empty, daily claimed, between seasons.",
			Screen = true,
			Fit = 0.5,
			Element = page({
				QuestState = Fixtures.quests("Empty"),
				DailyReward = Fixtures.daily(4, 4, false),
				SeasonState = Fixtures.season({ active = false }),
			}),
		},
		{
			Name = "Loading",
			Note = "No projections yet.",
			Screen = true,
			Fit = 0.5,
			Element = page({ DailyReward = NONE, SeasonState = NONE, QuestState = NONE }),
		},
	},
})
