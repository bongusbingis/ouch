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
local DamageEffects = require(script.Parent.Imported.DamageEffects)
local EggEffects = require(script.Parent.Imported.EggEffects)

export type ScriptEffect = {
	play: (context: any) -> (),
}

local productionIds = {
	"StarPop",
	"FoamPoof",
	"ConfettiImpact",
	"JellySplash",
	"CandyCrash",
	"PartyPopper",
	"SugarRush",
	"ComicBonk",
	"BubbleBurst",
	"RoyalParty",
	"Prismatic",
	"Galaxy",
	"Starlight",
}

-- Effects reproduced in code from an external particle pack's dump (ParticleKit +
-- Effects/Imported). They resolve like any script effect, so a cosmetic bound to
-- one (e.g. SugarRush) needs no Studio template.
local importedIds = {
	"Burn",
	"Magma",
	"Poison",
	"Shock",
	"Common",
	"Epic",
	"Ethereal",
}

local orderedIds = table.clone(productionIds)
for _, id in importedIds do
	table.insert(orderedIds, id)
end

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

for _, map in { DamageEffects, EggEffects } do
	for id, effect in map do
		registry[id] = effect
	end
end

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
