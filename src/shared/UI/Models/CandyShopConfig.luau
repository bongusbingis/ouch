--!strict
local T = require(script.Parent.Parent.Tokens)
local L = T.Shop
local function class(minimum, maximum, height, layout, aspect)
	return {
		MinPx = minimum,
		MaxPx = maximum,
		MinHeightPx = height,
		MaxHeightPx = height,
		Aspect = aspect,
		Layout = layout,
		ArtScale = L.SplitArtScale,
		NameScale = 0.2,
		NameTextSize = T.Type.TileLabel,
		ActionScale = 0.2,
		ActionMinPx = L.ActionHeight,
		ActionMaxPx = L.ActionHeight,
		ShowHint = layout == "Split",
	}
end
return table.freeze({
	Tracks = L.Tracks,
	SpanSteps = L.SpanSteps,
	GapPx = L.Gap,
	CardGapPx = L.CardGap,
	HeaderHeightPx = L.SectionHeight,
	HeaderTextSize = T.Type.Section,
	EmptyHeightPx = 54,
	ScrollBarPx = 8,
	PaddingXPx = 12,
	PaddingBottomPx = 24,
	CardClasses = {
		Pass = class(L.CardMin, L.CardMax, L.CardHeight, "Stack", 1),
		Feature = class(L.CardMin, L.CardMax, L.CardHeight, "Stack", 1),
		Tile = class(L.CurrencyMin, L.CurrencyMax, L.CurrencyHeight, "Split", 0.56),
		Promo = class(L.PromoMin, L.PromoMax, L.PromoHeight, "Split", 0.4),
		Season = class(L.PromoMin, L.PromoMax, L.PromoHeight, "Stack", 0.8),
	},
	DefaultSection = { Class = "Feature", MaxColumns = 4, Span = 4 },
	Sections = {
		More = { Class = "Pass", MaxColumns = 4, Span = 8, Title = "PASSES" },
		Bonks = { Class = "Tile", MaxColumns = 3, Span = 8 },
		Crates = { Class = "Feature", MaxColumns = 2, Span = 4 },
		ForYou = { Class = "Feature", MaxColumns = 2, Span = 4 },
	},
	Order = { "More", "ForYou", "Crates", "Bonks" },
})
