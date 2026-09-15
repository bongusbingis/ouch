-- Name: SplashdownState.luau
-- Author: Jack C.
-- Description: The replicated Splashdown snapshot shape shared by the server that publishes it and the clients that render it, with the idle value and a sanitizer that turns a decoded table into a safe snapshot or nothing.
-- Created: 2026-09-14

--!strict

local SplashdownState = {}

SplashdownState.SchemaVersion = 1

SplashdownState.Phases = table.freeze({
	Idle = "Idle",
	Intro = "Intro",
	Countdown = "Countdown",
	Racing = "Racing",
	RoundOver = "RoundOver",
})

export type Placement = {
	playerId: string,
	time: number,
	placement: number,
	points: number,
}

export type Standing = {
	playerId: string,
	points: number,
	time: number,
}

export type Snapshot = {
	schemaVersion: number,
	revision: number,
	roundIndex: number,
	roundCount: number,
	courseId: string,
	courseName: string,
	checkpointCount: number,
	phase: string,
	phaseEndsAt: number,
	raceStartedAt: number,
	closesAt: number,
	sequence: { string },
	placements: { Placement },
	standings: { Standing },
	lastRound: { courseName: string, placements: { Placement }, dnf: { string } }?,
}

local function finite(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function number(value: any, fallback: number): number
	return if finite(value) then value else fallback
end

local function text(value: any, fallback: string): string
	return if typeof(value) == "string" and #value <= 64 then value else fallback
end

local function copyPlacements(value: any): { Placement }
	local result = {}
	if typeof(value) ~= "table" then
		return result
	end
	for _, entry in value do
		if
			typeof(entry) == "table"
			and typeof(entry.playerId) == "string"
			and finite(entry.time)
			and finite(entry.placement)
			and finite(entry.points)
		then
			table.insert(result, {
				playerId = entry.playerId,
				time = entry.time,
				placement = entry.placement,
				points = entry.points,
			})
		end
	end
	return result
end

local function copyStandings(value: any): { Standing }
	local result = {}
	if typeof(value) ~= "table" then
		return result
	end
	for _, entry in value do
		if
			typeof(entry) == "table"
			and typeof(entry.playerId) == "string"
			and finite(entry.points)
			and finite(entry.time)
		then
			table.insert(result, { playerId = entry.playerId, points = entry.points, time = entry.time })
		end
	end
	return result
end

local function copyIds(value: any): { string }
	local result = {}
	if typeof(value) ~= "table" then
		return result
	end
	for _, entry in value do
		if typeof(entry) == "string" then
			table.insert(result, entry)
		end
	end
	return result
end

function SplashdownState.idle(): Snapshot
	return {
		schemaVersion = SplashdownState.SchemaVersion,
		revision = 0,
		roundIndex = 0,
		roundCount = 0,
		courseId = "",
		courseName = "",
		checkpointCount = 0,
		phase = SplashdownState.Phases.Idle,
		phaseEndsAt = 0,
		raceStartedAt = 0,
		closesAt = 0,
		sequence = {},
		placements = {},
		standings = {},
		lastRound = nil,
	}
end

function SplashdownState.isPhase(value: any): boolean
	return typeof(value) == "string" and SplashdownState.Phases[value] ~= nil
end

function SplashdownState.sanitize(value: any): Snapshot?
	if typeof(value) ~= "table" or value.schemaVersion ~= SplashdownState.SchemaVersion then
		return nil
	end
	local snapshot = SplashdownState.idle()
	snapshot.revision = number(value.revision, 0)
	snapshot.roundIndex = number(value.roundIndex, 0)
	snapshot.roundCount = number(value.roundCount, 0)
	snapshot.courseId = text(value.courseId, "")
	snapshot.courseName = text(value.courseName, "")
	snapshot.checkpointCount = number(value.checkpointCount, 0)
	snapshot.phase = if SplashdownState.isPhase(value.phase) then value.phase else SplashdownState.Phases.Idle
	snapshot.phaseEndsAt = number(value.phaseEndsAt, 0)
	snapshot.raceStartedAt = number(value.raceStartedAt, 0)
	snapshot.closesAt = number(value.closesAt, 0)
	snapshot.sequence = copyIds(value.sequence)
	snapshot.placements = copyPlacements(value.placements)
	snapshot.standings = copyStandings(value.standings)
	if typeof(value.lastRound) == "table" then
		snapshot.lastRound = {
			courseName = text(value.lastRound.courseName, ""),
			placements = copyPlacements(value.lastRound.placements),
			dnf = copyIds(value.lastRound.dnf),
		}
	end
	return snapshot
end

return table.freeze(SplashdownState)
