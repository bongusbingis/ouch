-- Description: Spec for aim-assist resolution: rejection of malformed overrides, device scaling, features gated off per device, and the cohort labelling used for analytics.

--!strict

local T = require(script.Parent.TestKit)
local AssistResolver = require(script.Parent.Parent.Game.Config.AssistResolver)

local entries = {
	{ Key = "LeadEnabled", Type = "boolean", Default = true },
	{ Key = "LeadStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },
}

local scales = {
	Mouse = { Lead = 0 },
	Touch = { Lead = 1 },
	Gamepad = { Lead = 0.5 },
}

T.describe("AssistResolver", function()
	T.it("falls back to the default on a wrong type or out of range value", function()
		T.expect(AssistResolver.coerce(entries[2], "1")):toEqual(1)
		T.expect(AssistResolver.coerce(entries[2], 5)):toEqual(1)
		T.expect(AssistResolver.coerce(entries[2], -1)):toEqual(1)
		T.expect(AssistResolver.coerce(entries[2], 0 / 0)):toEqual(1)
		T.expect(AssistResolver.coerce(entries[1], 1)):toEqual(true)
	end)

	T.it("accepts a valid override", function()
		T.expect(AssistResolver.coerce(entries[2], 0.4)):toBeNear(0.4, 1e-6)
		T.expect(AssistResolver.coerce(entries[1], false)):toEqual(false)
	end)

	T.it("resolves every declared key even when config is empty", function()
		local resolved = AssistResolver.resolve(entries, {})
		T.expect(resolved.LeadEnabled):toEqual(true)
		T.expect(resolved.LeadStrength):toEqual(1)
	end)

	T.it("treats disabled, zero strength and zero device scale identically", function()
		local touch = scales.Touch
		local off = AssistResolver.resolve(entries, { LeadEnabled = false })
		local zero = AssistResolver.resolve(entries, { LeadStrength = 0 })
		T.expect(AssistResolver.strength(off, touch, "Lead")):toEqual(0)
		T.expect(AssistResolver.strength(zero, touch, "Lead")):toEqual(0)
		T.expect(AssistResolver.strength(AssistResolver.resolve(entries, {}), scales.Mouse, "Lead")):toEqual(0)
	end)

	T.it("multiplies player strength by the device scale", function()
		local resolved = AssistResolver.resolve(entries, { LeadStrength = 0.5 })
		T.expect(AssistResolver.strength(resolved, scales.Touch, "Lead")):toBeNear(0.5, 1e-6)
		T.expect(AssistResolver.strength(resolved, scales.Gamepad, "Lead")):toBeNear(0.25, 1e-6)
	end)

	T.it("never lets mouse receive an assist gated off for it", function()
		local resolved = AssistResolver.resolve(entries, { LeadEnabled = true, LeadStrength = 1 })
		T.expect(AssistResolver.strength(resolved, scales.Mouse, "Lead")):toEqual(0)
	end)

	T.it("returns zero for a feature with no device scale rather than assuming full", function()
		local resolved = AssistResolver.resolve(entries, {})
		T.expect(AssistResolver.strength(resolved, { Other = 1 }, "Lead")):toEqual(0)
	end)

	T.it("falls back to the mouse scale for an unknown device", function()
		T.expect(AssistResolver.scaleFor(scales, "Wheel").Lead):toEqual(0)
		T.expect(AssistResolver.scaleFor(scales, nil).Lead):toEqual(0)
	end)

	T.it("labels an untouched set as the default cohort", function()
		local entries = {
			{ Key = "AEnabled", Type = "boolean", Default = true },
			{ Key = "AStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },
		}
		T.expect(AssistResolver.bucket(entries, AssistResolver.resolve(entries, {}))):toEqual("Default")
	end)

	T.it("labels any changed leaf as a variant", function()
		local entries = {
			{ Key = "AEnabled", Type = "boolean", Default = true },
			{ Key = "AStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },
		}
		local resolved = AssistResolver.resolve(entries, { AStrength = 0.5 })
		T.expect(AssistResolver.bucket(entries, resolved)):toEqual("Variant")
	end)

	T.it("treats a rejected override as the default cohort, since nothing changed", function()
		local entries = {
			{ Key = "AStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },
		}
		local resolved = AssistResolver.resolve(entries, { AStrength = 99 })
		T.expect(AssistResolver.bucket(entries, resolved)):toEqual("Default")
	end)
end)

return true
