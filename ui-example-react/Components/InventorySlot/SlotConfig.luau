return {
	Backgrounds = {
		Common = "rbxassetid://17156041815",
		Rare = "rbxassetid://17156041488",
		Legendary = "rbxassetid://17156041739",
		Mythical = "rbxassetid://17156041615",
		Shiny = "rbxassetid://17156041349",
	},
	Colors = {
		Common = Color3.fromRGB(37, 245, 9),
		Rare = Color3.fromRGB(93, 171, 255),
		Legendary = Color3.fromRGB(255, 202, 78),
		Mythical = Color3.fromRGB(167, 66, 255),
	},
	Gradients = {
		Common = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#3bff25")),
				ColorSequenceKeypoint.new(0.25, Color3.fromHex("#fffed2")),
				ColorSequenceKeypoint.new(0.5, Color3.fromHex("#3bff25")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#3bff25")),
			}),

			GradientType = "Shiny",
			Rotation = 0,
		},

		Rare = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#34aeff")),
				ColorSequenceKeypoint.new(0.25, Color3.fromHex("#a2d4ff")),
				ColorSequenceKeypoint.new(0.5, Color3.fromHex("#34aeff")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#34aeff")),
			}),

			GradientType = "Shiny",
			Rotation = 0,
		},

		Epic = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#9a60ff")),
				ColorSequenceKeypoint.new(0.25, Color3.fromHex("#fffed2")),
				ColorSequenceKeypoint.new(0.5, Color3.fromHex("#9a60ff")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#9a60ff")),
			}),

			GradientType = "Shiny",
			Rotation = 0,
		},

		Legendary = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#ffc801")),
				ColorSequenceKeypoint.new(0.25, Color3.fromHex("#fffed2")),
				ColorSequenceKeypoint.new(0.5, Color3.fromHex("#ffc801")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#ffc801")),
			}),

			GradientType = "Shiny",
			Rotation = 0,
		},

		Mythical = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#d30078")),
				ColorSequenceKeypoint.new(0.25, Color3.fromHex("#ea70ff")),
				ColorSequenceKeypoint.new(0.5, Color3.fromHex("#d30078")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#d30078")),
			}),

			GradientType = "Shiny",
			Rotation = 0,
		},

		Shiny = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#ffffff")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#ffffff")),
			}),

			GradientType = "Rainbow",
			Rotation = -180,
		},

		Secret = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#be0d0d")),
				ColorSequenceKeypoint.new(0.25, Color3.fromHex("#530808")),
				ColorSequenceKeypoint.new(0.5, Color3.fromHex("#be0d0d")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#be0d0d")),
			}),

			GradientType = "Shiny",
			Rotation = -180,
		},
	},
}
