-- Match bonuses require participation; repeat-opponent caps never change combat scores.
--!strict
local T = require(script.Parent.TestKit)
local P = require(script.Parent.Parent.Game.Economy.Participation)
local Config = require(script.Parent.Parent.Parent.Config.Progression.Data).Participation
T.describe("Participation", function()
	T.it("withholds completion and win payouts from an idle player", function()
		local state = P.new()
		for i = 1, 120 do
			P.sample(state, vector.zero, i, 0.5, Config)
		end
		T.expect(P.eligible(state, { Elims = 0, Catches = 0 }, Config)):toEqual(false)
	end)
	T.it("qualifies active movement, stationary combat, and a short decisive contribution", function()
		local moving = P.new()
		local throwing = P.new()
		for i = 1, 80 do
			P.sample(moving, vector.create(i * 3, 0, 0), i * 0.5, 0.5, Config)
			if i % 4 == 0 then
				P.action(throwing, i * 0.5)
			end
			P.sample(throwing, vector.zero, i * 0.5, 0.5, Config)
		end
		T.expect(P.eligible(moving, { Elims = 0, Catches = 0 }, Config)):toEqual(true)
		T.expect(P.eligible(throwing, { Elims = 0, Catches = 0 }, Config)):toEqual(true)
		T.expect(P.eligible(P.new(), { Elims = 1, Catches = 0 }, Config)):toEqual(true)
	end)
	T.it("caps same-opponent catches and total catches without consuming other players' allowance", function()
		local state = P.new()
		for i = 1, 8 do
			T.expect(P.payout(state, "Catch", "1", Config)):toEqual(true)
		end
		T.expect(P.payout(state, "Catch", "1", Config)):toEqual(false)
		for _, id in { "2", "3" } do
			for i = 1, 8 do
				T.expect(P.payout(state, "Catch", id, Config)):toEqual(true)
			end
		end
		T.expect(P.payout(state, "Catch", "4", Config)):toEqual(false)
		T.expect(P.payout(P.new(), "Catch", "1", Config)):toEqual(true)
	end)
end)
return true
