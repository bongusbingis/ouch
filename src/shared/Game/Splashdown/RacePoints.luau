-- Name: RacePoints.luau
-- Author: Jack C.
-- Description: Pure Splashdown scoring: finish-time order becomes placements and points for one round, and rounds accumulate into match standings ordered by points, then cumulative time, then id.
-- Created: 2026-09-14

--!strict

local RacePoints = {}

export type Finisher = { playerId: string, time: number }

export type Placement = {
	playerId: string,
	time: number,
	placement: number,
	points: number,
}

export type RoundScore = {
	courseId: string,
	capSeconds: number,
	placements: { Placement },
}

export type Standing = {
	playerId: string,
	points: number,
	time: number,
	finishes: number,
	bestPlacement: number?,
}

-- First place scores pointsForFirst and every place below it one less, never
-- below one, so a full lobby's winner always scores the same number.
function RacePoints.forPlacement(placement: number, pointsForFirst: number): number
	assert(placement % 1 == 0 and placement >= 1, "[RacePoints] placement must be a positive integer")
	return math.max(pointsForFirst - placement + 1, 1)
end

function RacePoints.placements(finishers: { Finisher }, pointsForFirst: number): { Placement }
	local sorted = table.clone(finishers)
	table.sort(sorted, function(a, b)
		if a.time == b.time then
			return a.playerId < b.playerId
		end
		return a.time < b.time
	end)
	local result = {}
	for index, finisher in sorted do
		table.insert(result, {
			playerId = finisher.playerId,
			time = finisher.time,
			placement = index,
			points = RacePoints.forPlacement(index, pointsForFirst),
		})
	end
	return result
end

-- A round a player did not finish charges them that round's cap, so cumulative
-- time stays comparable between finishers and non-finishers in the tiebreak.
function RacePoints.standings(rounds: { RoundScore }, playerIds: { string }): { Standing }
	local byId: { [string]: Standing } = {}
	for _, playerId in playerIds do
		byId[playerId] = { playerId = playerId, points = 0, time = 0, finishes = 0, bestPlacement = nil }
	end
	for _, round in rounds do
		local finished: { [string]: boolean } = {}
		for _, placement in round.placements do
			local standing = byId[placement.playerId]
			if standing then
				standing.points += placement.points
				standing.time += placement.time
				standing.finishes += 1
				finished[placement.playerId] = true
				local best = standing.bestPlacement
				if best == nil or placement.placement < best then
					standing.bestPlacement = placement.placement
				end
			end
		end
		for playerId, standing in byId do
			if not finished[playerId] then
				standing.time += round.capSeconds
			end
		end
	end

	local list = {}
	for _, standing in byId do
		table.insert(list, standing)
	end
	table.sort(list, function(a, b)
		if a.points ~= b.points then
			return a.points > b.points
		end
		if a.time ~= b.time then
			return a.time < b.time
		end
		return a.playerId < b.playerId
	end)
	return list
end

-- Nobody wins a match in which nobody finished a round.
function RacePoints.winner(standings: { Standing }): string?
	local leader = standings[1]
	if leader == nil or leader.points <= 0 then
		return nil
	end
	return leader.playerId
end

return table.freeze(RacePoints)
