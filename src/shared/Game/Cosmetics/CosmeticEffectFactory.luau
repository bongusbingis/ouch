-- Name: CosmeticEffectFactory.luau
-- Author: Jack C.
-- Description: Resolves a cosmetic effect id to its authored particle template or registered script effect and plays it at a world location, the single path both the arena driver and the onboarding flow use.
-- Created: 2026-08-29

--!strict

local Config = script.Parent.Parent.Parent.Parent.Config
local CosmeticEffectsConfig = require(Config:WaitForChild("CosmeticEffects"))

local CosmeticEffectFactory = {}

export type EffectContext = {
	position: Vector3,
	direction: Vector3?,
	scale: number?,
}

type ItemDef = { Category: string, EffectId: string?, [string]: any }

local ANCHOR_NAME = "CosmeticEffectAnchor"
local MIN_ANCHOR_LIFETIME = 2

-- The equipped item's EffectId names the effect; nil (nothing equipped, unknown,
-- or wrong slot) means the caller should fall back to the category default.
function CosmeticEffectFactory.effectIdForItem(items: { [string]: ItemDef }, slot: string, itemId: string?): string?
	if itemId == nil or itemId == "" then
		return nil
	end
	local item = items[itemId]
	if item == nil or item.Category ~= slot then
		return nil
	end
	return item.EffectId
end

local function emitCountFor(instance: Instance, fallback: number): number
	local attribute = instance:GetAttribute("EmitCount")
	if typeof(attribute) == "number" then
		return attribute
	end
	return fallback
end

local function collectEmitters(root: Instance): { ParticleEmitter }
	local emitters: { ParticleEmitter } = {}
	if root:IsA("ParticleEmitter") then
		table.insert(emitters, root)
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			table.insert(emitters, descendant)
		end
	end
	return emitters
end

local function anchorFor(context: EffectContext): BasePart
	local Runtime = require(script.Parent.Effects.Runtime)
	local anchor = Instance.new("Part")
	anchor.Name = ANCHOR_NAME
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = if context.direction
		then CFrame.lookAt(context.position, context.position - context.direction)
		else CFrame.new(context.position)
	anchor.Parent = Runtime.container()
	return anchor
end

local function playInstance(template: Instance, context: EffectContext, defaultEmit: number)
	local Debris = game:GetService("Debris")
	local templateCount = emitCountFor(template, defaultEmit)
	local anchor = anchorFor(context)
	local clone = template:Clone()

	local longestLifetime = 0
	for _, emitter in collectEmitters(clone) do
		longestLifetime = math.max(longestLifetime, emitter.Lifetime.Max)
		-- Consolidate every emitter onto the anchor so a multi-part authored effect
		-- bursts from the one impact point; a left-Enabled emitter (the Studio
		-- default) would otherwise free-run for the anchor's whole lifetime.
		emitter.Enabled = false
		emitter.Parent = anchor
		-- A per-emitter EmitCount attribute wins so each layer of a composite can
		-- burst a different amount, then the template's, then the category default.
		emitter:Emit(emitCountFor(emitter, templateCount))
	end
	if not clone:IsA("ParticleEmitter") then
		clone:Destroy()
	end

	Debris:AddItem(anchor, math.max(longestLifetime, MIN_ANCHOR_LIFETIME) + 0.25)
end

local function effectFolder(folderName: string): Instance
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	return ReplicatedStorage:WaitForChild("Assets")
		:WaitForChild("Cosmetics")
		:WaitForChild("Effects")
		:WaitForChild(folderName)
end

function CosmeticEffectFactory.play(categoryId: string, effectId: string?, context: EffectContext)
	local category = CosmeticEffectsConfig.Categories[categoryId]
	assert(category ~= nil, `[CosmeticEffectFactory] unknown effect category {categoryId}`)
	local resolvedId = if effectId ~= nil and effectId ~= "" then effectId else category.DefaultEffectId

	local ScriptEffects = require(script.Parent.Effects.ScriptEffects)
	local scriptEffect = ScriptEffects.get(resolvedId)
	if scriptEffect ~= nil then
		local ok, err = pcall(scriptEffect.play, context)
		if ok then
			return
		end
		warn(`[CosmeticEffectFactory] script effect {resolvedId} failed: {err}`)
		if resolvedId ~= category.DefaultEffectId then
			local defaultScriptEffect = ScriptEffects.get(category.DefaultEffectId)
			if defaultScriptEffect ~= nil then
				local fallbackOk, fallbackErr = pcall(defaultScriptEffect.play, context)
				if not fallbackOk then
					warn(`[CosmeticEffectFactory] default script effect failed: {fallbackErr}`)
				end
			else
				playInstance(
					effectFolder(category.FolderName):WaitForChild(category.DefaultEffectId),
					context,
					category.DefaultEmitCount
				)
			end
		end
		return
	end

	playInstance(effectFolder(category.FolderName):WaitForChild(resolvedId), context, category.DefaultEmitCount)
end

return CosmeticEffectFactory
