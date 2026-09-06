--!strict

local T = require(script.Parent.TestKit)
local Policy = require(script.Parent.Parent.Game.Modes.ModeAvailability)
local Registry = require(script.Parent.Parent.Game.Modes.ModeRegistry)

T.describe("ModeAvailability", function()
	T.it("requires opponents in production while preserving explicit solo practice", function()
		local solo = { { id = "1" } }
		for _, modeId in { "FFA", "TDM" } do
			local rules = assert(Registry.get(modeId)).resolveRules()
			T.expect(Policy.canStart(rules, solo, false)):toEqual(false)
			T.expect(Policy.canStart(rules, solo, true)):toEqual(true)
			T.expect(Policy.canStart(rules, {}, true)):toEqual(false)
		end
	end)
	T.it("keeps a single party out of team voting without blocking free-for-all", function()
		local party = { { id = "1", partyId = "friends" }, { id = "2", partyId = "friends" } }
		T.expect(Policy.canStart(assert(Registry.get("FFA")).resolveRules(), party, false)):toEqual(true)
		T.expect(Policy.canStart(assert(Registry.get("TDM")).resolveRules(), party, false)):toEqual(false)
		table.insert(party, { id = "3", partyId = "opponents" })
		T.expect(Policy.canStart(assert(Registry.get("TDM")).resolveRules(), party, false)):toEqual(true)
	end)
	T.it("counts direct entrants independently and avoids party/player key collisions", function()
		local players = { { id = "1", partyId = "2" }, { id = "2" } }
		T.expect(Policy.canStart(assert(Registry.get("TDM")).resolveRules(), players, false)):toEqual(true)
	end)
	T.it("requires actual opposing teams after departures, not just two surviving parties", function()
		local rules = assert(Registry.get("TDM")).resolveRules()
		T.expect(Policy.canContinue(rules, { { teamId = "Red" }, { teamId = "Red" } })):toEqual(false)
		T.expect(Policy.canContinue(rules, { { teamId = "Red" }, { teamId = "Blue" } })):toEqual(true)
		T.expect(Policy.canContinue(rules, { { teamId = "Red" } })):toEqual(false)
	end)
end)

return true
