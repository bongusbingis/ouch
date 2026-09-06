-- Name: MatchAudioLogic.spec.luau
-- Author: Jack C.
-- Description: Spec for match audio routing: which phases play music, the whistle firing only on entering results, and track selection never immediately repeating.
-- Created: 2026-07-25

--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local MatchAudioLogic = require(Client.Modules.Presentation.MatchAudioLogic)

T.describe("MatchAudioLogic", function()
	T.it("announces only an actual start and a decreasing final-seconds clock", function()
		T.expect(MatchAudioLogic.shouldPlayStart("Starting", "Active")):toBeTruthy()
		T.expect(MatchAudioLogic.shouldPlayStart(nil, "Active")):toEqual(false)
		T.expect(MatchAudioLogic.shouldPlayStart("Active", "Active")):toEqual(false)
		T.expect(MatchAudioLogic.shouldPlayTick("Active", 6, 5, 5)):toBeTruthy()
		T.expect(MatchAudioLogic.shouldPlayTick("Active", 5, 3, 5)):toBeTruthy()
		T.expect(MatchAudioLogic.shouldPlayTick("Active", 3, 3, 5)):toEqual(false)
		T.expect(MatchAudioLogic.shouldPlayTick("Active", 3, 4, 5)):toEqual(false)
		T.expect(MatchAudioLogic.shouldPlayTick("Active", 1, 0, 5)):toEqual(false)
		T.expect(MatchAudioLogic.shouldPlayTick("Starting", 3, 2, 5)):toEqual(false)
		T.expect(MatchAudioLogic.shouldPlayTick("Active", nil, 5, 5)):toEqual(false)
	end)
	T.it("routes only match and intermission phases to music", function()
		T.expect(MatchAudioLogic.musicMode("Starting")):toEqual("Match")
		T.expect(MatchAudioLogic.musicMode("Active")):toEqual("Match")
		T.expect(MatchAudioLogic.musicMode("Intermission")):toEqual("Lobby")
		T.expect(MatchAudioLogic.musicMode("Results")):toBeNil()
		T.expect(MatchAudioLogic.musicMode("Idle")):toBeNil()
	end)

	T.it("plays the whistle only on a transition into Results", function()
		T.expect(MatchAudioLogic.shouldPlayWhistle("Active", "Results")):toBeTruthy()
		T.expect(MatchAudioLogic.shouldPlayWhistle("Results", "Results")):toEqual(false)
		T.expect(MatchAudioLogic.shouldPlayWhistle(nil, "Results")):toEqual(false)
		T.expect(MatchAudioLogic.shouldPlayWhistle("Active", "Intermission")):toEqual(false)
	end)

	T.it("selects every track without immediately repeating the previous one", function()
		T.expect(MatchAudioLogic.selectTrackIndex(5, nil, 0.4)):toEqual(3)
		T.expect(MatchAudioLogic.selectTrackIndex(5, 3, 0)):toEqual(1)
		T.expect(MatchAudioLogic.selectTrackIndex(5, 3, 0.5)):toEqual(4)
		T.expect(MatchAudioLogic.selectTrackIndex(5, 3, 1)):toEqual(5)
		T.expect(MatchAudioLogic.selectTrackIndex(1, 1, 0.5)):toEqual(1)
		T.expect(MatchAudioLogic.selectTrackIndex(0, nil, 0.5)):toBeNil()
	end)
end)

return true
