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
	Hud = {
		LiveScoreboard = {
			FfaRows = 3,
			TeamRows = 2,
			TeamColors = {
				Red = Color3.fromRGB(255, 83, 110),
				Blue = Color3.fromRGB(72, 166, 255),
			},
		},
	},
}
