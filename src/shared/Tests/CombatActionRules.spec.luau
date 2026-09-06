-- Invalid character/round state never becomes a deferred attack after respawn or menu dismissal.
--!strict

local T = require(script.Parent.TestKit)
local Rules = require(script.Parent.Parent.Game.Input.CombatActionRules)

local function ready()
	return {
		enabled = true,
		active = true,
		alive = true,
		eligible = true,
		weapon = "Hammer",
		holdsBall = true,
		throwCooldown = 0,
		hammerCooldown = 0,
		catchCooldown = 0,
	}
end

T.describe("Combat action eligibility", function()
	T.it("allows a hammer swing while carrying a ball but never a catch", function()
		T.expect(Rules.status("Throw", ready())):toEqual("Ready")
		T.expect(Rules.status("Catch", ready())):toEqual("Unavailable")
	end)
	T.it("buffers cooldowns without buffering invalid player or round state", function()
		local state = ready()
		state.hammerCooldown = 0.1
		T.expect(Rules.status("Throw", state)):toEqual("Cooldown")
		for _, field in { "enabled", "active", "alive", "eligible" } do
			local invalid: any = table.clone(state)
			invalid[field] = false
			T.expect(Rules.status("Throw", invalid)):toEqual("Unavailable")
		end
	end)
	T.it("requires ammunition for a dodgeball throw", function()
		local state = ready()
		state.weapon = "Dodgeball"
		state.holdsBall = false
		T.expect(Rules.status("Throw", state)):toEqual("Unavailable")
		T.expect(Rules.status("Catch", state)):toEqual("Ready")
	end)
end)

return true
