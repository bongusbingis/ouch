-- Description: Checks that the bumper metronome keeps an even musical grid, learns a track's tempo from its onsets, holds the count through quiet passages, and only fires on the downbeat of each bar.

--!strict

local T = require(script.Parent.TestKit)
local BeatClock = require(script.Parent.Parent.Game.Util.BeatClock)

local function settings(overrides: { [string]: any }?): BeatClock.Settings
	local base: { [string]: any } = {
		DefaultPeriodSeconds = 0.5,
		MinPeriodSeconds = 0.3,
		MaxPeriodSeconds = 1.0,
		EnvelopeResponseHz = 3,
		LoudnessFloor = 8,
		Sensitivity = 1.35,
		OnsetGapSeconds = 0.25,
		TempoSamples = 8,
		TempoAdaptRate = 0.35,
		PhaseCorrection = 0.12,
		PhaseWindow = 0.25,
		LockedScale = 0.25,
		BeatsPerPulse = 4,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base :: any
end

-- Plays `seconds` of a track whose onsets land every `beatPeriod`, sampling at
-- 60 fps, and returns the track time of every pulse.
local function play(
	clock: BeatClock.Clock,
	config: BeatClock.Settings,
	seconds: number,
	beatPeriod: number?,
	start: number?
)
	local pulses = {}
	local step = 1 / 60
	local time = start or 0
	local finish = time + seconds
	local quiet = beatPeriod == nil
	while time < finish do
		local loudness = 10
		if not quiet then
			local phase = time % (beatPeriod :: number)
			loudness = if phase < step * 1.5 then 400 else 20
		end
		local fired = BeatClock.advance(clock, config, time, loudness, step)
		for _ = 1, fired do
			table.insert(pulses, time)
		end
		time += step
	end
	return pulses
end

local function gaps(times: { number }): { number }
	local out = {}
	for index = 2, #times do
		table.insert(out, times[index] - times[index - 1])
	end
	return out
end

T.describe("BeatClock", function()
	T.it("fires on an even grid rather than on every loud moment", function()
		local config = settings({ BeatsPerPulse = 1 })
		local clock = BeatClock.new(config)
		BeatClock.reset(clock, config, 0, 0)
		local pulses = play(clock, config, 12, 0.5)
		T.expect(#pulses > 18):toBeTruthy()
		for _, gap in gaps(pulses) do
			T.expect(gap):toBeNear(0.5, 0.05)
		end
	end)
	T.it("counts a bar between squashes so the pattern is impulse-2-3-4", function()
		local config = settings()
		local clock = BeatClock.new(config)
		BeatClock.reset(clock, config, 0, 0)
		local pulses = play(clock, config, 20, 0.5)
		T.expect(#pulses >= 8):toBeTruthy()
		for _, gap in gaps(pulses) do
			T.expect(gap):toBeNear(2.0, 0.09)
		end
	end)
	T.it("learns a tempo the default does not already match", function()
		local config = settings({ BeatsPerPulse = 1 })
		local clock = BeatClock.new(config)
		BeatClock.reset(clock, config, 0, 0)
		play(clock, config, 25, 0.75)
		T.expect(clock.period):toBeNear(0.75, 0.05)
		T.expect(BeatClock.beatsPerMinute(clock)):toBeNear(80, 6)
	end)
	T.it("folds a double-time or half-time onset run onto the same tempo", function()
		local config = settings({ BeatsPerPulse = 1 })
		local eighths = settings({ BeatsPerPulse = 1, OnsetGapSeconds = 0.12 })
		local fast = BeatClock.new(eighths)
		BeatClock.reset(fast, eighths, 0, 0)
		play(fast, eighths, 20, 0.25)
		T.expect(fast.period):toBeNear(0.5, 0.06)
		local slow = BeatClock.new(config)
		BeatClock.reset(slow, config, 0, 0)
		play(slow, config, 20, 1.6)
		T.expect(slow.period >= config.MinPeriodSeconds):toBeTruthy()
		T.expect(slow.period <= config.MaxPeriodSeconds):toBeTruthy()
	end)
	T.it("keeps the count going through a passage with no onsets at all", function()
		local config = settings({ BeatsPerPulse = 1 })
		local clock = BeatClock.new(config)
		BeatClock.reset(clock, config, 0, 0)
		play(clock, config, 6, 0.5)
		local quiet = play(clock, config, 8, nil, 6)
		T.expect(#quiet >= 14):toBeTruthy()
		for _, gap in gaps(quiet) do
			T.expect(gap):toBeNear(0.5, 0.05)
		end
	end)
	T.it("holds its tempo but restarts the bar when a track loops", function()
		local config = settings({ BeatsPerPulse = 1 })
		local clock = BeatClock.new(config)
		BeatClock.reset(clock, config, 0, 0)
		play(clock, config, 20, 0.75)
		local learned = clock.period
		T.expect(BeatClock.advance(clock, config, 0.4, 10, 1 / 60)):toEqual(0)
		T.expect(clock.period):toEqual(learned)
		T.expect(clock.beatIndex):toEqual(0)
	end)
	T.it("reports no pulse when the grid is still ahead of the track", function()
		local config = settings({ BeatsPerPulse = 1 })
		local clock = BeatClock.new(config)
		BeatClock.reset(clock, config, 4, 10)
		T.expect(BeatClock.advance(clock, config, 4.1, 10, 1 / 60)):toEqual(0)
		T.expect(clock.nextBeatAt):toBeNear(4.5, 1e-6)
		T.expect(BeatClock.advance(clock, config, 4.6, 10, 1 / 60)):toEqual(1)
	end)
	T.it("ignores an off-beat accent once it has locked onto the tempo", function()
		local config = settings({ BeatsPerPulse = 1 })
		local clock = BeatClock.new(config)
		BeatClock.reset(clock, config, 0, 0)
		play(clock, config, 20, 0.5)
		T.expect(BeatClock.isLocked(clock, config)):toBeTruthy()
		local grid, period = clock.nextBeatAt, clock.period
		-- an accent landing squarely between two beats must not drag the count:
		-- the grid may step forward a whole beat, but its phase cannot move
		BeatClock.advance(clock, config, grid + period / 2, 400, 1 / 60)
		local drift = (clock.nextBeatAt - grid) % period
		T.expect(math.min(drift, period - drift)):toBeNear(0, 1e-4)
	end)
	T.it("treats a loudness rise as an onset that steers the grid, not as a pulse", function()
		local config = settings({ BeatsPerPulse = 1 })
		local clock = BeatClock.new(config)
		BeatClock.reset(clock, config, 4, 0)
		T.expect(BeatClock.advance(clock, config, 4.1, 400, 1 / 60)):toEqual(0)
		T.expect(clock.nextBeatAt ~= 4.5):toBeTruthy()
		T.expect(clock.nextBeatAt):toBeNear(4.5, 0.08)
	end)
end)
return true
