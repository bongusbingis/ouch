--!strict

-- Terrain feature tuning (GDD §5: bounce pads and foam pits as
-- terrain-based mobility/dodge tools). Per-pad overrides via a
-- "LaunchSpeed" attribute on the pad part.

-- VerticalPadding widens a volume upward so a root hovering just above the part
-- still counts as inside it.
return {
	BouncePad = {
		LaunchSpeed = 80, -- along the pad's UpVector
		CooldownSeconds = 0.4, -- per player per pad, prevents retrigger while overlapping
		VerticalPadding = 2,
	},
	FoamPit = {
		WalkSpeedScale = 0.45,
		VerticalPadding = 2,
	},
	ElimZone = {
		VerticalPadding = 2,
	},
	Rotating = {
		DegreesPerSecond = 1, -- per-assembly override: numeric "RotationSpeed" attribute on Origin
		-- A rider is carried while their root sits above the assembly's footprint
		-- and within CarryHeight of its top, which is what keeps them moving with
		-- it through a jump instead of the platform turning out from under them.
		CarryHeight = 16,
		CarryDepthTolerance = 2,
	},
}
