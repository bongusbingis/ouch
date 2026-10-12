--[[
    The Shop page (ShopPage) over the real ShopViewModel built from the shipped catalog
    (Fixtures.economy), one state at a time -- the page is a full-viewport panel and each state is
    a heavy render, so this story uses the chip switcher instead of a grid.

    States: READY (featured EffectsCrate, three daily offers, bundles, passes), LOADING, REFRESHING,
    ERROR (SHOP UNAVAILABLE + RETRY), EMPTY (no daily offers), PURCHASED (the common offer owned),
    UNAFFORDABLE (0 Bonks), GUARANTEED (pity close), PENDING (a crate purchase in flight),
    RESTRICTED (paid random items not allowed in this region) and UNAVAILABLE (every product's
    price lookup failed). Card presses and RETRY print to the Output; nothing is purchased.

    Migrated from ShopPage.story (PreviewState attribute -> states).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local ShopPage = require(StoryRoot.Components:WaitForChild("ShopPage"))

local c = React.createElement

local STATES = {
	{ "Ready", "Featured crate, daily offers, bundles, passes." },
	{ "Loading", "LOADING SHOP…" },
	{ "Refreshing", "Offers rolling over." },
	{ "Error", "SHOP UNAVAILABLE + RETRY." },
	{ "Empty", "No daily offers." },
	{ "Purchased", "Common offer owned." },
	{ "Unaffordable", "0 Bonks." },
	{ "Guaranteed", "Crate pity nearly due." },
	{ "Pending", "Crate purchase in flight." },
	{ "Restricted", "Paid random items blocked here." },
	{ "Unavailable", "Every price lookup failed." },
}

local states = {}
for _, entry in STATES do
	local model = Fixtures.economy(entry[1])
	table.insert(states, {
		Name = entry[1],
		Note = entry[2],
		Screen = true,
		Element = c(ShopPage, {
			Model = model,
			SeasonState = Fixtures.season(),
			OnCardActivated = Fixtures.log("Shop", "OnCardActivated"),
			OnRefresh = Fixtures.log("Shop", "OnRefresh"),
		}),
	})
end

return StoryRoot.story({
	Title = "Shop",
	Summary = "ShopPage over the real catalog view model in every shop status; pick a state with the chips.",
	Mode = "Switch",
	States = states,
})
