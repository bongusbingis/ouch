--[[
    The restyled RarityRibbon: a puffy candy tag (fill, darker lip, fading highlight, ink outline)
    sized to its label with CollectibleLayout.tagWidth, exactly as CollectibleFace sizes it on a
    card seam. Shown at its real 28 px tag height.

    States:
      Rarities       -- every rarity in Fixtures.Rarities (Common, Rare, Legendary, Exclusive) by
                        Rarity alone: the colour and label come from Tokens.Rarity. Exclusive
                        (grape) uses white outlined text, the sticker rule.
      Product labels -- explicit Text / Color: odds "24%" in a tier colour (crate odds tiles),
                        "OWNED" yellow (the corner chip), "NEW" lime, "SALE" pink (white text),
                        and an unknown rarity (falls back to WellLine).
      Fixed widths   -- the default RibbonWidth (130 px) and a too-narrow width that truncates,
                        to show the label clipping rule.
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)
local Sheet = require(script.Parent.Sheet)

local React = StoryRoot.React
local T = StoryRoot.Tokens
local C = T.Colors
local c = React.createElement

local RarityRibbon = require(StoryRoot.Components:WaitForChild("RarityRibbon"))
local CollectibleLayout = require(StoryRoot.Models:WaitForChild("CollectibleLayout"))

local HEIGHT = T.Collectible.TagHeight

local function tag(order: number, caption: string, text: string, props: { [string]: any }, width: number?): any
	local w = width or CollectibleLayout.tagWidth(string.upper(text), T.Type.Minimum)
	return Sheet.slot(
		order,
		caption,
		Vector2.new(math.max(w, 110), HEIGHT),
		c(RarityRibbon, Sheet.merge(props, { Native = { Size = UDim2.fromOffset(w, HEIGHT) } }))
	)
end

local function Rarities()
	local cells = {}
	for index, rarity in Fixtures.Rarities do
		table.insert(cells, tag(index, string.upper(rarity), rarity, { Rarity = rarity }))
	end
	return Sheet.sheet(cells)
end

local function Products()
	return Sheet.sheet({
		tag(1, "ODDS · LEGENDARY", "24%", { Text = "24%", Color = T.Rarity.Legendary.Color }),
		tag(2, "ODDS · RARE", "61.5%", { Text = "61.5%", Color = T.Rarity.Rare.Color }),
		tag(3, "OWNED CORNER", "OWNED", { Text = "OWNED", Color = C.Yellow }),
		tag(4, "NEW", "NEW", { Text = "NEW", Color = C.Lime }),
		tag(5, "SALE · PINK", "SALE", { Text = "SALE", Color = C.Pink }),
		tag(6, "UNKNOWN RARITY", "Mythic", { Rarity = "Mythic" }),
	})
end

local function Widths()
	return Sheet.sheet({
		tag(1, "DEFAULT RIBBONWIDTH", "Legendary", { Rarity = "Legendary" }, T.Layout.RibbonWidth),
		tag(2, "TOO NARROW · TRUNCATES", "Exclusive", { Rarity = "Exclusive" }, 70),
	})
end

return StoryRoot.story({
	Title = "Rarity Ribbons",
	Summary = "The puffy RarityRibbon tag for every rarity, product labels (odds, OWNED, NEW) and width rules.",
	States = {
		{
			Name = "Rarities",
			Note = "Tokens.Rarity colour + label",
			Size = Vector2.new(720, 90),
			Element = c(Rarities),
		},
		{
			Name = "Product labels",
			Note = "Explicit Text / Color",
			Size = Vector2.new(1000, 90),
			Element = c(Products),
		},
		{
			Name = "Fixed widths",
			Note = "130 px default and a truncating width",
			Size = Vector2.new(520, 90),
			Element = c(Widths),
		},
	},
})
