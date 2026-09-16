--!strict
local T = require(script.Parent.Parent.Tokens)
local L = T.Shop
local function class(minimum, maximum, height, layout, aspect, adaptive)
	return {
		MinPx = minimum,
		MaxPx = maximum,
		MinHeightPx = height,
		MaxHeightPx = height,
		Aspect = aspect,
		Layout = layout,
		Adaptive = adaptive == true,
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
	HeaderHeight = function(width, countdownAt, short)
		if countdownAt and width < L.CountdownWrapWidth then
			return L.CountdownTitleHeight + L.SectionContentGap * 2 + L.CountdownHeight
		end
		return if short then T.LobbyLandscape.SectionHeight else L.SectionHeight
	end,
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
		Pass = class(L.CardMin, L.CatalogCardMax, L.CardHeight, "Stack", 1, true),
		Feature = class(L.CardMin, L.CatalogCardMax, L.CardHeight, "Stack", 1, true),
		Tile = class(L.CurrencyMin, L.CurrencyMax, L.CurrencyHeight, "Split", 0.56),
		Promo = class(L.PromoMin, L.PromoMax, L.PromoHeight, "Split", 0.4),
		Season = class(L.PromoMin, L.PromoMax, L.PromoHeight, "Split", 0.4),
	},
	DefaultSection = { Class = "Feature", MaxColumns = 4, Span = 4, Priority = 3 },
	Sections = {
		More = { Class = "Pass", MaxColumns = 4, Span = 12, Title = "PASSES", Priority = 1 },
		Crates = { Class = "Feature", MaxColumns = 2, Span = 4, Priority = 2 },
		ForYou = { Class = "Feature", MaxColumns = 2, Span = 4, Priority = 2 },
		Bonks = { Class = "Tile", MaxColumns = 3, Span = 8, Priority = 2 },
	},
	Order = { "More", "Crates", "ForYou", "Bonks" },
})
