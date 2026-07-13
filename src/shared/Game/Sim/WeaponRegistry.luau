--!strict

local WeaponKit = require(script.Parent.WeaponKit)
local Dodgeball = require(script.Parent.Weapons.Dodgeball)
local Hammer = require(script.Parent.Weapons.Hammer)

-- Registration order is iteration order; keep it deterministic and explicit.
local kits: { WeaponKit.WeaponKit } = {
	Dodgeball,
	Hammer,
}

local WeaponRegistry = {}

function WeaponRegistry.all(): { WeaponKit.WeaponKit }
	return kits
end

function WeaponRegistry.forCommand(kind: string): { WeaponKit.WeaponKit }
	local matching = {}
	for _, kit in kits do
		if kit.commands[kind] then
			table.insert(matching, kit)
		end
	end
	return matching
end

return WeaponRegistry
