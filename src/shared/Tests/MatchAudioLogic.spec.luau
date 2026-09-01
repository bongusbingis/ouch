-- Name: MatchAudioLogic.spec.luau
-- Author: Jack C.
-- Description: Spec for match audio routing: which phases play music, the whistle firing only on entering results, and track selection never immediately repeating.
-- Created: 2026-07-25

--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local MatchAudioLogic = require(Client.Modules.Presentation.MatchAudioLogic)

T.describe("MatchAudioLogic", function()
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
