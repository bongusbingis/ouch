-- Description: Spec that overrides are written into the config tables consumers read, that the shipped value is captured once and restored exactly, and that listeners fire only on real changes.

--!strict

local T = require(script.Parent.TestKit)
local ConfigRuntime = require(script.Parent.Parent.Game.Config.ConfigRuntime)

local function freshCombat()
	return { Dodgeball = { ThrowSpeed = 200, ThrowCooldown = 0.6 } }
end

T.describe("ConfigRuntime", function()
	T.it("writes overrides into the config table every consumer reads", function()
		ConfigRuntime.clear()
		local combat = freshCombat()
		ConfigRuntime.register("Combat", combat)
		ConfigRuntime.apply({ ["Combat.Dodgeball.ThrowSpeed"] = 250 })
		T.expect(combat.Dodgeball.ThrowSpeed):toEqual(250)
		T.expect(combat.Dodgeball.ThrowCooldown):toEqual(0.6)
		ConfigRuntime.clear()
	end)

	T.it("restores the baked value when an override disappears", function()
		ConfigRuntime.clear()
		local combat = freshCombat()
		ConfigRuntime.register("Combat", combat)
		ConfigRuntime.apply({ ["Combat.Dodgeball.ThrowSpeed"] = 250 })
		ConfigRuntime.apply({})
		T.expect(combat.Dodgeball.ThrowSpeed):toEqual(200)
		T.expect(next(ConfigRuntime.activeOverrides())):toBeNil()
		ConfigRuntime.clear()
	end)

	T.it("keeps the baked value across repeated overrides so it never drifts", function()
		ConfigRuntime.clear()
		local combat = freshCombat()
		ConfigRuntime.register("Combat", combat)
		ConfigRuntime.apply({ ["Combat.Dodgeball.ThrowSpeed"] = 250 })
		ConfigRuntime.apply({ ["Combat.Dodgeball.ThrowSpeed"] = 300 })
		ConfigRuntime.apply({ ["Combat.Dodgeball.ThrowSpeed"] = 400 })
		ConfigRuntime.apply({})
		T.expect(combat.Dodgeball.ThrowSpeed):toEqual(200)
		ConfigRuntime.clear()
	end)

	T.it("rejects a missing target without applying another valid override", function()
		ConfigRuntime.clear()
		local combat = freshCombat()
		ConfigRuntime.register("Combat", combat)
		local ok, reason = ConfigRuntime.apply({
			["Missing.Thing"] = 1,
			["Combat.Dodgeball.ThrowSpeed"] = 250,
		})
		T.expect(ok):toEqual(false)
		T.expect(string.find(reason :: string, "Missing.Thing", 1, true) ~= nil):toBeTruthy()
		T.expect(combat.Dodgeball.ThrowSpeed):toEqual(200)
		T.expect(next(ConfigRuntime.activeOverrides())):toBeNil()
		T.expect((combat.Dodgeball :: any).Unknown):toBeNil()
		ConfigRuntime.clear()
	end)

	T.it("reports the unmapped matchmaking target instead of choosing a queue", function()
		ConfigRuntime.clear()
		local matchmaking = { PartyMaxPlayers = 4 }
		ConfigRuntime.register("Matchmaking", matchmaking)
		local ok, reason = ConfigRuntime.apply({ ["Matchmaking.MatchTargetPlayers"] = 8 })
		T.expect(ok):toEqual(false)
		T.expect(string.find(reason :: string, "Matchmaking.MatchTargetPlayers", 1, true) ~= nil):toBeTruthy()
		T.expect(matchmaking.PartyMaxPlayers):toEqual(4)
		ConfigRuntime.clear()
	end)

	T.it("preflights restoration and retains prior values on a frozen target", function()
		ConfigRuntime.clear()
		local combat = freshCombat()
		ConfigRuntime.register("Combat", combat)
		ConfigRuntime.apply({ ["Combat.Dodgeball.ThrowSpeed"] = 250 })
		table.freeze(combat.Dodgeball)
		local ok, reason = ConfigRuntime.apply({ ["Combat.Dodgeball.ThrowCooldown"] = 0.2 })
		T.expect(ok):toEqual(false)
		T.expect(string.find(reason :: string, "frozen target", 1, true) ~= nil):toBeTruthy()
		T.expect(combat.Dodgeball.ThrowSpeed):toEqual(250)
		T.expect(combat.Dodgeball.ThrowCooldown):toEqual(0.6)
		T.expect(ConfigRuntime.activeOverrides()["Combat.Dodgeball.ThrowSpeed"]):toEqual(250)
		combat.Dodgeball = { ThrowSpeed = combat.Dodgeball.ThrowSpeed, ThrowCooldown = 0.6 }
		ConfigRuntime.clear()
	end)

	T.it("notifies listeners only about leaves that actually changed", function()
		ConfigRuntime.clear()
		local combat = freshCombat()
		ConfigRuntime.register("Combat", combat)
		local notifications = 0
		ConfigRuntime.subscribe(function()
			notifications += 1
		end)
		ConfigRuntime.apply({ ["Combat.Dodgeball.ThrowSpeed"] = 250 })
		ConfigRuntime.apply({ ["Combat.Dodgeball.ThrowSpeed"] = 250 })
		T.expect(notifications):toEqual(1)
		ConfigRuntime.clear()
	end)

	T.it("restores every baked value when cleared", function()
		ConfigRuntime.clear()
		local combat = freshCombat()
		ConfigRuntime.register("Combat", combat)
		ConfigRuntime.apply({
			["Combat.Dodgeball.ThrowSpeed"] = 250,
			["Combat.Dodgeball.ThrowCooldown"] = 0.2,
		})
		ConfigRuntime.clear()
		T.expect(combat.Dodgeball.ThrowSpeed):toEqual(200)
		T.expect(combat.Dodgeball.ThrowCooldown):toEqual(0.6)
	end)
end)

return true
