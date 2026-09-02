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
		InputGlyphSize = 20,
		PreferredScale = {
			Medium = 1,
			Large = 1.125,
			Larger = 1.25,
			Largest = 1.5,
		},
		DefaultPadding = { x = 8, y = 4 },
	},
	Interaction = {
		MinTargetPx = 44,
	},
	Layout = {
		PortraitMaxAspect = 1,
		CompactMaxWidthPx = 820,
		ShortLandscapeMaxHeightPx = 500,
		Panels = {
			Inventory = {
				Portrait = { WidthScale = 0.956, HeightScale = 0.75, MaxSize = Vector2.new(480, 720) },
				Landscape = {
					WidthScale = 0.602436,
					HeightScale = 0.74763,
					MaxSize = Vector2.new(1000, 820),
					AspectRatio = 1.08,
					ShortHeightScale = 0.86,
				},
			},
			Shop = {
				Portrait = { WidthScale = 0.956, HeightScale = 0.78, MaxSize = Vector2.new(680, 760) },
				Landscape = {
					WidthScale = 0.9,
					HeightScale = 0.82,
					MaxSize = Vector2.new(1200, 820),
					AspectRatio = 1.35,
					ShortHeightScale = 0.86,
				},
			},
			Settings = {
				Portrait = { WidthScale = 0.956, HeightScale = 0.78, MaxSize = Vector2.new(680, 760) },
				Landscape = {
					WidthScale = 0.602,
					HeightScale = 0.748,
					MaxSize = Vector2.new(1100, 820),
					ShortHeightScale = 0.86,
				},
			},
			Notification = {
				Portrait = { WidthScale = 0.9, HeightScale = 0.36, MaxSize = Vector2.new(480, 360) },
				Landscape = {
					WidthScale = 0.46,
					HeightScale = 0.3,
					MaxSize = Vector2.new(760, 360),
					ShortHeightScale = 0.62,
				},
			},
			JoinCode = {
				Portrait = { WidthScale = 0.94, HeightScale = 0.5, MaxSize = Vector2.new(520, 500) },
				Landscape = {
					WidthScale = 0.62,
					HeightScale = 0.46,
					MaxSize = Vector2.new(760, 420),
					ShortHeightScale = 0.82,
				},
			},
			ShopDetails = {
				Portrait = { WidthScale = 0.94, HeightScale = 0.88, MaxSize = Vector2.new(520, 760) },
				Landscape = {
					WidthScale = 0.62,
					HeightScale = 0.68,
					MaxSize = Vector2.new(1100, 760),
					ShortHeightScale = 0.92,
				},
			},
			CrateReveal = {
				Portrait = { WidthScale = 0.94, HeightScale = 0.8, MaxSize = Vector2.new(520, 720) },
				Landscape = {
					WidthScale = 0.56,
					HeightScale = 0.6,
					MaxSize = Vector2.new(950, 720),
					ShortHeightScale = 0.9,
				},
			},
			Loading = {
				Portrait = { WidthScale = 0.94, HeightScale = 0.27, MaxSize = Vector2.new(520, 280) },
				Landscape = {
					WidthScale = 0.58,
					HeightScale = 0.32,
					MaxSize = Vector2.new(1000, 334),
					AspectRatio = 3,
					ShortHeightScale = 0.5,
				},
			},
		},
		Inventory = {
			CardGapPx = 7,
			CardMinPx = 132,
			CardMaxPx = 150,
			MaxColumns = 6,
			HeaderHeightPx = 44,
			SpacerHeightPx = 22,
		},
		GameMode = {
			CardHeightPx = 160,
			CardGapPx = 8,
		},
		TopBar = {
			PortraitWidthScale = 0.92,
			LandscapeWidthScale = 0.4,
			PortraitGapScale = 0.025,
			LandscapeGapScale = 0.05,
		},
		Splash = {
			PortraitActionsHeightPx = 230,
			SecondaryActionHeightPx = 56,
			PrimaryActionHeightPx = 70,
		},
		PartyCode = {
			PortraitHeightPx = 118,
			CodeHeightPx = 58,
		},
		MenuToggle = {
			HorizontalPaddingPx = 12,
			LabelKeycapGapPx = 10,
			KeycapWidthScale = 0.27,
		},
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
