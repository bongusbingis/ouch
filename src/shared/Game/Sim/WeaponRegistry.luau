--!strict

local WeaponKit = require(script.Parent.WeaponKit)
local Dodgeball = require(script.Parent.Weapons.Dodgeball)
local Hammer = require(script.Parent.Weapons.Hammer)

-- Registration order is iteration order; keep it deterministic and explicit.
local kits: { WeaponKit.WeaponKit } = {
	Dodgeball,
	Hammer,
}

-- What a player has out before they choose. The hammer, because it is the only
-- weapon that works with nothing in hand: defaulting to the dodgeball would give
-- every player a slot that does nothing until they find a ball.
local DEFAULT_KIND = "Hammer"

local WeaponRegistry = {}

function WeaponRegistry.all(): { WeaponKit.WeaponKit }
	return kits
end

function WeaponRegistry.defaultKind(): string
	return DEFAULT_KIND
end

function WeaponRegistry.isKind(kind: string): boolean
	for _, kit in kits do
		if kit.kind == kind then
			return true
		end
	end
	return false
end

-- The kit a ball in hand belongs to, or nil if no kit claims one.
function WeaponRegistry.handBallKind(): string?
	for _, kit in kits do
		if kit.equipOnHandBall then
			return kit.kind
		end
	end
	return nil
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
