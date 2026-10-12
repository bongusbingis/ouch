--[[
    The daily quest board (QuestsPanel) in every data state the server can send, side by side:
    MIXED (one in progress, two claimable, one claimed), CLAIM PENDING (a claim in flight on the
    eliminations quest), ALL CLAIMABLE, ALL CLAIMED and EMPTY (between cycles). Each is shown in
    the compact column the Play hub uses; MIXED is repeated in the wide row layout and in the
    Short (short-landscape phone) layout.

    Data: Fixtures.quests(state). Claim presses print to the Output.
    Migrated from QuestStates.story (PreviewState / Compact / Short attributes -> states).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local QuestsPanel = require(StoryRoot.Components:WaitForChild("QuestsPanel"))

local c = React.createElement

local COLUMN = Vector2.new(420, 520)
local WIDE = Vector2.new(760, 420)
local SHORT = Vector2.new(420, 360)

local function panel(state: string, extra: { [string]: any }?): any
	local props: { [string]: any } = {
		Native = { Size = UDim2.fromScale(1, 1) },
		Compact = true,
		State = Fixtures.quests(state),
		PendingClaims = {},
		OnClaim = Fixtures.log("Quests", "OnClaim"),
	}
	for key, value in extra or {} do
		props[key] = value
	end
	return c(QuestsPanel, props)
end

return StoryRoot.story({
	Title = "Quests",
	Summary = "QuestsPanel across quest-board states, compact column plus wide and short layouts.",
	States = {
		{ Name = "Mixed", Note = "Progress, claimable and claimed rows.", Size = COLUMN, Element = panel("Mixed") },
		{
			Name = "Claim pending",
			Note = "Eliminations claim in flight.",
			Size = COLUMN,
			Element = panel("Mixed", { PendingClaims = { elims = true } }),
		},
		{ Name = "All claimable", Size = COLUMN, Element = panel("AllClaimable") },
		{ Name = "All claimed", Size = COLUMN, Element = panel("AllClaimed") },
		{ Name = "Empty", Note = "Between daily cycles.", Size = COLUMN, Element = panel("Empty") },
		{
			Name = "Wide",
			Note = "Compact = false row layout.",
			Size = WIDE,
			Element = panel("Mixed", { Compact = false }),
		},
		{
			Name = "Short",
			Note = "Short-landscape phone rows.",
			Size = SHORT,
			Element = panel("Mixed", { Short = true }),
		},
	},
})
