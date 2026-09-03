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
				-- Wider than the other panels: the storefront is a dashboard of
				-- side-by-side category blocks, and the aspect cap is what decides
				-- whether they still fit beside each other on a short window.
				Landscape = {
					WidthScale = 0.9,
					HeightScale = 0.82,
					MaxSize = Vector2.new(1240, 820),
					AspectRatio = 1.5,
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
		-- Storefront dashboard. The content area is a track grid; every category
		-- block declares how many tracks it spans, and the packer drops each one
		-- at the lowest position its span will fit over the blocks already
		-- placed. That is what keeps a shorter block from leaving a hole beneath
		-- it when its neighbour wraps: the next block starts in the space rather
		-- than waiting for the tallest neighbour. Spans are multiples of the
		-- smallest step so blocks always tile -- two quarter spans fill a half,
		-- and so on -- which is what makes the packing come out flush instead of
		-- ragged. Order is the reading order ("Promo" expands to the limited-time
		-- offers, "Rest" to any block no entry names).
		Shop = {
			PaddingXPx = 16,
			PaddingBottomPx = 20,
			ScrollBarPx = 8,
			GapPx = 20,
			CardGapPx = 12,
			HeaderHeightPx = 26,
			HeaderTextSize = 22,
			EmptyHeightPx = 54,
			Tracks = 12,
			SpanSteps = { 4, 8, 12 },
			MainSizeScale = Vector2.new(0.93, 0.78),
			ContentSizeScale = Vector2.new(0.95, 0.93),
			CardClasses = {
				-- Premium passes: artwork over the name and the price, like the rest of
				-- the storefront. There are more of them than fit above the fold at
				-- this size, which is why the block is split rather than flattened.
				Pass = {
					MinPx = 130,
					MaxPx = 300,
					Aspect = 0.78,
					MinHeightPx = 176,
					Layout = "Stack",
					ShowHint = false,
					NameScale = 0.15,
					NameTextSize = 26,
					ActionScale = 0.23,
					ActionMinPx = 28,
					ActionMaxPx = 40,
				},
				-- Currency: the densest class, icon over name over price.
				Tile = {
					MinPx = 100,
					MaxPx = 200,
					Aspect = 1.04,
					MinHeightPx = 112,
					Layout = "Stack",
					ShowHint = false,
					NameScale = 0.15,
					NameTextSize = 24,
					ActionScale = 0.24,
					ActionMinPx = 28,
					ActionMaxPx = 38,
				},
				-- Crates and rotating offers: richer artwork, two to a quarter span.
				Feature = {
					MinPx = 100,
					MaxPx = 235,
					Aspect = 0.68,
					MinHeightPx = 118,
					Layout = "Stack",
					ShowHint = false,
					NameScale = 0.16,
					NameTextSize = 26,
					ActionScale = 0.25,
					ActionMinPx = 28,
					ActionMaxPx = 40,
				},
				-- Limited-time offers: landscape banners, art beside the copy.
				Promo = {
					MinPx = 210,
					MaxPx = 560,
					Aspect = 0.44,
					MinHeightPx = 118,
					Layout = "Split",
					ShowHint = true,
					ArtScale = 0.32,
					NameScale = 0.2,
					NameTextSize = 34,
					ActionScale = 0.26,
					ActionMinPx = 30,
					ActionMaxPx = 44,
				},
			},
			DefaultSection = { Class = "Tile", MaxColumns = 4, Span = 4 },
			PromoSection = { Class = "Promo", MaxColumns = 1, Span = 4 },
			Sections = {
				-- One row of passes is featured at the top of the storefront and the
				-- remainder gets its own block below the offers. The split is a
				-- layout decision, so the two titles it needs live here: neither
				-- block may be labelled as though it were the whole catalogue.
				More = {
					Class = "Pass",
					MaxColumns = 4,
					Span = 12,
					Title = "PASSES",
					Overflow = { Id = "MorePasses", Title = "MORE PASSES", Span = 8 },
				},
				Bonks = { Class = "Tile", MaxColumns = 4, Span = 8 },
				Crates = { Class = "Feature", MaxColumns = 2, Span = 4 },
				ForYou = { Class = "Feature", MaxColumns = 2, Span = 4 },
			},
			Order = { "More", "Promo", "Crates", "Bonks", "ForYou", "MorePasses", "Rest" },
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
			ProgressPanels = {
				EdgePaddingPx = 24,
				GapPx = 10,
				Landscape = {
					DailyBottomScale = 0.9,
					SeasonTopScale = 0.145,
					QuestsTopScale = 0.31,
				},
				Portrait = {
					WidthScale = 0.94,
					TopScale = 0.315,
					BottomScale = 0.64,
					GapPx = 6,
					SeasonWeight = 0.19,
					DailyWeight = 0.29,
					QuestsWeight = 0.52,
				},
				Daily = {
					WidthScale = 0.29,
					HeightScale = 0.2,
					MaxSize = Vector2.new(600, 220),
					AspectRatio = 2.72,
				},
				Season = {
					WidthScale = 0.23,
					HeightScale = 0.16,
					MaxSize = Vector2.new(470, 180),
					AspectRatio = 2.6,
				},
				Quests = {
					WidthScale = 0.3,
					HeightScale = 0.28,
					MaxSize = Vector2.new(600, 300),
					AspectRatio = 2,
				},
			},
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
