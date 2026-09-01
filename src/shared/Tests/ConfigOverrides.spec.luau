-- Name: ConfigOverrides.spec.luau
-- Author: Jack C.
-- Description: Spec for live config override validation: key parsing, type and range rejection, allowlist enforcement, sim-critical partitioning, and safe writes into existing leaves.
-- Created: 2026-08-18

--!strict

local T = require(script.Parent.TestKit)
local ConfigOverrides = require(script.Parent.Parent.Game.Config.ConfigOverrides)

local entries = {
	{ Key = "Combat.Dodgeball.ThrowSpeed", Type = "number", Minimum = 10, Maximum = 1000 },
	{ Key = "GameModes.VoteDurationSeconds", Type = "number", Minimum = 3, Maximum = 60 },
	{ Key = "Debug.Enabled", Type = "boolean" },
}

T.describe("ConfigOverrides", function()
	T.it("splits a key into its module and leaf path", function()
		local moduleName, path = ConfigOverrides.parseKey("Combat.Dodgeball.ThrowSpeed")
		T.expect(moduleName):toEqual("Combat")
		T.expect(table.concat(path :: { string }, "/")):toEqual("Dodgeball/ThrowSpeed")
		T.expect((ConfigOverrides.parseKey("Combat"))):toBeNil()
		T.expect((ConfigOverrides.parseKey("Combat..ThrowSpeed"))):toBeNil()
	end)

	T.it("rejects wrong types, non-finite numbers, and out-of-range values", function()
		local entry = entries[1]
		T.expect((ConfigOverrides.validate(entry, "200"))):toBeNil()
		T.expect((ConfigOverrides.validate(entry, 0 / 0))):toBeNil()
		T.expect((ConfigOverrides.validate(entry, math.huge))):toBeNil()
		T.expect((ConfigOverrides.validate(entry, 9))):toBeNil()
		T.expect((ConfigOverrides.validate(entry, 1001))):toBeNil()
		T.expect(ConfigOverrides.validate(entry, 250)):toEqual(250)
		T.expect(ConfigOverrides.validate(entries[3], false)):toEqual(false)
	end)

	T.it("accepts only declared keys and reports why the rest were dropped", function()
		local accepted, rejected = ConfigOverrides.resolve(entries, {
			["Combat.Dodgeball.ThrowSpeed"] = 250,
			["GameModes.VoteDurationSeconds"] = 900,
			["Combat.Dodgeball.Unlisted"] = 5,
		})
		T.expect(accepted["Combat.Dodgeball.ThrowSpeed"]):toEqual(250)
		T.expect(accepted["GameModes.VoteDurationSeconds"]):toBeNil()
		T.expect(accepted["Combat.Dodgeball.Unlisted"]):toBeNil()
		T.expect(#rejected):toEqual(1)
		T.expect(rejected[1].Key):toEqual("GameModes.VoteDurationSeconds")
	end)

	T.it("holds sim-critical modules back and lets the rest through", function()
		local immediate, staged = ConfigOverrides.partition({
			["Combat.Dodgeball.ThrowSpeed"] = 250,
			["GameModes.VoteDurationSeconds"] = 12,
		}, { Combat = true })
		T.expect(staged["Combat.Dodgeball.ThrowSpeed"]):toEqual(250)
		T.expect(immediate["GameModes.VoteDurationSeconds"]):toEqual(12)
		T.expect(immediate["Combat.Dodgeball.ThrowSpeed"]):toBeNil()
	end)

	T.it("projects keys onto dot-free attribute names", function()
		T.expect(ConfigOverrides.projectedName("Combat.Dodgeball.ThrowSpeed")):toEqual("Combat_Dodgeball_ThrowSpeed")
		T.expect(ConfigOverrides.projectedName("GameModes.VoteDurationSeconds"))
			:toEqual("GameModes_VoteDurationSeconds")
	end)

	T.it("writes only over leaves that already exist and never into frozen tables", function()
		local root = { Dodgeball = { ThrowSpeed = 200 }, Frozen = table.freeze({ Value = 1 }) }
		T.expect(ConfigOverrides.writePath(root, { "Dodgeball", "ThrowSpeed" }, 250)):toBeTruthy()
		T.expect(root.Dodgeball.ThrowSpeed):toEqual(250)
		T.expect(not ConfigOverrides.writePath(root, { "Dodgeball", "Missing" }, 1)):toBeTruthy()
		T.expect(not ConfigOverrides.writePath(root, { "Frozen", "Value" }, 2)):toBeTruthy()
		T.expect(not ConfigOverrides.writePath(root, { "Absent", "Value" }, 2)):toBeTruthy()
		T.expect(ConfigOverrides.readPath(root, { "Dodgeball", "ThrowSpeed" })):toEqual(250)
		T.expect(ConfigOverrides.readPath(root, { "Nope", "ThrowSpeed" })):toBeNil()
	end)
end)

return true
