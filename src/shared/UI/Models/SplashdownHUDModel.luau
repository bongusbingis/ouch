-- Name: SplashdownHUDModel.luau
-- Author: Jack C.
-- Description: Pure Splashdown HUD copy derived from the replicated race snapshot and the local racer's attributes: the round and course line, countdown and GO, the race clock and closing window, checkpoint progress, the finish banner, and the round-results toast rows.
-- Created: 2026-09-14

--!strict

local SplashdownHUDModel = {}

export type Input = {
	snapshot: any,
	localPlayerId: string,
	checkpoint: number?,
	finishTime: number?,
	splashes: number?,
	roundPoints: number?,
	names: { [string]: string }?,
}

export type ToastRow = {
	placement: number,
	name: string,
	time: string,
	points: number,
	isLocal: boolean,
}

export type Toast = {
	title: string,
	subtitle: string,
	rows: { ToastRow },
	summary: string,
}

export type View = {
	visible: boolean,
	phase: string,
	title: string,
	roundLabel: string,
	sequence: { string },
	intro: boolean,
	courseId: string,
	introEndsAt: number,
	countdown: string?,
	clock: string,
	closing: string?,
	checkpointLabel: string,
	checkpointProgress: number,
	finished: boolean,
	finishLabel: string?,
	finishedCount: number,
	toast: Toast?,
}

local GO_SECONDS = 1.2
local TOAST_ROWS = 5

function SplashdownHUDModel.ordinal(placement: number): string
	local tens = placement % 100
	local suffix = "TH"
	if tens < 11 or tens > 13 then
		local ones = placement % 10
		if ones == 1 then
			suffix = "ST"
		elseif ones == 2 then
			suffix = "ND"
		elseif ones == 3 then
			suffix = "RD"
		end
	end
	return `{placement}{suffix}`
end

function SplashdownHUDModel.formatTime(seconds: number): string
	local tenths = math.floor(math.max(seconds, 0) * 10 + 0.5)
	local minutes = math.floor(tenths / 600)
	local rest = (tenths - minutes * 600) / 10
	return string.format("%d:%04.1f", minutes, rest)
end

local function nameFor(input: Input, playerId: string): string
	if playerId == input.localPlayerId then
		return "YOU"
	end
	local names = input.names
	return if names and names[playerId] then names[playerId] else playerId
end

local function toastFor(input: Input, snapshot: any): Toast?
	local last = snapshot.lastRound
	if last == nil then
		return nil
	end
	local rows: { ToastRow } = {}
	local localRow: ToastRow? = nil
	for _, placement in last.placements do
		local row = {
			placement = placement.placement,
			name = nameFor(input, placement.playerId),
			time = SplashdownHUDModel.formatTime(placement.time),
			points = placement.points,
			isLocal = placement.playerId == input.localPlayerId,
		}
		if row.isLocal then
			localRow = row
		end
		if #rows < TOAST_ROWS then
			table.insert(rows, row)
		end
	end
	if localRow and not table.find(rows, localRow) then
		table.insert(rows, localRow)
	end
	local summary
	if localRow then
		summary = `YOU FINISHED {SplashdownHUDModel.ordinal(localRow.placement)} • +{localRow.points} POINTS`
	elseif table.find(last.dnf, input.localPlayerId) then
		summary = "YOU DID NOT FINISH • +0 POINTS"
	else
		summary = `{#last.placements} FINISHED`
	end
	return {
		title = `ROUND {snapshot.roundIndex} RESULTS`,
		subtitle = last.courseName,
		rows = rows,
		summary = summary,
	}
end

function SplashdownHUDModel.build(input: Input, now: number): View
	local snapshot = input.snapshot
	local phase = snapshot.phase
	local checkpointCount = math.max(snapshot.checkpointCount or 0, 0)
	local checkpoint = math.clamp(input.checkpoint or 0, 0, checkpointCount)
	local finished = input.finishTime ~= nil
	local racing = phase == "Racing"

	local countdown: string? = nil
	if phase == "Countdown" then
		countdown = tostring(math.max(math.ceil(snapshot.phaseEndsAt - now), 1))
	elseif racing and now - snapshot.raceStartedAt < GO_SECONDS then
		countdown = "GO!"
	end

	local clock = "0:00.0"
	if racing then
		clock = SplashdownHUDModel.formatTime(now - snapshot.raceStartedAt)
		if finished then
			clock = SplashdownHUDModel.formatTime(input.finishTime :: number)
		end
	elseif phase == "RoundOver" and finished then
		clock = SplashdownHUDModel.formatTime(input.finishTime :: number)
	end

	local closing: string? = nil
	if racing and #snapshot.placements > 0 and snapshot.closesAt > 0 then
		closing = `RACE ENDS IN {math.max(math.ceil(snapshot.closesAt - now), 0)}`
	end

	local finishLabel: string? = nil
	if finished then
		local placement = nil
		for _, entry in snapshot.placements do
			if entry.playerId == input.localPlayerId then
				placement = entry.placement
				break
			end
		end
		finishLabel = if placement then `FINISHED {SplashdownHUDModel.ordinal(placement)}` else "FINISHED"
	end

	local checkpointLabel = if finished
		then "FINISHED"
		elseif checkpointCount == 0 then "RACE TO THE FINISH"
		else `CHECKPOINT {checkpoint} / {checkpointCount}`
	local progress = if finished then 1 elseif checkpointCount == 0 then 0 else checkpoint / checkpointCount

	return {
		visible = phase ~= "Idle",
		phase = phase,
		title = if snapshot.courseName ~= "" then snapshot.courseName else "SPLASHDOWN",
		roundLabel = if snapshot.roundIndex > 0
			then `ROUND {snapshot.roundIndex} OF {snapshot.roundCount}`
			else "GET READY",
		sequence = table.clone(snapshot.sequence),
		intro = phase == "Intro",
		courseId = snapshot.courseId,
		introEndsAt = snapshot.phaseEndsAt,
		countdown = countdown,
		clock = clock,
		closing = closing,
		checkpointLabel = checkpointLabel,
		checkpointProgress = progress,
		finished = finished,
		finishLabel = finishLabel,
		finishedCount = #snapshot.placements,
		toast = if phase == "RoundOver" then toastFor(input, snapshot) else nil,
	}
end

return table.freeze(SplashdownHUDModel)
