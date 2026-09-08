-- Shared arena presentation tokens reuse the existing palette and interaction scale.
--!strict

local UI = require(script.Parent.UI)
local palette = UI.ProgressionStyle

return {
	Colors = {
		Ink = palette.Ink,
		Surface = palette.Surface,
		Raised = palette.Raised,
		Muted = palette.Muted,
		Panel = palette.Panel,
		PanelRaised = palette.PanelRaised,
		Claimed = palette.Claimed,
		Disabled = palette.Disabled,
		Track = palette.Track,
		Cyan = palette.Cyan,
		Pink = palette.Pink,
		Yellow = palette.Yellow,
		Green = palette.Green,
		White = Color3.new(1, 1, 1),
	},
	Surface = { RadiusPx = 14, StrokePx = 2, ShadowPx = 4 },
	Text = { TitleStroke = 0.04, BodyStroke = 0.02, MinimumPx = 12 },
	Action = { MinimumPx = UI.Interaction.MinTargetPx, HeightPx = 52, TextPx = 25 },
	CoreUI = { RetryCount = 12, RetrySeconds = 0.25 },
	HUD = {
		WidthPx = 620,
		HeightPx = 76,
		EdgePx = 12,
		TopPx = 10,
		UpdateSeconds = 0.1,
		UrgentSeconds = 30,
		RespawnHeightPx = 46,
	},
	Scoreboard = {
		WidthScale = 0.88,
		HeightScale = 0.84,
		MaxWidthPx = 980,
		RowPx = 48,
		RowGapPx = 6,
		ChromePx = 108,
		MinRows = 3,
	},
	Teammates = { MaxDistanceStuds = 100, HeightStuds = 2.2 },
	Results = {
		EdgePx = 16,
		GapPx = 14,
		MaxWidthPx = 1420,
		ShortHeightPx = 520,
		HeaderPx = 72,
		ShortHeaderPx = 44,
		FooterPx = 72,
		ShortFooterPx = 58,
		PodiumUpdateHz = 30,
		StageOrigin = CFrame.new(0, 10000, 1000),
		StageTarget = Vector3.new(0, 4.4, 0),
		StageSpan = Vector2.new(25, 11),
		StageFieldOfView = 40,
	},
}
