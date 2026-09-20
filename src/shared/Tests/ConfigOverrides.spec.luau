-- Description: Spec for live config override validation: key parsing, type and range rejection, allowlist enforcement, sim-critical partitioning, and safe writes into existing leaves.

--!strict

local T = require(script.Parent.TestKit)
local ConfigOverrides = require(script.Parent.Parent.Game.Config.ConfigOverrides)
local LiveConfig = require(script.Parent.Parent.Parent.Config.LiveConfig)

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

	T.it("validates a complete revision before returning any overrides", function()
		local revision, accepted = ConfigOverrides.validateSnapshot(entries, {
			revision = 0,
			overrides = {},
		}, -1)
		T.expect(revision):toEqual(0)
		T.expect(next(accepted :: { [string]: any })):toBeNil()

		local invalidRevision, invalidOverrides, reason = ConfigOverrides.validateSnapshot(entries, {
			revision = 1,
			overrides = {
				["Combat.Dodgeball.ThrowSpeed"] = 250,
				["GameModes.VoteDurationSeconds"] = 900,
			},
		}, 0)
		T.expect(invalidRevision):toBeNil()
		T.expect(invalidOverrides):toBeNil()
		T.expect(string.find(reason :: string, "GameModes.VoteDurationSeconds", 1, true) ~= nil):toBeTruthy()
	end)

	T.it("rejects stale revisions, unknown keys, and malformed projection shape", function()
		local stale = ConfigOverrides.validateSnapshot(entries, { revision = 2, overrides = {} }, 2)
		T.expect(stale):toBeNil()
		local unknown = ConfigOverrides.validateSnapshot(entries, {
			revision = 3,
			overrides = { ["Combat.Dodgeball.Unlisted"] = 1 },
		}, 2)
		T.expect(unknown):toBeNil()
		local malformed = ConfigOverrides.validateSnapshot(entries, { revision = 4, overrides = "bad" }, 2)
		T.expect(malformed):toBeNil()
	end)

	T.it("rejects fractions in all eight match reward overrides but permits other decimals", function()
		local checked = 0
		for _, entry in LiveConfig.Entries do
			if
				string.match(entry.Key, "^Progression%.ProgressionXP%.")
				or string.match(entry.Key, "^Progression%.ProgressionBonks%.")
			then
				checked += 1
				local value, reason = ConfigOverrides.validate(entry, 1.5)
				T.expect(value):toBeNil()
				T.expect(reason):toEqual("expected integer")
				T.expect(ConfigOverrides.validate(entry, 2)):toEqual(2)
			end
		end
		T.expect(checked):toEqual(8)
		for _, entry in LiveConfig.Entries do
			if entry.Key == "Combat.Dodgeball.ThrowCooldown" then
				T.expect(ConfigOverrides.validate(entry, 0.5)):toEqual(0.5)
				return
			end
		end
		error("missing decimal-capable cooldown entry")
	end)

	T.it("rejects a mixed valid and fractional reward revision as one value", function()
		local revision, accepted, reason = ConfigOverrides.validateSnapshot(LiveConfig.Entries, {
			revision = 2,
			overrides = {
				["Combat.Dodgeball.ThrowCooldown"] = 0.5,
				["Progression.ProgressionXP.Win"] = 1.5,
			},
		}, 1)
		T.expect(revision):toBeNil()
		T.expect(accepted):toBeNil()
		T.expect(string.find(reason :: string, "Progression.ProgressionXP.Win", 1, true) ~= nil):toBeTruthy()
	end)
end)

return true
