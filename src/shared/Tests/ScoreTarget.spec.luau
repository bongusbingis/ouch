-- Name: ScoreTarget.spec.luau
-- Author: Jack C.
-- Description: Spec for roster scaling of a mode's elimination target: the authored value holds at the reference roster, small and large lobbies clamp, and a mode without a reference keeps its number.
-- Created: 2026-09-12

--!strict

local T = require(script.Parent.TestKit)
local ScoreTarget = require(script.Parent.Parent.Game.Modes.ScoreTarget)
local ModeRegistry = require(script.Parent.Parent.Game.Modes.ModeRegistry)
local Modes = require(script.Parent.Parent.Parent.Config.Gameplay.Modes)
local GameModes = require(script.Parent.Parent.Parent.Config.Gameplay.GameModes)

T.describe("ScoreTarget", function()
	T.it("keeps the authored target exactly at the reference roster", function()
		for modeId, rules in Modes do
			if rules.ReferencePlayers ~= nil then
				T.expect(ScoreTarget.resolve(rules, rules.ReferencePlayers)):toEqual(rules.ScoreTarget)
				T.expect(type(modeId)):toEqual("string")
			end
		end
	end)

	T.it("scales linearly between the clamps", function()
		local rules = { ScoreTarget = 40, ReferencePlayers = 10, MinScoreTarget = 10, MaxScoreTarget = 80 }
		T.expect(ScoreTarget.resolve(rules, 5)):toEqual(20)
		T.expect(ScoreTarget.resolve(rules, 15)):toEqual(60)
		T.expect(ScoreTarget.resolve(rules, 20)):toEqual(80)
	end)

	T.it("clamps both ends rather than trailing off to nothing or to forever", function()
		local rules = { ScoreTarget = 15, ReferencePlayers = 10, MinScoreTarget = 6, MaxScoreTarget = 25 }
		T.expect(ScoreTarget.resolve(rules, 1)):toEqual(6)
		T.expect(ScoreTarget.resolve(rules, 2)):toEqual(6)
		T.expect(ScoreTarget.resolve(rules, 40)):toEqual(25)
	end)

	T.it("treats a missing or zero roster as one player rather than scaling to zero", function()
		local rules = { ScoreTarget = 40, ReferencePlayers = 10, MinScoreTarget = 1, MaxScoreTarget = 80 }
		T.expect(ScoreTarget.resolve(rules, 0)):toEqual(4)
		T.expect(ScoreTarget.resolve(rules, -3)):toEqual(4)
	end)

	T.it("leaves a mode with no reference roster alone", function()
		T.expect(ScoreTarget.resolve({ ScoreTarget = 15 }, 20)):toEqual(15)
		T.expect(ScoreTarget.resolve({ ScoreTarget = math.huge, ReferencePlayers = 10 }, 20)):toEqual(math.huge)
	end)

	T.it("resolves every registered mode to a playable target across the whole matchmaking range", function()
		for _, mode in ModeRegistry.all() do
			for players = 1, GameModes.MatchCapacity do
				local target = ScoreTarget.resolve(mode.resolveRules(), players)
				T.expect(target > 0):toBeTruthy()
				T.expect(target == math.huge or target % 1 == 0):toBeTruthy()
			end
		end
	end)

	T.it("makes a full lobby of team deathmatch cost more eliminations than a duel", function()
		local rules = ModeRegistry.get("TDM").resolveRules()
		local duel = ScoreTarget.resolve(rules, 2)
		local full = ScoreTarget.resolve(rules, GameModes.MatchCapacity)
		T.expect(full > duel):toBeTruthy()
		-- The failure this scaling exists to stop: forty pooled eliminations across
		-- ten-a-side is four kills each, and the match ends before the ceremony
		-- around it does.
		T.expect(full >= 80):toBeTruthy()
	end)
end)

return true
