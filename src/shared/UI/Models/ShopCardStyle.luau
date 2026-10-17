-- Name: ShopCardStyle.luau
-- Author: Jack C.
-- Description: Decides what a storefront card shows before anything is drawn: the tilted product sticker, the named rarity ribbon, the OWNED stamp, the tinted artwork tile and body colours, the name, the supporting line, the season progress and the action label, so ShopCard only lays out what this resolves and the mapping can be tested headlessly.
-- Created: 2026-09-15
--!strict

local T = require(script.Parent.Parent.Tokens)
local number = require(script.Parent.NumberText)

local C, L = T.Colors, T.Shop

export type Sticker = { Text: string, Color: Color3, TextColor: Color3 }

export type Options = {
	Headline: boolean?,
	ShowProgress: boolean?,
	RobuxSymbol: string?,
	-- The block's own header; a sticker that only repeats it is dropped.
	SectionTitle: string?,
}

export type Style = {
	season: boolean,
	currency: boolean,
	sticker: Sticker?,
	rarity: string?,
	owned: boolean,
	ownedText: string,
	accent: Color3,
	tileColor: Color3,
	tileLine: Color3,
	bodyColor: Color3,
	name: string,
	secondary: string?,
	progress: number?,
	action: { Text: string?, BonksAmount: number? },
	-- "Muted" is a status in the action slot (still opens inspection), never a CTA;
	-- "Retry" re-requests a price that failed to load.
	actionState: string,
	description: string?,
	primary: boolean,
	previewItems: { any },
}

local accents: { [string]: Color3 } = {
	SeasonPass = C.Gold,
	GamePass = C.Grape,
	Crate = C.Cyan,
	Bundle = C.Pink,
	Bonks = C.Yellow,
}

local stickers: { [string]: { Color: Color3, TextColor: Color3 } } = {
	["SEASON PASS"] = { Color = C.Gold, TextColor = C.Ink },
	["FEATURED"] = { Color = C.Pink, TextColor = C.Surface },
	["WEEKLY BUNDLE"] = { Color = C.Pink, TextColor = C.Surface },
	["STARTER OFFER"] = { Color = C.Cyan, TextColor = C.Ink },
	["PERMANENT"] = { Color = C.Grape, TextColor = C.Surface },
}

local ShopCardStyle = {}

function ShopCardStyle.sticker(card: any, sectionTitle: string?): Sticker?
	local season = card.kind == "SeasonPass"
	local text = if season then "SEASON PASS" else card.badge
	if text == nil or text == "" or T.Rarity[text] then
		return nil
	end
	local upper = string.upper(text)
	if sectionTitle ~= nil and string.upper(sectionTitle) == upper then
		return nil
	end
	local palette = stickers[upper] or { Color = C.Cyan, TextColor = C.Ink }
	return { Text = upper, Color = palette.Color, TextColor = palette.TextColor }
end

function ShopCardStyle.accent(card: any): Color3
	-- Any single item (shop offer, Backpack entry, crate reward) is tinted by its tier.
	local tier = if card.badge then T.Rarity[card.badge] else nil
	if tier then
		return tier.Color
	end
	if card.kind == "Cosmetic" then
		return C.NeutralTile
	end
	return accents[card.kind] or C.NeutralTile
end

-- The art tile fill and its tonal recess edge for an accent; shared by cards and
-- inspection wells. It uses the collectible window's tint, so an item's Shop card,
-- odds tile, Backpack tile and inspection all sit in the same pale window (which
-- also keeps dark skins readable against it).
function ShopCardStyle.tile(accent: Color3): (Color3, Color3)
	local fill = accent:Lerp(C.Surface, T.Collectible.WellTint)
	return fill, fill:Lerp(C.Ink, T.Collectible.WellEdgeTint)
end

function ShopCardStyle.actionState(card: any): string
	if card.kind == "SeasonPass" or card.owned or card.purchased then
		return "Action"
	elseif card.pending then
		return "Muted"
	elseif card.status == "Retry" then
		return "Retry"
	elseif card.status == "Loading" or card.status == "Preview" or card.status == "Unavailable" then
		return "Muted"
	end
	return "Action"
end

function ShopCardStyle.actionText(card: any, robuxSymbol: string?): (string?, number?)
	if card.kind == "SeasonPass" then
		return "VIEW REWARDS", nil
	elseif card.pending then
		return "PROCESSING…", nil
	elseif card.purchased then
		return "PURCHASED", nil
	elseif card.owned then
		return "VIEW ITEM", nil
	elseif card.status == "Preview" then
		return "COMING SOON", nil
	elseif card.status == "Loading" then
		return "LOADING PRICE…", nil
	elseif card.status == "Retry" then
		return "RETRY PRICE", nil
	elseif card.status == "Unavailable" then
		return "UNAVAILABLE", nil
	elseif card.kind == "Crate" then
		return "VIEW ODDS", nil
	elseif card.bonksPrice then
		return nil, card.bonksPrice
	elseif card.robuxPrice then
		return (robuxSymbol or "") .. number(card.robuxPrice), nil
	end
	return "VIEW", nil
end

function ShopCardStyle.previewItems(card: any): { any }
	local items = card.previewItems or {}
	if #items <= 1 then
		return items
	end
	local hero = items[1]
	for _, item in items do
		if item.category == "CostumeAssets" then
			hero = item
			break
		end
	end
	return { hero }
end

function ShopCardStyle.resolve(card: any, seasonState: any?, options: Options?): Style
	local opts: Options = options or {}
	local season = card.kind == "SeasonPass"
	local currency = card.kind == "Bonks"
	local state = if season
			and opts.ShowProgress ~= false
			and seasonState
			and seasonState.active
		then seasonState
		else nil
	local accent = ShopCardStyle.accent(card)
	local tileColor, tileLine = ShopCardStyle.tile(accent)
	local text, amount = ShopCardStyle.actionText(card, opts.RobuxSymbol)
	local name = if season
			and seasonState
			and seasonState.active
		then string.upper(seasonState.displayName)
		elseif currency then number((card.definition and card.definition.BonksAmount) or 0) .. " BONKS"
		else string.upper(card.displayName or "")
	local secondary: string? = if season
		then (if card.owned then "PREMIUM OWNED" else "FREE + PREMIUM REWARDS")
		elseif card.originalBonksPrice then number(card.bonksPrice or 0) .. " BONKS · WAS " .. number(
			card.originalBonksPrice
		)
		elseif card.kind == "Crate" and card.bonksPrice then number(card.bonksPrice) .. " BONKS / OPEN"
		else nil
	if state and secondary then
		secondary = "TIER " .. tostring(state.tier) .. " · " .. secondary
	end
	local progress: number? = nil
	if state then
		progress = if state.tier >= state.tierCount
			then 1
			else (state.xpIntoTier or 0) / math.max(state.xpForNextTier or 1, 1)
	end
	return {
		season = season,
		currency = currency,
		sticker = ShopCardStyle.sticker(card, opts.SectionTitle),
		rarity = if T.Rarity[card.badge] then card.badge else nil,
		owned = (card.owned == true or card.purchased == true) and not season,
		ownedText = if card.purchased then "PURCHASED" else "OWNED",
		accent = accent,
		tileColor = tileColor,
		-- A tonal recess edge from the tile's own fill, never a saturated accent outline.
		tileLine = tileLine,
		bodyColor = if opts.Headline then accent:Lerp(C.SurfaceWarm, L.HeadlineTint) else C.SurfaceWarm,
		name = name,
		secondary = secondary,
		progress = progress,
		action = { Text = text, BonksAmount = amount },
		actionState = ShopCardStyle.actionState(card),
		-- The offer's own sentence for cards with a copy column; a currency pack's
		-- blurb only restates its amount, so it is left to the name.
		description = if not season
				and not currency
				and type(card.description) == "string"
				and card.description ~= ""
			then card.description
			else nil,
		primary = season,
		previewItems = ShopCardStyle.previewItems(card),
	}
end

return table.freeze(ShopCardStyle)
