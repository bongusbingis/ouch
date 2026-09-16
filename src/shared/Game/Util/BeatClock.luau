-- Description: Locks a steady metronome to a playing track, estimating the beat period from loudness onsets and correcting its phase toward them, so effects can fire on an even musical grid instead of on whatever moment the track happens to be loud.

--!strict

local BeatClock = {}

export type Settings = {
	DefaultPeriodSeconds: number,
	MinPeriodSeconds: number,
	MaxPeriodSeconds: number,
	EnvelopeResponseHz: number,
	LoudnessFloor: number,
	Sensitivity: number,
	OnsetGapSeconds: number,
	TempoSamples: number,
	TempoAdaptRate: number,
	PhaseCorrection: number,
	PhaseWindow: number,
	LockedScale: number,
	BeatsPerPulse: number,
}

export type Clock = {
	period: number,
	nextBeatAt: number,
	beatIndex: number,
	envelope: number,
	previousLoudness: number,
	lastOnsetAt: number,
	intervals: { number },
	time: number,
}

local MAX_BEATS_PER_STEP = 8

function BeatClock.new(settings: Settings): Clock
	return {
		period = settings.DefaultPeriodSeconds,
		nextBeatAt = 0,
		beatIndex = 0,
		envelope = 0,
		previousLoudness = 0,
		lastOnsetAt = -math.huge,
		intervals = {},
		time = 0,
	}
end

-- Starts the grid one period ahead of where the track is now. The tempo learned
-- so far is deliberately kept: a track that loops or is seeked has not changed
-- speed, only position.
function BeatClock.rephase(clock: Clock, trackTime: number, loudness: number)
	clock.nextBeatAt = trackTime + clock.period
	clock.beatIndex = 0
	clock.envelope = loudness
	clock.previousLoudness = loudness
	clock.lastOnsetAt = -math.huge
	clock.time = trackTime
end

function BeatClock.reset(clock: Clock, settings: Settings, trackTime: number, loudness: number)
	clock.period = settings.DefaultPeriodSeconds
	clock.intervals = {}
	BeatClock.rephase(clock, trackTime, loudness)
end

-- Two onsets a bar apart and two an eighth apart describe the same tempo, so an
-- interval is doubled or halved into the musical range before it is believed.
local function fold(interval: number, minimum: number, maximum: number): number?
	if interval <= 0 then
		return nil
	end
	local folded = interval
	local guard = 0
	while folded < minimum and guard < 8 do
		folded *= 2
		guard += 1
	end
	while folded > maximum and guard < 16 do
		folded /= 2
		guard += 1
	end
	if folded < minimum or folded > maximum then
		return nil
	end
	return folded
end

local function median(values: { number }): number?
	local count = #values
	if count == 0 then
		return nil
	end
	local sorted = table.clone(values)
	table.sort(sorted)
	if count % 2 == 1 then
		return sorted[(count + 1) // 2]
	end
	return (sorted[count // 2] + sorted[count // 2 + 1]) / 2
end

-- Until the interval window is full the clock is still working out the track and
-- follows the onsets closely. After that it is locked: it keeps its own time and
-- only trims, which is what stops the squash drifting bar to bar.
local function isLocked(clock: Clock, settings: Settings): boolean
	return #clock.intervals >= math.max(settings.TempoSamples, 1)
end

local function observeOnset(clock: Clock, settings: Settings, trackTime: number)
	local locked = isLocked(clock, settings)
	local scale = if locked then math.clamp(settings.LockedScale, 0, 1) else 1
	if clock.lastOnsetAt > -math.huge then
		local folded = fold(trackTime - clock.lastOnsetAt, settings.MinPeriodSeconds, settings.MaxPeriodSeconds)
		if folded then
			table.insert(clock.intervals, folded)
			while #clock.intervals > math.max(settings.TempoSamples, 1) do
				table.remove(clock.intervals, 1)
			end
			-- The median ignores the occasional syncopation or missed onset that
			-- a running average would fold into the tempo forever.
			local estimate = median(clock.intervals)
			if estimate then
				clock.period += (estimate - clock.period) * math.clamp(settings.TempoAdaptRate, 0, 1) * scale
			end
		end
	end
	clock.lastOnsetAt = trackTime
	if clock.period <= 0 then
		return
	end
	local offset = (trackTime - clock.nextBeatAt) % clock.period
	if offset > clock.period / 2 then
		offset -= clock.period
	end
	-- A locked clock ignores an onset that lands nowhere near a beat: that is
	-- syncopation or a fill, and following it is exactly what made the old
	-- loudness-triggered squash look random.
	if locked and math.abs(offset) > clock.period * math.clamp(settings.PhaseWindow, 0, 0.5) then
		return
	end
	clock.nextBeatAt += offset * math.clamp(settings.PhaseCorrection, 0, 1) * scale
end

-- Returns how many pulses fall in this step. The metronome free-runs whether or
-- not the track is giving usable onsets, so a quiet passage keeps the same count
-- going instead of stopping the effect.
function BeatClock.advance(
	clock: Clock,
	settings: Settings,
	trackTime: number,
	loudness: number,
	deltaTime: number
): number
	if trackTime < clock.time then
		BeatClock.rephase(clock, trackTime, loudness)
		return 0
	end
	clock.time = trackTime

	local alpha = 1 - math.exp(-settings.EnvelopeResponseHz * math.max(deltaTime, 0))
	clock.envelope += (loudness - clock.envelope) * alpha
	local threshold = math.max(settings.LoudnessFloor, clock.envelope * settings.Sensitivity)
	if
		loudness > clock.previousLoudness
		and loudness >= threshold
		and trackTime - clock.lastOnsetAt >= settings.OnsetGapSeconds
	then
		observeOnset(clock, settings, trackTime)
	end
	clock.previousLoudness = loudness

	clock.period = math.clamp(clock.period, settings.MinPeriodSeconds, settings.MaxPeriodSeconds)
	local pulses = 0
	local beats = 0
	local every = math.max(math.floor(settings.BeatsPerPulse), 1)
	while trackTime >= clock.nextBeatAt and beats < MAX_BEATS_PER_STEP do
		if clock.beatIndex % every == 0 then
			pulses += 1
		end
		clock.beatIndex += 1
		clock.nextBeatAt += clock.period
		beats += 1
	end
	if beats >= MAX_BEATS_PER_STEP then
		BeatClock.rephase(clock, trackTime, loudness)
	end
	return pulses
end

function BeatClock.isLocked(clock: Clock, settings: Settings): boolean
	return isLocked(clock, settings)
end

function BeatClock.beatsPerMinute(clock: Clock): number
	if clock.period <= 0 then
		return 0
	end
	return 60 / clock.period
end

return BeatClock
