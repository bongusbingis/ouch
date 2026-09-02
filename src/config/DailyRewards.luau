-- Name: DailyRewards.luau
-- Author: Jack C.
-- Description: Reward schedule, cycle length, and UI styling hints for the 7-day daily login reward system.
-- Created: 2026-09-01

--!strict

local Cosmetics = require(script.Parent.Cosmetics)

export type Reward = {
	kind: "Bonks" | "Cosmetic",
	amount: number?,
	itemId: string?,
}

local CYCLE_LENGTH = 7

local Rewards: { [number]: Reward } = {
	[1] = { kind = "Bonks", amount = 100 },
	[2] = { kind = "Bonks", amount = 125 },
	[3] = { kind = "Bonks", amount = 150 },
	[4] = { kind = "Bonks", amount = 200 },
	[5] = { kind = "Bonks", amount = 250 },
	[6] = { kind = "Bonks", amount = 300 },
	[7] = { kind = "Bonks", amount = 500 },
}

for day, reward in Rewards do
	assert(day >= 1 and day <= CYCLE_LENGTH, `reward day {day} outside 1..{CYCLE_LENGTH}`)
	if reward.kind == "Cosmetic" then
		assert(
			reward.itemId ~= nil and Cosmetics.Items[reward.itemId] ~= nil,
			`day {day} rewards unknown cosmetic "{tostring(reward.itemId)}"`
		)
	elseif reward.kind == "Bonks" then
		assert((reward.amount or 0) > 0, `day {day} Bonks reward must be positive`)
	end
end

return {
	CycleLength = CYCLE_LENGTH,
	Rewards = Rewards,

	UI = {
		ClaimColor = Color3.fromRGB(154, 233, 91),
		ClaimedColor = Color3.fromRGB(100, 100, 100),
		AvailableGlow = Color3.fromRGB(255, 211, 51),
		LockedTransparency = 0.45,
	},
}
