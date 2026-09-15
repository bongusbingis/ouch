-- Name: RaceRound.luau
-- Author: Jack C.
-- Description: Pure state for one Splashdown round: who is racing, which checkpoint each racer holds, finish times, splash counts, and when the round closes; it decides nothing about how those outcomes are applied.
-- Created: 2026-09-14

--!strict

local RacePoints = require(script.Parent.RacePoints)

local RaceRound = {}

export type Phase = "Pending" | "Racing" | "Closed"

export type Racer = {
	checkpoint: number,
	finishTime: number?,
	splashes: number,
}

export type Round = {
	courseId: string,
	checkpointCount: number,
	capSeconds: number,
	closeWindowSeconds: number,
	phase: Phase,
	startedAt: number?,
	closesAt: number?,
	firstFinishAt: number?,
	racers: { [string]: Racer },
}

export type Outcome = {
	finishers: { RacePoints.Finisher },
	dnf: { string },
}

function RaceRound.new(courseId: string, checkpointCount: number, capSeconds: number, closeWindowSeconds: number): Round
	assert(checkpointCount % 1 == 0 and checkpointCount >= 0, "[RaceRound] checkpointCount must be a whole number")
	assert(capSeconds > 0, "[RaceRound] capSeconds must be positive")
	assert(closeWindowSeconds >= 0, "[RaceRound] closeWindowSeconds must not be negative")
	return {
		courseId = courseId,
		checkpointCount = checkpointCount,
		capSeconds = capSeconds,
		closeWindowSeconds = closeWindowSeconds,
		phase = "Pending",
		startedAt = nil,
		closesAt = nil,
		firstFinishAt = nil,
		racers = {},
	}
end

function RaceRound.addRacer(round: Round, playerId: string): Racer
	local racer = round.racers[playerId]
	if racer == nil then
		racer = { checkpoint = 0, finishTime = nil, splashes = 0 }
		round.racers[playerId] = racer
	end
	return racer
end

function RaceRound.removeRacer(round: Round, playerId: string): boolean
	if round.racers[playerId] == nil then
		return false
	end
	round.racers[playerId] = nil
	return true
end

function RaceRound.start(round: Round, now: number): boolean
	if round.phase ~= "Pending" then
		return false
	end
	round.phase = "Racing"
	round.startedAt = now
	round.closesAt = now + round.capSeconds
	return true
end

-- Checkpoints must be taken in order: the only checkpoint that counts is the
-- one after the racer's current one, so no volume can be skipped or replayed.
function RaceRound.reachCheckpoint(round: Round, playerId: string, index: number): boolean
	local racer = round.racers[playerId]
	if round.phase ~= "Racing" or racer == nil or racer.finishTime ~= nil then
		return false
	end
	if index ~= racer.checkpoint + 1 or index > round.checkpointCount then
		return false
	end
	racer.checkpoint = index
	return true
end

function RaceRound.finish(round: Round, playerId: string, now: number): boolean
	local racer = round.racers[playerId]
	if round.phase ~= "Racing" or racer == nil or racer.finishTime ~= nil then
		return false
	end
	if racer.checkpoint < round.checkpointCount then
		return false
	end
	local startedAt = assert(round.startedAt, "[RaceRound] a racing round has a start time")
	racer.finishTime = math.max(now - startedAt, 0)
	if round.firstFinishAt == nil then
		round.firstFinishAt = now
		local closesAt = assert(round.closesAt, "[RaceRound] a racing round has a close time")
		round.closesAt = math.min(closesAt, now + round.closeWindowSeconds)
	end
	return true
end

function RaceRound.splash(round: Round, playerId: string): number?
	local racer = round.racers[playerId]
	if racer == nil or racer.finishTime ~= nil then
		return nil
	end
	racer.splashes += 1
	return racer.splashes
end

-- Zero means the start pads.
function RaceRound.respawnIndex(round: Round, playerId: string): number
	local racer = round.racers[playerId]
	return if racer then racer.checkpoint else 0
end

function RaceRound.hasFinished(round: Round, playerId: string): boolean
	local racer = round.racers[playerId]
	return racer ~= nil and racer.finishTime ~= nil
end

function RaceRound.counts(round: Round): (number, number)
	local total, finished = 0, 0
	for _, racer in round.racers do
		total += 1
		if racer.finishTime ~= nil then
			finished += 1
		end
	end
	return total, finished
end

function RaceRound.shouldClose(round: Round, now: number): boolean
	if round.phase ~= "Racing" then
		return false
	end
	local total, finished = RaceRound.counts(round)
	if total > 0 and finished == total then
		return true
	end
	local closesAt = assert(round.closesAt, "[RaceRound] a racing round has a close time")
	return now >= closesAt
end

function RaceRound.close(round: Round): Outcome
	round.phase = "Closed"
	local finishers = {}
	local dnf = {}
	for playerId, racer in round.racers do
		if racer.finishTime ~= nil then
			table.insert(finishers, { playerId = playerId, time = racer.finishTime })
		else
			table.insert(dnf, playerId)
		end
	end
	table.sort(dnf)
	return { finishers = finishers, dnf = dnf }
end

return table.freeze(RaceRound)
