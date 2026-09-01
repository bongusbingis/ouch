-- Name: CosmeticEffects.luau
-- Author: Jack C.
-- Description: Drives every cosmetic VFX category from the config registry: on each triggering sim event it plays the acting player's equipped effect at the impact point through the shared factory, deduplicating per category against repeated broadcasts. Shared so both the arena and the lobby test session drive cosmetics through one path.
-- Created: 2026-08-29

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local CosmeticEffectsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CosmeticEffects"))
local SharedCosmetics = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics")
local CosmeticEffectFactory = require(SharedCosmetics:WaitForChild("CosmeticEffectFactory"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))

local CosmeticEffects = {}

local started = false
local dedups: { [string]: EventDedup.Dedup } = {}

local function toVector3(value: any): Vector3?
	if value == nil then
		return nil
	end
	return Vector3.new(value.x, value.y, value.z)
end

local function effectIdFor(slot: string, ownerId: string?): string?
	local player = PlayerIds.fromId(ownerId)
	if player == nil then
		return nil
	end
	local itemId = player:GetAttribute(`Equip_{slot}`) :: string?
	return CosmeticEffectFactory.effectIdForItem(Cosmetics.Items, slot, itemId)
end

function CosmeticEffects.onEvent(event: { [string]: any })
	if not started then
		return
	end
	for categoryId, category in CosmeticEffectsConfig.Categories do
		for _, trigger in category.Triggers do
			if event.kind ~= trigger.Event then
				continue
			end
			if trigger.Match ~= nil and not trigger.Match(event) then
				continue
			end
			if not dedups[categoryId].markSeen(event) then
				break
			end
			local position = toVector3(event[category.PositionField])
			if position == nil then
				break
			end
			CosmeticEffectFactory.play(categoryId, effectIdFor(category.Slot, event[category.OwnerField]), {
				position = position,
				direction = toVector3(event.direction),
			})
			break
		end
	end
end

function CosmeticEffects.start()
	if started then
		return
	end
	started = true
	for categoryId in CosmeticEffectsConfig.Categories do
		dedups[categoryId] = EventDedup.new(4096)
	end
end

return CosmeticEffects
