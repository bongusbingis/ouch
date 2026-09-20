-- Description: Whole-candidate assist validation, declared defaults, cohorts, and device scaling.
--!strict

local T = require(script.Parent.TestKit)
local AssistResolver = require(script.Parent.Parent.Game.Config.AssistResolver)

local entries = {
	{ Key = "LeadEnabled", Type = "boolean", Default = true },
	{ Key = "LeadStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },
}
local scales = { Mouse = { Lead = 0 }, Touch = { Lead = 1 }, Gamepad = { Lead = 0.5 } }

local function resolved(raw: { [string]: any }): { [string]: any }
	local ok, reason, value = AssistResolver.resolve(entries, raw)
	assert(ok and value ~= nil, reason)
	return value
end

T.describe("AssistResolver", function()
	T.it("uses declared defaults only for absent keys", function()
		local value = resolved({})
		T.expect(value.LeadEnabled):toEqual(true)
		T.expect(value.LeadStrength):toEqual(1)
		T.expect(AssistResolver.bucket(entries, value)):toEqual("Default")
	end)

	T.it("accepts valid boundary values and labels a variant", function()
		local low = resolved({ LeadEnabled = false, LeadStrength = 0 })
		local high = resolved({ LeadStrength = 1 })
		T.expect(low.LeadStrength):toEqual(0)
		T.expect(high.LeadStrength):toEqual(1)
		T.expect(AssistResolver.bucket(entries, low)):toEqual("Variant")
	end)

	T.it("rejects malformed present siblings as a whole candidate", function()
		for _, invalid in { "fast", -0.1, 1.1, 0 / 0, math.huge, -math.huge } do
			local ok, reason, value = AssistResolver.resolve(entries, { LeadEnabled = false, LeadStrength = invalid })
			T.expect(ok):toEqual(false)
			T.expect(value):toEqual(nil)
			T.expect(string.find(reason or "", "LeadStrength", 1, true) ~= nil):toEqual(true)
		end
		local ok, reason = AssistResolver.resolve(entries, { LeadEnabled = 1 })
		T.expect(ok):toEqual(false)
		T.expect(string.find(reason or "", "LeadEnabled", 1, true) ~= nil):toEqual(true)
	end)

	T.it("preserves device strengths and disabled behavior", function()
		local value = resolved({ LeadStrength = 0.5 })
		T.expect(AssistResolver.strength(value, scales.Mouse, "Lead")):toEqual(0)
		T.expect(AssistResolver.strength(value, scales.Touch, "Lead")):toBeNear(0.5, 1e-6)
		T.expect(AssistResolver.strength(value, scales.Gamepad, "Lead")):toBeNear(0.25, 1e-6)
		T.expect(AssistResolver.strength(resolved({ LeadEnabled = false }), scales.Touch, "Lead")):toEqual(0)
		T.expect(AssistResolver.strength(value, { Other = 1 }, "Lead")):toEqual(0)
		T.expect(AssistResolver.scaleFor(scales, "Wheel").Lead):toEqual(0)
	end)
end)

return true
