--!strict

-- Per-device aim assist rows. SelectionCone is the sim's soft-lock cone;
-- ValidationCone is the wider server-side re-check (fail-open to unguided).
-- AcquireCone/StickyCone drive the client AimDirector: how far off camera
-- center a target can be acquired, and how far the current lock may drift
-- before it drops (hysteresis).

export type DeviceRow = {
	SelectionConeDeg: number,
	ValidationConeDeg: number,
	HomingTurnScale: number,
	MagnetismRadius: number,
	AcquireConeDeg: number,
	StickyConeDeg: number,
}

local AimAssist: { [string]: DeviceRow } = {
	Mouse = {
		SelectionConeDeg = 8,
		ValidationConeDeg = 16,
		HomingTurnScale = 0.65,
		MagnetismRadius = 0,
		AcquireConeDeg = 8,
		StickyConeDeg = 8,
	},
	Touch = {
		SelectionConeDeg = 14,
		ValidationConeDeg = 24,
		HomingTurnScale = 1.6,
		MagnetismRadius = 0.6,
		AcquireConeDeg = 60,
		StickyConeDeg = 75,
	},
	Gamepad = {
		SelectionConeDeg = 11,
		ValidationConeDeg = 20,
		HomingTurnScale = 1.1,
		MagnetismRadius = 0.3,
		AcquireConeDeg = 24,
		StickyConeDeg = 32,
	},
}

return AimAssist
