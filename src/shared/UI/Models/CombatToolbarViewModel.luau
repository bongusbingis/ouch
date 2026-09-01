--!strict

local Config = script.Parent.Parent.Parent.Parent.Config

local Combat = require(Config.Combat)
local Input = require(Config.Input)

local CombatToolbarViewModel = {}

export type Snapshot = {
	active: boolean,
	weapon: string,
	holdsBall: boolean,
	throwCooldown: number,
	hammerCooldown: number,
	weaponLocked: boolean,
	throwState: string,
	chargeAlpha: number,
}

export type ActionState =
	{ kind: "Ready" }
	| { kind: "Locked" }
	| { kind: "Unavailable", reason: "NoBall" }
	| { kind: "Cooldown", progress: number }
	| { kind: "Charging", progress: number }
	| { kind: "Disabled" }

export type Slot = {
	weapon: string,
	title: string,
	selected: boolean,
	interactive: boolean,
	inputLabel: string?,
	inputKeyCode: Enum.KeyCode?,
	state: ActionState,
}

export type Model = {
	visible: boolean,
	deviceClass: string,
	slots: { Slot },
}

export type Layout = {
	width: number,
	height: number,
	bottomGap: number,
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
		return definition.GamepadLabel, definition.Gamepad
	end
	return definition.KeyboardLabel, definition.Keyboard
end

local function cooldownRemaining(snapshot: Snapshot, weapon: string): number
	if weapon == "Dodgeball" then
		return math.clamp(snapshot.throwCooldown / math.max(Combat.Dodgeball.ThrowCooldown, 1e-3), 0, 1)
	end
	return math.clamp(snapshot.hammerCooldown / math.max(Combat.Hammer.Cooldown, 1e-3), 0, 1)
end

local function actionState(snapshot: Snapshot, weapon: string, selected: boolean): ActionState
	if not snapshot.active then
		return { kind = "Disabled" }
	end
	if snapshot.weaponLocked and not selected then
		return { kind = "Locked" }
	end
	if weapon == "Dodgeball" and not snapshot.holdsBall then
		return { kind = "Unavailable", reason = "NoBall" }
	end
	if
		weapon == "Dodgeball"
		and selected
		and (snapshot.throwState == "Charging" or snapshot.throwState == "FullCharge")
	then
		return { kind = "Charging", progress = math.clamp(snapshot.chargeAlpha, 0, 1) }
	end
	local remaining = cooldownRemaining(snapshot, weapon)
	if remaining > 0 then
		return { kind = "Cooldown", progress = 1 - remaining }
	end
	return { kind = "Ready" }
end

function CombatToolbarViewModel.fromSnapshot(snapshot: Snapshot, deviceClass: string): Model
	local slots = {}
	for _, weapon in ORDER do
		local selected = snapshot.weapon == weapon
		local state = actionState(snapshot, weapon, selected)
		local inputLabel, inputKeyCode = binding(deviceClass, weapon)
		table.insert(slots, {
			weapon = weapon,
			title = string.upper(weapon),
			selected = selected,
			interactive = snapshot.active
				and deviceClass == "Touch"
				and not selected
				and (state.kind == "Ready" or state.kind == "Cooldown"),
			inputLabel = inputLabel,
			inputKeyCode = inputKeyCode,
			state = state,
		})
	end
	return {
		visible = snapshot.active,
		deviceClass = deviceClass,
		slots = slots,
	}
end

function CombatToolbarViewModel.layout(viewport: Vector2, deviceClass: string): Layout
	local touch = deviceClass == "Touch"
	local portrait = viewport.Y > viewport.X
	local widthFraction = if portrait then (if touch then 0.68 else 0.58) else if touch then 0.34 else 0.27
	local minimum = 260
	local maximum = if touch then 350 else 332
	local width = math.clamp(viewport.X * widthFraction, minimum, maximum)
	local aspect = if touch then 3 else 3.15
	return {
		width = width,
		height = width / aspect,
		bottomGap = math.clamp(viewport.Y * (if touch then 0.02 else 0.016), 14, 22),
	}
end

return CombatToolbarViewModel
