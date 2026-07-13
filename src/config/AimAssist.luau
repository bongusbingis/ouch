--!strict

-- Per-device aim assist rows. SelectionCone is the client-side soft-lock cone;
-- ValidationCone is the wider server-side re-check (fail-open to unguided).
-- Touch values are stubs until mobile tuning (M4+).

export type DeviceRow = {
	SelectionConeDeg: number,
	ValidationConeDeg: number,
	HomingTurnScale: number,
	MagnetismRadius: number,
}

local AimAssist: { [string]: DeviceRow } = {
	Mouse = {
		SelectionConeDeg = 8,
		ValidationConeDeg = 16,
		HomingTurnScale = 0.65,
		MagnetismRadius = 0,
	},
	Touch = {
		SelectionConeDeg = 14,
		ValidationConeDeg = 24,
		HomingTurnScale = 1.6,
		MagnetismRadius = 0.6,
	},
}

return AimAssist
