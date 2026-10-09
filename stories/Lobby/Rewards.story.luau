--[[
    The two reward modals. DailyRewardModal in all six presentations the old story cycled through,
    now side by side as Screen frames (the modal sizes itself from the viewport): CLAIM PENDING,
    CLAIM FAILED (error line), DAY 1 CLAIMABLE, MID STREAK CLAIMABLE (day 4), FINAL DAY CLAIMABLE
    (day 7) and ALREADY CLAIMED (come back tomorrow).

    SeasonPassModal -- the season pass card from the Shop -- for a free player (premium track
    locked, BUY for 399 Robux) and a pass owner (premium claimable), plus a claim in flight.

    FocusEnabled is off on both (their gamepad focus path reads Players.LocalPlayer, which is nil
    in edit mode). Claim / buy / close print. Data: Fixtures.daily, Fixtures.season,
    Fixtures.SeasonCard, Fixtures.Appearance. Migrated from DailyRewardModal.story (cycle button ->
    six states) and SeasonPassModal.story.
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local Components = StoryRoot.Components
local DailyRewardModal = require(Components:WaitForChild("DailyRewardModal"))
local SeasonPassModal = require(Components:WaitForChild("SeasonPassModal"))

local c = React.createElement
local log = Fixtures.log

local function daily(state: any, extra: { [string]: any }?): any
	local props: { [string]: any } = {
		Visible = true,
		FocusEnabled = false,
		State = state,
		OnClaim = log("Rewards", "Daily.OnClaim"),
		OnClose = log("Rewards", "Daily.OnClose"),
	}
	for key, value in extra or {} do
		props[key] = value
	end
	return c(DailyRewardModal, props)
end

local function pass(hasPremium: boolean, claimPending: boolean?): any
	local card = table.clone(Fixtures.SeasonCard)
	return c(SeasonPassModal, {
		FocusEnabled = false,
		Card = card,
		SeasonState = Fixtures.season({ tier = 3, hasPremium = hasPremium }),
		ClaimPending = claimPending,
		Equipped = { CharacterColor = Fixtures.Appearance.ColorId, CostumeAssets = Fixtures.Appearance.CostumeId },
		OnClose = log("Rewards", "SeasonPass.OnClose"),
		OnClaimSeason = log("Rewards", "SeasonPass.OnClaimSeason"),
		OnPurchaseRobux = log("Rewards", "SeasonPass.OnPurchaseRobux"),
	})
end

return StoryRoot.story({
	Title = "Reward modals",
	Summary = "DailyRewardModal in its six presentations, then SeasonPassModal for free and pass-owning players.",
	States = {
		{ Name = "Claim pending", Screen = true, Fit = 0.5, Element = daily(Fixtures.daily(1, 0), { Pending = true }) },
		{
			Name = "Claim failed",
			Screen = true,
			Fit = 0.5,
			Element = daily(Fixtures.daily(1, 0), { ErrorText = "COULDN'T CLAIM. TRY AGAIN." }),
		},
		{ Name = "Day 1 claimable", Screen = true, Fit = 0.5, Element = daily(Fixtures.daily(1, 0)) },
		{ Name = "Mid streak claimable", Screen = true, Fit = 0.5, Element = daily(Fixtures.daily(4, 3)) },
		{ Name = "Final day claimable", Screen = true, Fit = 0.5, Element = daily(Fixtures.daily(7, 6)) },
		{ Name = "Already claimed", Screen = true, Fit = 0.5, Element = daily(Fixtures.daily(4, 4, false)) },
		{
			Name = "Season pass — free",
			Note = "Premium locked; BUY 399.",
			Screen = true,
			Fit = 0.5,
			Element = pass(false),
		},
		{ Name = "Season pass — owned", Note = "Premium claimable.", Screen = true, Fit = 0.5, Element = pass(true) },
		{ Name = "Season pass — claiming", Screen = true, Fit = 0.5, Element = pass(true, true) },
	},
})
