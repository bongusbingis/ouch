--[[
    Opening a crate: CrateRevealModal over results built from the real EffectsCrate odds
    (Fixtures.crateReveal). It is a full-viewport modal with its own reveal motion, so states are
    picked with the chips; each replays its reveal when selected.

    States: SINGLE NEW (one pull, the collectible hero card + NEW ITEM info stack), SINGLE DUPE
    (one pull that was a duplicate: DUPE · +n BONKS), BATCH (every outcome, every fourth a dupe,
    with the total-refund line), PITY (a single pull flagged pityTriggered = Legendary, showing the
    PITY · GUARANTEED hint) and OPEN AGAIN (single pull with the pink AGAIN action and its Bonks
    price). FocusEnabled is off; every action prints.

    Migrated from CrateRevealModal.story (which showed only the full batch).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local CrateRevealModal = require(StoryRoot.Components:WaitForChild("CrateRevealModal"))

local c = React.createElement
local log = Fixtures.log

local function reveal(results: any, extra: { [string]: any }?): any
	local _, _, data = Fixtures.economy("Ready")
	local props: { [string]: any } = {
		Reveal = results,
		Visible = true,
		FocusEnabled = false,
		Owned = data.Cosmetics.Owned,
		Equipped = data.Cosmetics.Equipped,
		BusySlots = {},
		OnClose = log("CrateReveal", "OnClose"),
		OnEquipItem = log("CrateReveal", "OnEquipItem"),
		OnInspectItem = log("CrateReveal", "OnInspectItem"),
		OnViewInventory = log("CrateReveal", "OnViewInventory"),
	}
	for key, value in extra or {} do
		props[key] = value
	end
	return c(CrateRevealModal, props)
end

local function singleDupe(): any
	local batch = Fixtures.crateReveal()
	for _, result in batch.results do
		if result.isDupe then
			return { results = { result }, totalRefund = result.bonksRefund }
		end
	end
	return Fixtures.crateReveal(1)
end

local function pity(): any
	local single = Fixtures.crateReveal(1)
	single.pityTriggered = "Legendary"
	return single
end

return StoryRoot.story({
	Title = "Crate reveal",
	Summary = "CrateRevealModal for a single new pull, a dupe, a full batch, a pity pull and the open-again footer.",
	Mode = "Switch",
	States = {
		{ Name = "Single new", Screen = true, Element = reveal(Fixtures.crateReveal(1)) },
		{ Name = "Single dupe", Note = "Refunded in Bonks.", Screen = true, Element = reveal(singleDupe()) },
		{
			Name = "Batch",
			Note = "Every outcome; every 4th a dupe.",
			Screen = true,
			Element = reveal(Fixtures.crateReveal()),
		},
		{ Name = "Pity", Note = "Guaranteed Legendary hint.", Screen = true, Element = reveal(pity()) },
		{
			Name = "Open again",
			Note = "AGAIN action with its Bonks price.",
			Screen = true,
			Element = reveal(Fixtures.crateReveal(1), {
				OnOpenAgain = log("CrateReveal", "OnOpenAgain"),
				OpenAgainEnabled = true,
				OpenAgainText = "OPEN AGAIN",
				OpenAgainBonks = 500,
			}),
		},
	},
})
