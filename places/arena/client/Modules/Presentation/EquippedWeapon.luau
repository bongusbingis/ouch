--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local SimStateCodec = require(Adapters:WaitForChild("SimStateCodec"))
local WeaponRegistry = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Sim"):WaitForChild("WeaponRegistry")
)

-- Which weapon any player currently has out, for presentation.
--
-- Reads the attribute SimStateCodec writes onto the character, which is the sim's
-- own copy rather than a projection made for the client, so it answers for remote
-- players as well as the local one. Every visual that shows a weapon asks here;
-- deciding it locally is how the hammer ended up hidden whenever a ball was held
-- long after possession stopped being what chose the weapon.

local EquippedWeapon = {}

function EquippedWeapon.forCharacter(character: Model?): string
	if character == nil then
		return WeaponRegistry.defaultKind()
	end
	local equipped = character:GetAttribute(SimStateCodec.EquippedAttribute) :: string?
	if equipped == nil or equipped == "" then
		return WeaponRegistry.defaultKind()
	end
	return equipped
end

function EquippedWeapon.of(player: Player?): string
	if player == nil then
		return WeaponRegistry.defaultKind()
	end
	return EquippedWeapon.forCharacter(player.Character)
end

function EquippedWeapon.isShowing(player: Player?, kind: string): boolean
	return EquippedWeapon.of(player) == kind
end

return EquippedWeapon
