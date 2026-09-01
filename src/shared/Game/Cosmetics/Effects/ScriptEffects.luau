--!strict

-- Registry of code-driven cosmetic effects used by the shared factory and
-- Studio preview tooling.

local BubbleBurst = require(script.Parent.BubbleBurst)
local CandyCrash = require(script.Parent.CandyCrash)
local ComicBonk = require(script.Parent.ComicBonk)
local ConfettiImpact = require(script.Parent.ConfettiImpact)
local FoamPoof = require(script.Parent.FoamPoof)
local JellySplash = require(script.Parent.JellySplash)
local PartyPopper = require(script.Parent.PartyPopper)
local RoyalParty = require(script.Parent.RoyalParty)
local StarPop = require(script.Parent.StarPop)

export type ScriptEffect = {
	play: (context: any) -> (),
}

local productionIds = {
	"StarPop",
	"FoamPoof",
	"JellySplash",
	"PartyPopper",
	"ComicBonk",
	"CandyCrash",
	"BubbleBurst",
	"RoyalParty",
}

local orderedIds = table.clone(productionIds)
table.insert(orderedIds, "ConfettiImpact")

local registry: { [string]: ScriptEffect } = {
	BubbleBurst = BubbleBurst,
	CandyCrash = CandyCrash,
	ComicBonk = ComicBonk,
	ConfettiImpact = ConfettiImpact,
	FoamPoof = FoamPoof,
	JellySplash = JellySplash,
	PartyPopper = PartyPopper,
	RoyalParty = RoyalParty,
	StarPop = StarPop,
}

local ScriptEffects = {}

function ScriptEffects.get(effectId: string): ScriptEffect?
	return registry[effectId]
end

function ScriptEffects.ids(): { string }
	return table.clone(orderedIds)
end

function ScriptEffects.productionIds(): { string }
	return table.clone(productionIds)
end

return ScriptEffects
