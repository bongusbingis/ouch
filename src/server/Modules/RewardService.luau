--!strict

local PlayerData = require(script.Parent.PlayerData)

export type Reward = {
	kind: string,
	amount: number?,
	itemId: string?,
}

local RewardService = {}

function RewardService.grant(player: Player, reward: Reward): (boolean, string?)
	if reward.kind == "Cash" then
		local amount = reward.amount
		if amount == nil or amount <= 0 then
			return false, "invalid_reward"
		end
		PlayerData.addCash(player, amount)
		return true, nil
	end

	return false, "unsupported_reward"
end

return RewardService
