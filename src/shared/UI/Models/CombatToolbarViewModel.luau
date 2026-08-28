--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Input = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))

local CombatToolbarViewModel = {}

export type Snapshot = {
	active: boolean,
	weapon: string,
	holdsBall: boolean,
	throwCooldown: number,
	hammerCooldown: number,
	weaponLocked: boolean,
}

export type Slot = {
	weapon: string,
	title: string,
	available: boolean,
	equipped: boolean,
	interactive: boolean,
	inputLabel: string?,
	inputKeyCode: Enum.KeyCode?,
	cooldownAlpha: number,
	statusText: string,
}

export type Model = {
	visible: boolean,
	deviceClass: string,
	slots: { Slot },
}

local ORDER = { "Dodgeball", "Hammer" }

local function binding(deviceClass: string, weapon: string): (string?, Enum.KeyCode?)
	if deviceClass == "Touch" then
		return nil, nil
	end
	local definition = Input.WeaponEquip[weapon]
	if definition == nil then
		return nil, nil
	end
	if deviceClass == "Gamepad" then
		return if weapon == "Hammer" then "L1" else "R1", definition.Gamepad
	end
	return if weapon == "Hammer" then "1" else "2", definition.Keyboard
end

local function cooldown(snapshot: Snapshot, weapon: string): number
	if weapon == "Dodgeball" then
		return math.clamp(snapshot.throwCooldown / math.max(Combat.Dodgeball.ThrowCooldown, 1e-3), 0, 1)
	end
	return math.clamp(snapshot.hammerCooldown / math.max(Combat.Hammer.Cooldown, 1e-3), 0, 1)
end

function CombatToolbarViewModel.fromSnapshot(snapshot: Snapshot, deviceClass: string): Model
	local slots = {}
	for _, weapon in ORDER do
		local available = weapon ~= "Dodgeball" or snapshot.holdsBall
		local cooldownAlpha = cooldown(snapshot, weapon)
		local inputLabel, inputKeyCode = binding(deviceClass, weapon)
		local statusText = if snapshot.weaponLocked and snapshot.weapon ~= weapon
			then "LOCKED"
			else if not available
				then "NO BALL"
				else if cooldownAlpha > 0 then "WAIT" else if weapon == "Hammer" then "MELEE" else "READY"
		table.insert(slots, {
			weapon = weapon,
			title = string.upper(weapon),
			available = available,
			equipped = snapshot.weapon == weapon,
			interactive = snapshot.active
				and deviceClass == "Touch"
				and available
				and not snapshot.weaponLocked
				and snapshot.weapon ~= weapon,
			inputLabel = inputLabel,
			inputKeyCode = inputKeyCode,
			cooldownAlpha = cooldownAlpha,
			statusText = statusText,
		})
	end
	return {
		visible = snapshot.active,
		deviceClass = deviceClass,
		slots = slots,
	}
end

return CombatToolbarViewModel
