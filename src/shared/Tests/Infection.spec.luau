-- Description: Spec for the infection mode rules: survivor counting, conversion only on an infected elimination, patient zero selection, and the survivors winning on the clock.

--!strict

local T = require(script.Parent.TestKit)
local Infection = require(script.Parent.Parent.Game.Modes.Infection)

T.describe("Infection", function()
	T.it("counts only players still on the survivor side", function()
		T.expect(Infection.countSurvivors({ "Survivors", "Survivors", "Infected" })):toEqual(2)
		T.expect(Infection.countSurvivors({ "Infected", "Infected" })):toEqual(0)
		T.expect(Infection.countSurvivors({ nil, "Infected" })):toEqual(0)
		T.expect(Infection.countSurvivors({})):toEqual(0)
	end)

	T.it("converts only when an infected eliminates a survivor", function()
		T.expect(Infection.isConversion("Infected", "Survivors")):toBeTruthy()
		T.expect(not Infection.isConversion("Survivors", "Infected")):toBeTruthy()
		T.expect(not Infection.isConversion("Infected", "Infected")):toBeTruthy()
		T.expect(not Infection.isConversion("Survivors", "Survivors")):toBeTruthy()
		T.expect(not Infection.isConversion(nil, "Survivors")):toBeTruthy()
	end)

	T.it("picks one patient zero inside the roster", function()
		local index = Infection.pickPatientZero(5, function()
			return 3
		end)
		T.expect(index):toEqual(3)
	end)

	T.it("has no patient zero below the minimum player count", function()
		T.expect(Infection.pickPatientZero(1, function()
			return 1
		end)):toBeNil()
		T.expect(Infection.pickPatientZero(0, function()
			return 1
		end)):toBeNil()
	end)

	T.it("hands the clock to the survivors and never ends on score", function()
		T.expect(Infection.rules.TimeCapWinnerId):toEqual("Survivors")
		T.expect(Infection.rules.ScoreTarget > 1e9):toBeTruthy()
		T.expect(Infection.rules.MinPlayers >= 2):toBeTruthy()
	end)
end)

return true
