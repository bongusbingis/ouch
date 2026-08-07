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

	Tweens = {
		Menu = {
			Open = {
				Time = 0.18,
				EasingStyle = Enum.EasingStyle.Quad,
				EasingDirection = Enum.EasingDirection.Out,
			},
			Close = {
				Time = 0.14,
				EasingStyle = Enum.EasingStyle.Quad,
				EasingDirection = Enum.EasingDirection.In,
			},
		},

		Button = {
			Hover = {
				Time = 0.1,
				EasingStyle = Enum.EasingStyle.Quad,
				EasingDirection = Enum.EasingDirection.Out,
			},
			Press = {
				Time = 0.06,
				EasingStyle = Enum.EasingStyle.Quad,
				EasingDirection = Enum.EasingDirection.Out,
			},
			Release = {
				Time = 0.12,
				EasingStyle = Enum.EasingStyle.Back,
				EasingDirection = Enum.EasingDirection.Out,
			},
			Select = {
				Time = 0.14,
				EasingStyle = Enum.EasingStyle.Quad,
				EasingDirection = Enum.EasingDirection.Out,
			},
		},
	},

	Elements = {
		Button = {
			DefaultColor = { r = 0.18, g = 0.36, b = 0.82 },
			SelectedColor = { r = 0.35, g = 0.62, b = 1 },
			HoverBrightness = 1.12,
			PressedBrightness = 0.9,
			DefaultScale = 1,
			HoverScale = 1.045,
			PressedScale = 0.94,
			SelectedScale = 1.025,
			Text = {
				MinSize = 12,
				MaxSize = 26,
				Padding = { x = 10, y = 4 },
			},
		},
	},

	Menus = {
		ClosedYOffset = 26,
		ClosedScale = 0.96,
		OpenScale = 1,
	},

	Hud = {
		DelayIndicator = {
			FullSize = {
				xScale = 0.35,
				xOffset = 0,
				yScale = 0.002,
				yOffset = 0,
			},
		},
		LiveScoreboard = {
			FfaRows = 3,
			TeamRows = 2,
			TeamColors = {
				Red = Color3.fromRGB(255, 83, 110),
				Blue = Color3.fromRGB(72, 166, 255),
			},
		},
		MatchVote = {
			PortraitThreshold = 0.94,
			LandscapeAspect = 2.18,
			PortraitAspect = 0.78,
			Options = {
				{
					Top = Color3.fromRGB(255, 103, 155),
					Bottom = Color3.fromRGB(204, 36, 113),
				},
				{
					Top = Color3.fromRGB(97, 222, 255),
					Bottom = Color3.fromRGB(31, 121, 218),
				},
				{
					Top = Color3.fromRGB(186, 255, 93),
					Bottom = Color3.fromRGB(62, 184, 100),
				},
			},
			Modes = {
				FFA = {
					Top = Color3.fromRGB(255, 103, 135),
					Bottom = Color3.fromRGB(219, 39, 89),
				},
				TDM = {
					Top = Color3.fromRGB(73, 218, 207),
					Bottom = Color3.fromRGB(17, 139, 156),
				},
			},
			Selected = Color3.fromRGB(255, 218, 82),
		},
	},
}
