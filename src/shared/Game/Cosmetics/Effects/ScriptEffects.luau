-- Name: ScriptEffects.luau
-- Author: Jack C.
-- Description: Registry of script-defined cosmetic effects keyed by effect id, so the factory can run code-driven visuals in place of an authored particle template without touching the Studio asset tree.
-- Created: 2026-08-29

--!strict

local ConfettiImpact = require(script.Parent.ConfettiImpact)

export type ScriptEffect = {
	play: (context: any) -> (),
}

local registry: { [string]: ScriptEffect } = {
	ConfettiImpact = ConfettiImpact,
}

local ScriptEffects = {}

function ScriptEffects.get(effectId: string): ScriptEffect?
	return registry[effectId]
end

return ScriptEffects
