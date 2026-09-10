--!strict

-- Radial emote selector geometry and timing. Numbers only, so the pure wheel
-- model can load in the headless test runner. Angles start at twelve o'clock,
-- cardinal-first (top, bottom, right, left, then diagonals) so slots keep their
-- place when the wheel grows; the hollow centre is the cancel dead zone.
return {
	DiameterScale = 0.54,
	MinDiameterPx = 260,
	MaxDiameterPx = 460,
	EdgeMarginPx = 20,
	CaptionReservePx = 96,
	ShortViewportMaxPx = 500,
	DeadZoneFraction = 0.26,
	HoleFraction = 0.6,
	RingSegments = 64,
	NameTextPx = 34,
	SectorGapDegrees = 3,
	IconFraction = 0.25,
	RingInsetPx = 6,
	LabelTextPx = 18,
	CenterLabelTextPx = 22,
	OpenSeconds = 0.12,
	CloseSeconds = 0.1,
	OpenScaleFrom = 0.86,
	SelectedScale = 1.08,
	StickDeadZone = 0.35,
	TouchButtonPx = 56,
	TouchButtonBottomPx = 96,
}
