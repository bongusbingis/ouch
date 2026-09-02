--!strict

return {
	Text = {
		DefaultFont = Font.new(
			"rbxasset://fonts/families/ComicNeueAngular.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		),
		DefaultMinSize = 12,
		DefaultMaxSize = 28,
		DefaultPadding = { x = 8, y = 4 },
	},
	Feedback = {
		HoverSoundId = "rbxassetid://117503154823137",
		ClickSoundId = {
			"rbxassetid://122835655736085",
			"rbxassetid://124993589864467",
		},
	},
	PartyState = {
		DotPulseSeconds = 0.5,
		DotStaggerSeconds = 0.18,
		SequencePauseSeconds = 0.35,
	},
	-- Orbiting establishing shot shown while the mode vote is open. Distance and
	-- Height are studs from Workspace.Assets.Arena.MapOrigin.
	VoteCamera = {
		Distance = 450,
		Height = 120,
		RotationSpeedDeg = 6,
		BlurSize = 10,
	},
	-- Always-on highlight over other players so they read clearly against the
	-- arena. DepthMode Occluded keeps them hidden behind geometry; AlwaysOnTop
	-- would show every player through walls, which the sim's line-of-sight
	-- mechanics are built around.
	PlayerHighlight = {
		FillColor = Color3.fromRGB(255, 0, 0),
		OutlineColor = Color3.new(1, 1, 1),
		FillTransparency = 0.5,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.Occluded,
	},
}
