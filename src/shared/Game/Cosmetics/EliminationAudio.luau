-- Name: EliminationAudio.luau
-- Author: Jack C.
-- Description: Pure resolution of an elimination event and the eliminator's equipped sound cosmetic into configured primary and fallback audio cues.
-- Created: 2026-08-31

--!strict

local EliminationAudio = {}

export type ElimEffectDef = {
	DodgeballSound: string,
	HammerSound: string,
}

type Catalog = {
	Defaults: { [string]: any },
	Items: { [string]: any },
}

local function defaultEffect(catalog: Catalog): ElimEffectDef
	local definition = catalog.Defaults.ElimEffectAssets
	assert(definition ~= nil, "[EliminationAudio] catalog must define Defaults.ElimEffectAssets")
	local effect = definition.ElimEffect
	assert(effect ~= nil, "[EliminationAudio] default elimination cosmetic must define ElimEffect")
	return effect
end

function EliminationAudio.effectFor(catalog: Catalog, itemId: string?): ElimEffectDef
	local fallback = defaultEffect(catalog)
	if itemId == nil or itemId == "" then
		return fallback
	end
	local item = catalog.Items[itemId]
	if item == nil or item.Category ~= "ElimEffectAssets" or item.ElimEffect == nil then
		return fallback
	end
	return item.ElimEffect
end

function EliminationAudio.soundFor(catalog: Catalog, itemId: string?, event: { [string]: any }): (string, string?)
	if event.sourceId == nil and event.projectileId == nil then
		return "ElimZoneFall", nil
	end

	local effect = EliminationAudio.effectFor(catalog, itemId)
	local fallback = defaultEffect(catalog)
	if event.projectileId ~= nil then
		return effect.DodgeballSound, fallback.DodgeballSound
	end
	return effect.HammerSound, fallback.HammerSound
end

return EliminationAudio
