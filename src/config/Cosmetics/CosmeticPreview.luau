--!strict

-- Local effect audition framing and replay limits. The authored camera marker
-- supplies the composition; this origin keeps the stage clear of live play.

return {
	WorldOrigin = CFrame.new(0, 10000, 0),
	FieldOfView = 55,
	ReplayCooldownSeconds = 1,
	SoundLifetimeSeconds = 8,
}
