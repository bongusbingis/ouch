-- Name: CombatConfig.luau
-- Author: Jack C.
-- Description: Tuning values for the combat input and camera layer: thresholds, timings, touch regions, and camera behavior constants.
-- Created: 2026-08-20

--!strict

export type Scaled = {
	Fraction: number,
	MinPixels: number,
	MaxPixels: number,
}

return {
	Tap = {

		MaxDistance = { Fraction = 0.022, MinPixels = 10, MaxPixels = 26 } :: Scaled,
	},

	Camera = {
		ClaimDistance = { Fraction = 0.028, MinPixels = 12, MaxPixels = 34 } :: Scaled,

		ClaimVelocity = { Fraction = 1.4, MinPixels = 500, MaxPixels = 2600 } :: Scaled,

		ChargeSensitivityMultiplier = 0.9,
	},

	Charge = {
		HoldDelay = 0.18,

		HoldSlop = { Fraction = 0.05, MinPixels = 18, MaxPixels = 60 } :: Scaled,
	},

	BottomSwipe = {
		Enabled = true,

		RegionHeightFraction = 0.28,

		RegionMinXFraction = 0,
		RegionMaxXFraction = 1,

		DirectionSampleMinPixels = { Fraction = 0.012, MinPixels = 9, MaxPixels = 18 } :: Scaled,

		MinDistance = { Fraction = 0.09, MinPixels = 44, MaxPixels = 150 } :: Scaled,

		MaxDuration = 0.28,

		MinVelocity = { Fraction = 0.7, MinPixels = 260, MaxPixels = 1400 } :: Scaled,

		DirectionDot = 0.72,
	},

	Controller = {
		TriggerPressThreshold = 0.55,
		TriggerReleaseThreshold = 0.35,
	},

	CombatCamera = {
		Enabled = true,

		HideMouseCursor = true,
		LockMouseToCenter = true,

		ShoulderOffset = Vector3.new(1.5, 0.35, 0),

		CharacterFollowsCameraYaw = false,

		MouseSensitivityMultiplier = 1,
	},

	Debug = {
		Enabled = false,
		LogClassification = false,
	},
}
