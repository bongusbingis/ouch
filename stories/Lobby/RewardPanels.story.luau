--[[
    The two reward browsers that live inside other screens, shown at their real sizes:

    DailyRewardsPanel -- the seven-day strip with day 3 ready to claim (days 1-2 claimed, 4-7
    locked), in its full layout, its Compact phone layout and its one-line Summary form, plus the
    final-day and already-claimed points of the streak.

    SeasonRewardsPanel -- the season reward browser (free and premium tracks, tier 3 of the season
    reached, premium locked behind the pass) at its wide 900 px width and its compact phone width.
    Selecting a reward card is live.

    Data: Fixtures.daily, Fixtures.seasonEntries (SeasonRewardsModel.entries over Fixtures.season).
    Migrated from DailyRewardsPanel.story (Compact / Summary attributes -> states) and
    SeasonRewardsPanel.story (Compact / Width attributes -> wide + compact states).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local Components = StoryRoot.Components
local DailyRewardsPanel = require(Components:WaitForChild("DailyRewardsPanel"))
local SeasonRewardsPanel = require(Components:WaitForChild("SeasonRewardsPanel"))

local c = React.createElement

local function daily(state: any, extra: { [string]: any }?): any
	local props: { [string]: any } = {
		Native = { Size = UDim2.fromScale(1, 1) },
		State = state,
		OnClaim = Fixtures.log("RewardPanels", "Daily.OnClaim"),
	}
	for key, value in extra or {} do
		props[key] = value
	end
	return c(DailyRewardsPanel, props)
end

local function Browser(props: { Width: number, Compact: boolean?, Premium: boolean? })
	local entries = Fixtures.seasonEntries({ tier = 3, hasPremium = props.Premium })
	local selected, setSelected = React.useState(if entries[1] then entries[1].key else nil)
	return c(SeasonRewardsPanel, {
		Entries = entries,
		SelectedKey = selected,
		Compact = props.Compact,
		Width = props.Width,
		OnSelectEntry = function(entry)
			setSelected(entry.key)
		end,
	})
end

return StoryRoot.story({
	Title = "Reward panels",
	Summary = "DailyRewardsPanel (full / compact / summary / streak points) and SeasonRewardsPanel (wide / compact / premium owned).",
	States = {
		{
			Name = "Daily",
			Note = "Day 3 claimable.",
			Size = Vector2.new(760, 300),
			Element = daily(Fixtures.daily(3, 2)),
		},
		{
			Name = "Daily compact",
			Size = Vector2.new(420, 340),
			Element = daily(Fixtures.daily(3, 2), { Compact = true }),
		},
		{
			Name = "Daily summary",
			Note = "One-line form.",
			Size = Vector2.new(420, 140),
			Element = daily(Fixtures.daily(3, 2), { Summary = true }),
		},
		{ Name = "Daily final day", Size = Vector2.new(760, 300), Element = daily(Fixtures.daily(7, 6)) },
		{
			Name = "Daily claimed",
			Note = "Come back tomorrow.",
			Size = Vector2.new(760, 300),
			Element = daily(Fixtures.daily(4, 4, false)),
		},
		{
			Name = "Season wide",
			Note = "Width 900.",
			Size = Vector2.new(900, 520),
			Element = c(Browser, { Width = 900 }),
		},
		{
			Name = "Season compact",
			Note = "Width 420, Compact.",
			Size = Vector2.new(420, 560),
			Element = c(Browser, { Width = 420, Compact = true }),
		},
		{
			Name = "Season premium owned",
			Note = "Pass owned: premium track claimable.",
			Size = Vector2.new(900, 520),
			Element = c(Browser, { Width = 900, Premium = true }),
		},
	},
})
