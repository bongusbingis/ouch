-- Name: CombatToolbarViewModel.luau
-- Description: Derives the combat toolbar slots from the authoritative combat snapshot and current weapon registry.

--!strict

local WeaponRegistry = require(script.Parent.Parent.Parent.Game.Sim.WeaponRegistry)

local CombatToolbarViewModel = {}

export type Snapshot = {
	weapon: string,
	holdsBall: boolean,
	ready: boolean,
	throwCooldown: number,
}

export type Slot = {
	weapon: string,
	available: boolean,
	equipped: boolean,
	inputLabel: string?,
	readiness: number?,
}

export type Model = {
	visible: boolean,
	interactive: boolean,
	slots: { Slot },
}

local function inputLabel(deviceClass: string, weapon: string): string?
	if deviceClass == "Touch" then
		return nil
	end
	if deviceClass == "Gamepad" then
		return if weapon == "Hammer" then "L1" else "R1"
	end
	return if weapon == "Hammer" then "1" else "2"
end

local function isAvailable(snapshot: Snapshot, weapon: string): boolean
	if weapon == "Dodgeball" then
		return snapshot.holdsBall
	end
	return WeaponRegistry.isKind(weapon)
end

function CombatToolbarViewModel.fromSnapshot(snapshot: Snapshot, deviceClass: string): Model
	local slots = {}
	for _, kit in WeaponRegistry.all() do
		local available = isAvailable(snapshot, kit.kind)
		if available then
			table.insert(slots, {
				weapon = kit.kind,
				available = true,
				equipped = snapshot.weapon == kit.kind,
				inputLabel = inputLabel(deviceClass, kit.kind),
				readiness = if kit.kind == "Dodgeball" then math.clamp(1 - snapshot.throwCooldown / 1.5, 0, 1) else nil,
			})
		end
	end
	return {
		visible = #slots > 0,
		interactive = deviceClass == "Touch",
		slots = slots,
	}
end

return CombatToolbarViewModel
