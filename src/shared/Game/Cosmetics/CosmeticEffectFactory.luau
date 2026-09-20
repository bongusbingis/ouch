-- Description: Resolves a cosmetic effect id to its authored particle template or registered script effect and plays it at a world location, the single path both the arena driver and the onboarding flow use.

--!strict

local Config = script.Parent.Parent.Parent.Parent.Config
local CosmeticEffectsConfig = require(Config:WaitForChild("Cosmetics"):WaitForChild("CosmeticEffects"))
-- The pure effect-id resolver is also loaded by Lune without Roblox services.
local Runtime = if game ~= nil then require(script.Parent.Effects.Runtime) else ({} :: any)

local CosmeticEffectFactory = {}

export type EffectContext = {
	position: Vector3,
	direction: Vector3?,
	scale: number?,
	scope: Runtime.Scope?,
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

local function validCount(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0 and value % 1 == 0
end

local function emitCountFor(instance: Instance, fallback: number): number
	local attribute = instance:GetAttribute("EmitCount")
	if attribute == nil then
		return fallback
	end
	assert(
		validCount(attribute),
		`{instance:GetFullName()}.EmitCount: expected finite nonnegative integer, received {typeof(attribute)} {tostring(attribute)}; correct the Studio attribute and republish Arena/Lobby`
	)
	return attribute
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
	Runtime.mount(anchor, context.scope)
	return anchor
end

local function preflightTemplate(template: Instance, defaultEmit: number)
	local templateCount = emitCountFor(template, defaultEmit)
	local emitters = collectEmitters(template)
	assert(
		#emitters > 0,
		`{template:GetFullName()}: required ParticleEmitter template is missing; restore the authored template and republish Arena/Lobby`
	)
	for _, emitter in emitters do
		emitCountFor(emitter, templateCount)
	end
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

local function requiredFolder(parent: Instance, name: string): Folder
	local child = parent:FindFirstChild(name)
	assert(
		child ~= nil and child:IsA("Folder"),
		`{parent:GetFullName()}.{name}: required Folder is {if child then child.ClassName else "missing"}; restore the authored cosmetics hierarchy and republish Arena/Lobby`
	)
	return child
end

local function effectFolder(folderName: string): Folder
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local assets = requiredFolder(ReplicatedStorage, "Assets")
	local cosmetics = requiredFolder(assets, "Cosmetics")
	local effects = requiredFolder(cosmetics, "Effects")
	return requiredFolder(effects, folderName)
end

local function templateFor(folderName: string, effectId: string): Instance
	local folder = effectFolder(folderName)
	local template = folder:FindFirstChild(effectId)
	assert(
		template ~= nil,
		`{folder:GetFullName()}.{effectId}: required effect template is missing; restore the authored template and republish Arena/Lobby`
	)
	return template
end

local function categoryFor(categoryId: string)
	local path = `Config.Cosmetics.CosmeticEffects.Categories.{categoryId}`
	local category = CosmeticEffectsConfig.Categories[categoryId]
	assert(typeof(category) == "table", `{path}: required category is missing or malformed; correct the configuration and republish Arena/Lobby`)
	assert(typeof(category.DefaultEffectId) == "string" and category.DefaultEffectId ~= "", `{path}.DefaultEffectId: expected nonempty effect id; correct the configuration and republish Arena/Lobby`)
	assert(typeof(category.FolderName) == "string" and category.FolderName ~= "", `{path}.FolderName: expected nonempty folder name; correct the configuration and republish Arena/Lobby`)
	assert(validCount(category.DefaultEmitCount), `{path}.DefaultEmitCount: expected finite nonnegative integer, received {tostring(category.DefaultEmitCount)}; correct the configuration and republish Arena/Lobby`)
	return category
end

local function cueFor(scriptEffects, category, effectId: string)
	local scripted = scriptEffects.get(effectId)
	if scripted ~= nil then
		return scripted, nil
	end
	local template = templateFor(category.FolderName, effectId)
	preflightTemplate(template, category.DefaultEmitCount)
	return nil, template
end

local function playAttempt(scripted, template: Instance?, effectId: string, context: EffectContext, defaultEmit: number): (boolean, string?)
	local attempt = Runtime.createAttempt(context.scope)
	local attemptContext = table.clone(context)
	attemptContext.scope = attempt
	local callOk, result, reason = pcall(function()
		if scripted ~= nil then
			return scripted.play(attemptContext)
		end
		assert(template ~= nil, `[CosmeticEffectFactory] {effectId}: preflight template is missing`)
		playInstance(template, attemptContext, defaultEmit)
		return true, nil
	end)
	if not callOk then
		Runtime.destroyScope(attempt)
		error(result, 0)
	end
	if result == false then
		Runtime.destroyScope(attempt)
		assert(typeof(reason) == "string" and reason ~= "", `[CosmeticEffectFactory] {effectId}: classified playback failure requires a nonempty reason`)
		return false, reason
	end
	Runtime.adoptScope(attempt, context.scope)
	return true, nil
end

-- Permanent cosmetic contract: a selected script may explicitly report a
-- synchronous playback failure. Clean it, try the configured default once,
-- warn with both outcomes, and keep the selected failure in the return value.
function CosmeticEffectFactory.play(categoryId: string, effectId: string?, context: EffectContext): (boolean, string?)
	if context.scope and context.scope.destroyed then
		return false, "effect scope is closed"
	end
	local category = categoryFor(categoryId)
	local resolvedId = if effectId ~= nil and effectId ~= "" then effectId else category.DefaultEffectId

	local ScriptEffects = require(script.Parent.Effects.ScriptEffects)
	local defaultScript, defaultTemplate = cueFor(ScriptEffects, category, category.DefaultEffectId)
	local selectedScript = defaultScript
	local selectedTemplate = defaultTemplate
	if resolvedId ~= category.DefaultEffectId then
		selectedScript, selectedTemplate = cueFor(ScriptEffects, category, resolvedId)
	end
	local selectedOk, selectedReason = playAttempt(selectedScript, selectedTemplate, resolvedId, context, category.DefaultEmitCount)
	if selectedOk then
		return true, nil
	end
	if resolvedId == category.DefaultEffectId then
		warn(`[CosmeticEffectFactory] default effect {resolvedId} failed: {selectedReason}; correct the authored effect`)
		return false, selectedReason
	end
	warn(`[CosmeticEffectFactory] selected effect {resolvedId} failed: {selectedReason}; cleaned its attempt and starting default {category.DefaultEffectId}`)
	local callOk, defaultOk, defaultReason = pcall(playAttempt, defaultScript, defaultTemplate, category.DefaultEffectId, context, category.DefaultEmitCount)
	if not callOk then
		warn(`[CosmeticEffectFactory] default {category.DefaultEffectId} failed after selected {resolvedId}: {defaultOk}`)
		error(defaultOk, 0)
	end
	if defaultOk then
		warn(`[CosmeticEffectFactory] default {category.DefaultEffectId} started after selected {resolvedId} failed`)
	else
		warn(`[CosmeticEffectFactory] default {category.DefaultEffectId} failed after selected {resolvedId}: {defaultReason}`)
	end
	return false, selectedReason
end

return CosmeticEffectFactory
