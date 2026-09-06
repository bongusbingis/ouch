-- Command ordering must produce the same result for every arrival permutation.
--!strict

local T = require(script.Parent.TestKit)
local CommandOrder = require(script.Parent.Parent.Game.Sim.CommandOrder)

T.describe("CommandOrder", function()
	T.it("orders conflicting same-player commands independently of arrival", function()
		local commands = {
			{ playerId = "1", kind = "Equip", weapon = "Hammer" },
			{ playerId = "1", kind = "Equip", weapon = "Dodgeball" },
			{ playerId = "1", kind = "Throw", aimDir = vector.create(1, 0, 0), charge = 1 },
			{ playerId = "1", kind = "Throw", aimDir = vector.create(0, 1, 0), charge = 0 },
			{ playerId = "1", kind = "Throw", aimDir = vector.create(0, 0, 1), charge = 0 },
			{ playerId = "1", kind = "Throw", assist = { Lead = 0.5, ConeSnap = 0.2 } },
			{ playerId = "1", kind = "Throw", assist = { ConeSnap = 0.5, Lead = 0.2 } },
		}
		local expected = table.clone(commands)
		table.sort(expected, CommandOrder.less)
		for shift = 1, #commands do
			local reordered = {}
			for index = #commands, 1, -1 do
				table.insert(reordered, commands[(index + shift - 1) % #commands + 1])
			end
			table.sort(reordered, CommandOrder.less)
			for index, command in reordered do
				T.expect(command == expected[index]):toBeTruthy()
				T.expect(CommandOrder.less(command, command)):toEqual(false)
			end
		end
	end)
end)

return true
