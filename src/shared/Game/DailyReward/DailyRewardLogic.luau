-- Name: DailyRewardLogic.luau
-- Author: Jack C.
-- Description: Pure daily reward rules: UTC-day gating, cycle progression without streak reset, and client payload construction, with time always passed in.
-- Created: 2026-09-01

--!strict

local DailyRewardLogic = {}

export type DailyRewardState = {
	Day: number,
	LastClaimAt: number,
	TotalClaimed: number,
}

export type Reward = {
	kind: string,
	amount: number?,
	itemId: string?,
}

export type PublicDay = {
	day: number,
	reward: Reward,
	claimed: boolean,
	available: boolean,
	current: boolean,
}

export type ClaimResult = {
	day: number,
	reward: Reward,
}

export type PublicState = {
	canClaim: boolean,
	currentDay: number,
	nextDay: number,
	days: { PublicDay },
	totalClaimed: number,
	secondsUntilReset: number,
}

export type Config = {
	CycleLength: number,
	Rewards: { [number]: Reward },
}

local SECONDS_PER_DAY = 86400

function DailyRewardLogic.blankState(): DailyRewardState
	return {
		Day = 0,
		LastClaimAt = 0,
		TotalClaimed = 0,
	}
end

function DailyRewardLogic.readState(raw: any): DailyRewardState
	if type(raw) ~= "table" then
		return DailyRewardLogic.blankState()
	end
	return {
		Day = if type(raw.Day) == "number" then raw.Day else 0,
		LastClaimAt = if type(raw.LastClaimAt) == "number" then raw.LastClaimAt else 0,
		TotalClaimed = if type(raw.TotalClaimed) == "number" then raw.TotalClaimed else 0,
	}
end

function DailyRewardLogic.dailyKey(now: number): string
	return os.date("!%Y-%m-%d", now) :: string
end

function DailyRewardLogic.canClaim(state: DailyRewardState, now: number): boolean
	if state.LastClaimAt == 0 then
		return true
	end
	return DailyRewardLogic.dailyKey(now) ~= DailyRewardLogic.dailyKey(state.LastClaimAt)
end

function DailyRewardLogic.nextDay(state: DailyRewardState, config: Config): number
	return (state.Day % config.CycleLength) + 1
end

function DailyRewardLogic.claim(state: DailyRewardState, config: Config, now: number): (DailyRewardState?, ClaimResult?)
	if not DailyRewardLogic.canClaim(state, now) then
		return nil, nil
	end

	local day = DailyRewardLogic.nextDay(state, config)
	local reward = config.Rewards[day]
	if reward == nil then
		return nil, nil
	end

	local newState: DailyRewardState = {
		Day = day,
		LastClaimAt = now,
		TotalClaimed = state.TotalClaimed + 1,
	}

	return newState, { day = day, reward = { kind = reward.kind, amount = reward.amount, itemId = reward.itemId } }
end

function DailyRewardLogic.secondsUntilReset(now: number): number
	local currentDayStart = now - (now % SECONDS_PER_DAY)
	local nextDayStart = currentDayStart + SECONDS_PER_DAY
	return nextDayStart - now
end

function DailyRewardLogic.publicState(state: DailyRewardState, config: Config, now: number): PublicState
	local claimable = DailyRewardLogic.canClaim(state, now)
	local next = DailyRewardLogic.nextDay(state, config)

	local days: { PublicDay } = {}
	for day = 1, config.CycleLength do
		local reward = config.Rewards[day]
		if reward == nil then
			continue
		end

		local claimed = day <= state.Day
		local available = day == next and claimable
		local current = day == next

		table.insert(days, {
			day = day,
			reward = { kind = reward.kind, amount = reward.amount, itemId = reward.itemId },
			claimed = claimed,
			available = available,
			current = current,
		})
	end

	return {
		canClaim = claimable,
		currentDay = state.Day,
		nextDay = next,
		days = days,
		totalClaimed = state.TotalClaimed,
		secondsUntilReset = DailyRewardLogic.secondsUntilReset(now),
	}
end

return DailyRewardLogic
