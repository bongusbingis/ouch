--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local CosmeticsService = require(script.Parent.CosmeticsService)
local PlayerData = require(script.Parent.PlayerData)

-- Dispatches reward grants by kind, mirroring MonetizationService.registerHandler.
--
-- Duplicate cosmetics resolve as GrantOrRefund: an already-owned item pays the
-- rarity's DupeCash instead. Returning false there would leave the reward
-- permanently unclaimable, since callers only mark a reward claimed once the
-- grant succeeds -- and it reuses the exact dupe economics crates already use.

local RewardService = {}

export type Reward = {
	kind: string,
	amount: number?,
	itemId: string?,
}

type Handler = (player: Player, reward: Reward) -> (boolean, string?)

local handlers: { [string]: Handler } = {}

handlers.Cash = function(player, reward)
	local amount = reward.amount
	if amount == nil or amount <= 0 then
		return false, "invalid_reward"
	end
	PlayerData.addCash(player, amount)
	return true, nil
end

handlers.XP = function(player, reward)
	local amount = reward.amount
	if amount == nil or amount <= 0 then
		return false, "invalid_reward"
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
		local refund = if rarity then rarity.DupeCash else 0
		if refund > 0 then
			PlayerData.addCash(player, refund)
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
