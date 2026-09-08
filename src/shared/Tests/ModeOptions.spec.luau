-- Description: Spec for ballot option canonicalization: filtering unavailable and duplicate options, falling back after complete version skew, and comparing canonical sequences.

--!strict

local T = require(script.Parent.TestKit)
local ModeOptions = require(script.Parent.Parent.Game.Modes.ModeOptions)

T.describe("ModeOptions", function()
	T.it("filters unavailable and duplicate options without changing valid order", function()
		local resolved = ModeOptions.resolve({ "TDM", "Infection", "TDM", "REMOVED", "FFA" })
		T.expect(table.concat(resolved, ",")):toEqual("TDM,FFA")
	end)

	T.it("falls back to the current vote options after complete version skew", function()
		local resolved = ModeOptions.resolve({ "REMOVED" })
		T.expect(table.concat(resolved, ",")):toEqual("FFA,TDM")
	end)

	T.it("compares canonical option sequences", function()
		T.expect(ModeOptions.equals({ "FFA", "TDM" }, { "FFA", "TDM" })):toBeTruthy()
		T.expect(not ModeOptions.equals({ "FFA", "TDM" }, { "TDM", "FFA" })):toBeTruthy()
	end)
end)

return true
