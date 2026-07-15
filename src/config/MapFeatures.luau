--!strict

-- Terrain feature tuning (GDD §5: bounce pads and foam pits as
-- terrain-based mobility/dodge tools). Per-pad overrides via a
-- "LaunchSpeed" attribute on the pad part.

return {
	BouncePad = {
		LaunchSpeed = 80, -- along the pad's UpVector
		CooldownSeconds = 0.4, -- per player per pad, prevents retrigger while overlapping
	},
	FoamPit = {
		WalkSpeedScale = 0.45,
	},
}
