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
}

export type Style = {
	season: boolean,
	currency: boolean,
	sticker: Sticker?,
	rarity: string?,
	owned: boolean,
	accent: Color3,
	tileColor: Color3,
	tileLine: Color3,
	bodyColor: Color3,
	name: string,
	secondary: string?,
	progress: number?,
	action: { Text: string?, BonksAmount: number? },
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

function ShopCardStyle.sticker(card: any): Sticker?
	local season = card.kind == "SeasonPass"
	local text = if season then "SEASON PASS" else card.badge
	if text == nil or text == "" or T.Rarity[text] then
		return nil
	end
	local upper = string.upper(text)
	local palette = stickers[upper] or { Color = C.Cyan, TextColor = C.Ink }
	return { Text = upper, Color = palette.Color, TextColor = palette.TextColor }
end

function ShopCardStyle.accent(card: any): Color3
	if card.kind == "Cosmetic" then
		local tier = T.Rarity[card.badge]
		return if tier then tier.Color else C.NeutralTile
	end
	return accents[card.kind] or C.NeutralTile
end

function ShopCardStyle.actionText(card: any, robuxSymbol: string?): (string?, number?)
	if card.kind == "SeasonPass" then
		return "VIEW REWARDS", nil
	elseif card.pending then
		return "PROCESSING…", nil
	elseif card.owned then
		return "VIEW ITEM", nil
	elseif card.status == "Preview" then
		return "COMING SOON", nil
	elseif card.status == "Loading" then
		return "LOADING…", nil
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
		sticker = ShopCardStyle.sticker(card),
		rarity = if T.Rarity[card.badge] then card.badge else nil,
		owned = card.owned == true and not season,
		accent = accent,
		tileColor = accent:Lerp(C.Surface, L.TileTint),
		tileLine = accent:Lerp(C.Ink, L.TileLineTint),
		bodyColor = if opts.Headline then accent:Lerp(C.SurfaceWarm, L.HeadlineTint) else C.SurfaceWarm,
		name = name,
		secondary = secondary,
		progress = progress,
		action = { Text = text, BonksAmount = amount },
		primary = season,
		previewItems = ShopCardStyle.previewItems(card),
	}
end

return table.freeze(ShopCardStyle)
