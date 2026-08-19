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

	T.it("ignores keys whose module or leaf is not present", function()
		ConfigRuntime.clear()
		local combat = freshCombat()
		ConfigRuntime.register("Combat", combat)
		local changed = ConfigRuntime.apply({
			["Missing.Thing"] = 1,
			["Combat.Dodgeball.Unknown"] = 2,
			["Combat.Dodgeball.ThrowSpeed"] = 250,
		})
		T.expect(changed["Combat.Dodgeball.ThrowSpeed"]):toEqual(250)
		T.expect(changed["Missing.Thing"]):toBeNil()
		T.expect(changed["Combat.Dodgeball.Unknown"]):toBeNil()
		T.expect((combat.Dodgeball :: any).Unknown):toBeNil()
		ConfigRuntime.clear()
	end)

	T.it("notifies listeners only about leaves that actually changed", function()
		ConfigRuntime.clear()
		local combat = freshCombat()
		ConfigRuntime.register("Combat", combat)
		local notifications = 0
		ConfigRuntime.onChanged(function()
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
