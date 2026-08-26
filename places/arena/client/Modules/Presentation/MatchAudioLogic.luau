-- Name: MatchAudioLogic.luau
-- Author: Jack C.
-- Description: Pure rules behind match audio: which music mode a match phase maps to, when the results whistle fires, and how the next track is picked without immediately repeating.
-- Created: 2026-07-25

--!strict

local MatchAudioLogic = {}

export type MusicMode = "Match" | "Lobby"

function MatchAudioLogic.musicMode(phase: any): MusicMode?
	if phase == "Starting" or phase == "Active" then
		return "Match"
	end
	if phase == "Intermission" then
		return "Lobby"
	end
	return nil
end

function MatchAudioLogic.shouldPlayWhistle(previousPhase: any, phase: any): boolean
	return phase == "Results" and previousPhase ~= nil and previousPhase ~= "Results"
end

function MatchAudioLogic.selectTrackIndex(trackCount: number, previousIndex: number?, roll: number): number?
	if trackCount <= 0 then
		return nil
	end
	if trackCount == 1 then
		return 1
	end

	local clampedRoll = math.clamp(roll, 0, 1 - 1e-7)
	if previousIndex == nil or previousIndex < 1 or previousIndex > trackCount then
		return math.floor(clampedRoll * trackCount) + 1
	end

	local index = math.floor(clampedRoll * (trackCount - 1)) + 1
	if index >= previousIndex then
		index += 1
	end
	return index
end

return MatchAudioLogic
