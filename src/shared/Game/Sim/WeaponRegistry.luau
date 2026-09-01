-- Name: WeaponRegistry.luau
-- Author: Jack C.
-- Description: Lists every weapon kit, resolves which kit a command routes to, and names the default and the kit auto-equipped on picking up a ball.
-- Created: 2026-07-12

--!strict

local WeaponKit = require(script.Parent.WeaponKit)
local Dodgeball = require(script.Parent.Weapons.Dodgeball)
local Hammer = require(script.Parent.Weapons.Hammer)

local kits: { WeaponKit.WeaponKit } = {
	Dodgeball,
	Hammer,
}

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
