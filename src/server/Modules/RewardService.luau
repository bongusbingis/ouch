-- Name: RewardService.luau
-- Author: Jack C.
-- Description: Single entry point for granting rewards, dispatching each reward type to its registered handler so quests, passes, and crates all award through one path.
-- Created: 2026-07-13

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local CosmeticsService = require(script.Parent.CosmeticsService)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)

local RewardService = {}

export type Reward = {
	kind: string,
	amount: number?,
	itemId: string?,
	duplicateRefund: boolean?,
}

type Handler = (player: Player, reward: Reward) -> (boolean, string?)

local handlers: { [string]: Handler } = {}

handlers.Bonks = function(player, reward)
	local amount = reward.amount
	if amount == nil or amount <= 0 or amount % 1 ~= 0 or amount == math.huge then
		return false, "invalid_reward"
	end
	if PlayerData.get(player) == nil then
		return false, "no_profile"
	end
	PlayerData.addBonks(player, amount)
	return true, nil
end

handlers.XP = function(player, reward)
	local amount = reward.amount
	if amount == nil or amount <= 0 or amount % 1 ~= 0 or amount == math.huge then
		return false, "invalid_reward"
	end
	if PlayerData.get(player) == nil then
		return false, "no_profile"
	end
	PlayerData.addXP(player, amount)
	return true, nil
end

handlers.Cosmetic = function(player, reward)
	local itemId = reward.itemId
	if itemId == nil then
		return false, "invalid_reward"
	end
	local item = Cosmetics.Items[itemId]
	if item == nil then
		return false, "unknown_item"
	end
	local granted, reason = CosmeticsService.grant(player, itemId)
	if granted then
		return true, nil
	end
	if reason == "already_owned" then
		local rarity = Cosmetics.Rarities[item.Rarity]
		local refund = if rarity then rarity.DupeBonks else 0
		if refund > 0 and reward.duplicateRefund ~= false then
			PlayerData.addBonks(player, refund)
			local data = PlayerData.get(player)
			pcall(
				AnalyticsService.logEconomyEvent,
				player,
				"Source",
				"Bonks",
				refund,
				if data then data.Bonks else 0,
				"Gameplay",
				itemId,
				{ source = "DuplicateReward" }
			)
		end
		return true, nil
	end
	return false, reason or "grant_failed"
end

function RewardService.registerHandler(kind: string, handler: Handler)
	handlers[kind] = handler
end

function RewardService.grant(player: Player, reward: Reward): (boolean, string?)
	local handler = handlers[reward.kind]
	if handler == nil then
		warn(`[RewardService] unsupported reward kind "{reward.kind}" for {player.Name}`)
		return false, "unsupported_reward"
	end
	return handler(player, reward)
end

return RewardService
