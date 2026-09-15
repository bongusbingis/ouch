-- Description: Reads which weapon a character currently has equipped from the replicated sim attribute, the single source consulted by the HUD and animation layer.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local SimStateCodec = require(Adapters:WaitForChild("SimStateCodec"))
local WeaponRegistry = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Sim"):WaitForChild("WeaponRegistry")
)
local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))

local EquippedWeapon = {}

-- A non-combat mode (Splashdown) still has a sim-equipped weapon on every
-- character; nothing is allowed to show it.
local function combatMode(): boolean
	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	return matchState == nil or GameModes.IsCombat(matchState:GetAttribute("modeId"))
end

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
	return combatMode() and EquippedWeapon.of(player) == kind
end

return EquippedWeapon
