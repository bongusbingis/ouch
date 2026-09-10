--!strict

local characterBody = {
	Minimum = Vector3.new(-2.25, -3, -2.25),
	Maximum = Vector3.new(2.25, 4.5, 2.25),
}

return {
	Preview = { MaxHz = 30, MaxDeltaSeconds = 0.1 },
	LobbyArtwork = {
		Logo = {
			Image = "rbxassetid://78333957912633",
			Offset = Vector2.new(91, 114),
			Size = Vector2.new(813, 379),
			OpticalCenterY = 203.08,
		},
		Action = {
			Cyan = "rbxassetid://136021539696619",
			Pink = "rbxassetid://94748581468730",
			CyanSlice = Rect.new(198, 228, 842, 469),
			PinkSlice = Rect.new(198, 228, 841, 468),
			SliceScale = 0.09,
			CornerPx = 12,
			ShadowPx = 2.4,
			TextOffsetY = 3,
			PaddingPx = 16,
			MinPaddingPx = 10,
			WidthPaddingScale = 0.1,
			IconPx = 22,
			IconGapPx = 10,
		},
	},
	ProgressionStyle = {
		White = Color3.new(1, 1, 1),
		Ink = Color3.fromRGB(30, 32, 36),
		Surface = Color3.fromRGB(37, 41, 48),
		Raised = Color3.fromRGB(55, 61, 70),
		Panel = Color3.fromRGB(20, 189, 218),
		PanelRaised = Color3.fromRGB(53, 204, 231),
		Claimed = Color3.fromRGB(17, 133, 204),
		Disabled = Color3.fromRGB(84, 169, 190),
		Track = Color3.fromRGB(107, 222, 238),
		Muted = Color3.fromRGB(220, 230, 238),
		Cyan = Color3.fromRGB(20, 192, 222),
		Pink = Color3.fromRGB(239, 18, 111),
		Yellow = Color3.fromRGB(255, 220, 62),
		Green = Color3.fromRGB(154, 233, 91),
		Shadow = Color3.new(0, 0, 0),
	},
	-- One radius scale: panels and modals, then every control and inner
	-- container, then tiles nested inside a container. Pills only for chips
	-- and bars no taller than PillMaxPx.
	Radius = { Panel = 16, Control = 12, Tile = 8, PillMaxPx = 32 },
	Well = { StrokePx = 2, ShadowPx = 4, InsetPx = 12 },
	Text = {
		BodyFont = Enum.Font.BuilderSansBold,
		DefaultFont = Font.new(
			"rbxasset://fonts/families/ComicNeueAngular.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		),
		DefaultMinSize = 12,
		DefaultMaxSize = 28,
		CaptionMinPx = 16,
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
		FocusStrokePx = 3,
		FocusCornerPx = 8,
	},
	Button = {
		StrokePx = 2,
		ShadowPx = 4,
		TextPx = 28,
		PricePx = 25,
		GapPx = 5,
	},
	Layout = {
		SectionHeader = { TextPx = 24, HeightPx = 38, UnderlinePx = 2, UnderlineGapPx = 4, BottomGapPx = 10 },
		PageSurface = {
			Image = "rbxassetid://124751224634629",
			SliceCenter = Rect.new(31, 41, 978, 620),
			SliceScale = 0.5,
		},
		-- The inner-container 9-slice from Figma; an empty Image makes Well draw
		-- the same construction natively until the upload is approved.
		WellSurface = {
			Image = "",
			SliceCenter = Rect.new(32, 32, 480, 288),
			SliceScale = 0.5,
		},
		PagePosition = UDim2.fromScale(0.5, 0.56),
		InventoryPagePosition = UDim2.fromScale(0.32, 0.56),
		PageOffscreen = UDim2.fromScale(-1, 0.56),
		ShortPagePosition = UDim2.fromScale(0.5, 0.62),
		ShortPageOffscreen = UDim2.fromScale(-1, 0.62),
		MatchHUD = { WidthPx = 420, HeightPx = 78, TopPx = 54, EdgePx = 12, RespawnHeightPx = 36 },
		PortraitMaxAspect = 1,
		CompactMaxWidthPx = 820,
		ShortLandscapeMaxHeightPx = 500,
		PartyNametags = { GapPx = 3, ViewportPaddingPx = 8 },
		WorldFraming = {
			FieldOfView = 50,
			CharacterBody = characterBody,
			CharacterWidthStuds = 6,
			CharacterHeightStuds = 6,
			CharacterDepthStuds = 4,
			NameHeadroomStuds = 1.5,
			InventoryBody = {
				Minimum = characterBody.Minimum,
				Maximum = characterBody.Maximum + Vector3.new(0, 1.5, 0),
			},
			InventorySkins = {
				Minimum = Vector3.new(-3.4, -3, -3.75),
				Maximum = Vector3.new(3.4, 6, 3.55),
			},
			PixelPadding = 8,
		},
		Panels = {
			DailyReward = {
				Portrait = { WidthScale = 0.9, HeightScale = 0.48, MaxSize = Vector2.new(480, 430) },
				Landscape = {
					WidthScale = 0.46,
					HeightScale = 0.58,
					MaxSize = Vector2.new(620, 460),
					ShortHeightScale = 0.88,
				},
			},
			Inventory = {
				Portrait = { WidthScale = 0.956, HeightScale = 0.75, MaxSize = Vector2.new(480, 720) },
				Landscape = {
					WidthScale = 0.602436,
					HeightScale = 0.74763,
					MaxSize = Vector2.new(1000, 820),
					AspectRatio = 1.08,
					ShortHeightScale = 0.7,
					ShortWidthScale = 0.9,
					ShortAspectRatio = 2.4,
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
					ShortHeightScale = 0.7,
					ShortWidthScale = 0.9,
					ShortAspectRatio = 2.5,
				},
			},
			Settings = {
				Portrait = { WidthScale = 0.956, HeightScale = 0.78, MaxSize = Vector2.new(680, 760) },
				Landscape = {
					WidthScale = 0.602,
					HeightScale = 0.748,
					MaxSize = Vector2.new(1100, 820),
					ShortHeightScale = 0.7,
					ShortWidthScale = 0.9,
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
					WidthScale = 0.86,
					HeightScale = 0.78,
					MaxSize = Vector2.new(1100, 760),
					ShortHeightScale = 0.96,
					ShortWidthScale = 0.96,
				},
			},
			CrateReveal = {
				Portrait = { WidthScale = 0.94, HeightScale = 0.8, MaxSize = Vector2.new(520, 720) },
				Landscape = {
					WidthScale = 0.56,
					HeightScale = 0.6,
					MaxSize = Vector2.new(950, 720),
					ShortHeightScale = 0.9,
					ShortWidthScale = 0.86,
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
			ShortRailWidthPx = 88,
			ShortRailGapPx = 4,
			ShortContentLeftPx = 106,
			ShortContentTopPx = 44,
			ShortContentBottomPx = 10,
			ShortCardMinPx = 104,
			ShortPanelWidthScale = 0.58,
			ShortPanelMinWidthPx = 360,
			ShortWorldMinWidthPx = 170,
			ShortCardSizePx = 124,
			ShortHeaderHeightPx = 34,
			CardGapPx = 7,
			CardMinPx = 132,
			CardMaxPx = 150,
			MaxColumns = 6,
			HeaderHeightPx = 50,
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
			ShortCardHeightPx = 196,
			ShortCardWidthPx = 210,
			PaddingXPx = 16,
			PaddingBottomPx = 20,
			ScrollBarPx = 8,
			GapPx = 20,
			CardGapPx = 12,
			HeaderHeightPx = 38,
			HeaderTextSize = 22,
			EmptyHeightPx = 54,
			Tracks = 12,
			SpanSteps = { 4, 8, 12 },
			CardClasses = {
				-- Premium passes: artwork over the name and the price, like the rest of
				-- the storefront. There are more of them than fit above the fold at
				-- this size, which is why the block is split rather than flattened.
				Pass = {
					MinPx = 130,
					MaxPx = 300,
					Aspect = 1,
					MinHeightPx = 210,
					Layout = "Stack",
					ShowHint = false,
					NameScale = 0.15,
					NameTextSize = 26,
					ActionScale = 0.23,
					ActionMinPx = 44,
					ActionMaxPx = 44,
				},
				-- Currency: the densest class, icon over name over price.
				Tile = {
					MinPx = 140,
					MaxPx = 200,
					Aspect = 1.04,
					MinHeightPx = 170,
					Layout = "Stack",
					ShowHint = false,
					NameScale = 0.15,
					NameTextSize = 24,
					ActionScale = 0.24,
					ActionMinPx = 44,
					ActionMaxPx = 44,
				},
				-- Crates and rotating offers: richer artwork, two to a quarter span.
				Feature = {
					MinPx = 150,
					MaxPx = 235,
					Aspect = 0.86,
					MinHeightPx = 190,
					Layout = "Stack",
					ShowHint = false,
					NameScale = 0.16,
					NameTextSize = 26,
					ActionScale = 0.25,
					ActionMinPx = 44,
					ActionMaxPx = 44,
				},
				-- Limited-time offers: landscape banners, art beside the copy.
				Promo = {
					MinPx = 210,
					MaxPx = 560,
					Aspect = 0.44,
					MinHeightPx = 150,
					Layout = "Split",
					ShowHint = true,
					ArtScale = 0.32,
					NameScale = 0.2,
					NameTextSize = 34,
					ActionScale = 0.26,
					ActionMinPx = 44,
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
		EmoteWheel = require(script.Parent.EmoteWheel),
		TopBar = {
			ShortHeightPx = 72,
			ShortWidthScale = 0.7,
			PortraitWidthScale = 0.92,
			LandscapeWidthScale = 0.4,
			PortraitGapScale = 0.025,
			LandscapeGapScale = 0.05,
		},
		Splash = {
			DesktopLogoSizePx = Vector2.new(220, 110),
			ActionsGapPx = 8,
			ActionTextPx = 26,
			PrimaryActionTextPx = 38,
			ActionHeightPx = 52,
			PrimaryActionHeightPx = 68,
			DesktopPrimaryActionHeightPx = 84,
			DesktopPrimaryActionTextPx = 46,
			DesktopStatusHeightPx = 28,
			ShortActionTextPx = 22,
			ShortActionsHeightPx = 56,
			ShortActionButtonHeightPx = 48,
			ShortActionsBottomPx = 8,
			ShortLogoTopPx = 78,
			PortraitActionsHeightPx = 146,
			SecondaryActionHeightPx = 56,
			ProgressPanels = {
				DailyMinHeightPx = 140,
				EdgePaddingPx = 24,
				GapPx = 10,
				Landscape = {
					MinWidthPx = 360,
					SeasonHeightPx = 88,
					DailyHeightPx = 140,
					QuestsMinHeightPx = 156,
					ActionsReservePx = 280,
					DailyBottomScale = 0.9,
					SeasonTopScale = 0.145,
					ShortTopPx = 80,
					ShortBottomPx = 78,
					QuestsTopScale = 0.31,
				},
				Portrait = {
					WidthScale = 0.94,
					TopScale = 0.24,
					BottomScale = 0.67,
					GapPx = 6,
					SeasonWeight = 0.22,
					DailyWeight = 0.37,
					QuestsWeight = 0.41,
				},
				Daily = {
					WidthScale = 0.34,
					HeightScale = 0.27,
					MaxSize = Vector2.new(600, 220),
					AspectRatio = 2.5,
				},
				Season = {
					WidthScale = 0.3,
					HeightScale = 0.16,
					ShortHeightScale = 0.19,
					ShortAspectRatio = 4,
					MaxSize = Vector2.new(600, 180),
					AspectRatio = 3.5,
				},
				Quests = {
					WidthScale = 0.3,
					HeightScale = 0.32,
					ShortHeightScale = 0.4,
					MaxSize = Vector2.new(600, 340),
					AspectRatio = 1.65,
				},
			},
		},
		SettingsControls = {
			ShortRowHeightPx = 80,
			RowHeight = { Compact = { Plain = 104, Description = 140 }, Wide = { Plain = 88, Description = 104 } },
			SliderLabelHeightPx = 24,
			LabelControlGapPx = 8,
		},
		InventoryContentGapPx = 8,
		SeasonClaimWidthPx = 102,
		ShopDetailsActionMaxWidthPx = 320,
		SeasonCompactClaimWidthPx = 70,
		SeasonDetailedMinHeightPx = 132,
		QuestRow = { ShortHeightPx = 80, CompactHeightPx = 138, CompactInfoHeightPx = 82 },
		DailyCell = {
			FullWeekMinWidthPx = 352,
			MinWidthPx = 52,
		},
		PartyCode = {
			PortraitHeightPx = 118,
			LandscapeWidthPx = 210,
			LandscapeCodeHeightPx = 40,
			CodeHeightPx = 58,
			Members = {
				MaxWidthPx = 620,
				MaxHeightPx = 420,
				MarginPx = 16,
				GapPx = 8,
				RowHeightPx = 64,
				ActionWidthPx = 112,
			},
		},
		MenuToggle = {
			HorizontalPaddingPx = 12,
			LabelKeycapGapPx = 10,
			KeycapWidthScale = 0.27,
		},
	},
	Feedback = {
		Volume = 0.5,
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
