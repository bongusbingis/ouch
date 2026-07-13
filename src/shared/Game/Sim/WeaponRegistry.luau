--!strict

local WeaponKit = require(script.Parent.WeaponKit)
local Dodgeball = require(script.Parent.Weapons.Dodgeball)

-- Registration order is iteration order; keep it deterministic and explicit.
local kits: { WeaponKit.WeaponKit } = {
	Dodgeball,
}

local WeaponRegistry = {}

function WeaponRegistry.all(): { WeaponKit.WeaponKit }
	return kits
end

function WeaponRegistry.forCommand(kind: string): WeaponKit.WeaponKit?
	for _, kit in kits do
		if kit.commands[kind] then
			return kit
		end
	end
	return nil
end

return WeaponRegistry
