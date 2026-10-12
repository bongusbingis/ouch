--[[
    The candy surfaces every panel, card and sticker is built from, at real size, so the shared
    fill / lip / highlight / ink-outline / drop-shadow recipe can be judged in one place.

    States:
      CandySurface -- the button/card recipe in pink (pill radius), yellow (card radius), cream with
                      a WellLine lip, no stroke, and no shadow.
      Panels       -- CandyPanel (cream, default -1.5 deg tilt; upright with padding; lime), OuchPanel
                      (the raised cyan Ouch panel; with gloss) and PanelFrame (the tilted Backpack
                      frame; pops in on mount).
      CandyTitle   -- the modal title sticker: short and long text (long tilts less), pink, cyan,
                      grape, and the ModalTitle size every modal uses.
      Arena surfaces -- Arena/Surface (rounded HUD panel, translucent, custom stroke) and
                      Arena/HUDSurface (candy HUD chip, cream and pink).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Sheet = require(script.Parent.Sheet)

local React = StoryRoot.React
local Components = StoryRoot.Components
local T = StoryRoot.Tokens
local C = T.Colors
local c = React.createElement

local CandySurface = require(Components:WaitForChild("CandySurface"))
local CandyPanel = require(Components:WaitForChild("CandyPanel"))
local OuchPanel = require(Components:WaitForChild("OuchPanel"))
local PanelFrame = require(Components:WaitForChild("PanelFrame"))
local CandyTitle = require(Components:WaitForChild("CandyTitle"))
local ArenaSurface = require(Components:WaitForChild("Arena"):WaitForChild("Surface"))
local HUDSurface = require(Components:WaitForChild("Arena"):WaitForChild("HUDSurface"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))

local function label(text: string): any
	return StoryRoot.Text({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 20,
	})
end

local function Surfaces()
	local size = Vector2.new(180, 90)
	local function surface(order: number, caption: string, props: { [string]: any }): any
		return Sheet.slot(order, caption, size, c(CandySurface, props))
	end
	return Sheet.sheet({
		surface(1, "PINK · PILL", { Color = C.Pink }),
		surface(2, "YELLOW · CARD", { Color = C.Yellow, Radius = T.Shape.RadiusCard }),
		surface(3, "CREAM · WELLLINE LIP", {
			Color = C.SurfaceWarm,
			LipColor = C.WellLine,
			Radius = T.Shape.RadiusCard,
		}),
		surface(4, "NO STROKE", { Color = C.Cyan, Stroke = false, Radius = T.Shape.RadiusCard }),
		surface(5, "NO SHADOW", { Color = C.Lime, Shadow = false, Radius = T.Shape.RadiusCard }),
	})
end

local function Panels()
	local size = Vector2.new(240, 160)
	return Sheet.sheet({
		Sheet.slot(
			1,
			"CANDYPANEL",
			size,
			c(CandyPanel, { Native = { Size = UDim2.fromScale(1, 1) } }, {
				Label = label("CREAM · TILTED"),
			})
		),
		Sheet.slot(
			2,
			"CANDYPANEL · UPRIGHT · PADDED",
			size,
			c(CandyPanel, { Native = { Size = UDim2.fromScale(1, 1) }, Tilt = 0, Padding = 18 }, {
				Label = label("UPRIGHT"),
			})
		),
		Sheet.slot(
			3,
			"CANDYPANEL · LIME",
			size,
			c(CandyPanel, {
				Native = { Size = UDim2.fromScale(1, 1) },
				Color = C.Lime,
			}, { Label = label("LIME") })
		),
		Sheet.slot(
			4,
			"OUCHPANEL",
			size,
			c(OuchPanel, { Native = { Size = UDim2.fromScale(1, 1) } }, {
				Label = label("OUCH PANEL"),
			})
		),
		Sheet.slot(
			5,
			"OUCHPANEL · GLOSS",
			size,
			c(OuchPanel, {
				Native = { Size = UDim2.fromScale(1, 1) },
				Gloss = true,
				Padding = 12,
			}, { Label = label("GLOSS") })
		),
		Sheet.slot(
			6,
			"PANELFRAME",
			size,
			c(PanelFrame, { Native = { Size = UDim2.fromScale(1, 1) } }, {
				Label = label("PANEL FRAME"),
			})
		),
	})
end

local function Titles()
	local function title(order: number, caption: string, width: number, props: { [string]: any }): any
		return Sheet.slot(
			order,
			caption,
			Vector2.new(width, T.Layout.TitleHeight),
			c(CandyTitle, Sheet.merge({ Native = { Size = UDim2.fromOffset(width, T.Layout.TitleHeight) } }, props))
		)
	end
	return Sheet.sheet({
		title(1, "SHORT · PINK", 260, { Text = "SHOP" }),
		title(2, "CYAN", 300, { Text = "SETTINGS", Color = C.Cyan }),
		title(
			3,
			"GRAPE · MODALTITLE SIZE",
			340,
			{ Text = "SEASON PASS", Color = C.Grape, TextSize = T.Type.ModalTitle }
		),
		title(4, "LONG (> 500 PX TILTS LESS)", 760, { Text = "SEASON 1: FIRST SPLAT REWARDS" }),
	})
end

local function Arena()
	local size = Vector2.new(220, 76)
	return Sheet.sheet({
		Sheet.slot(
			1,
			"SURFACE · PANEL",
			size,
			c(ArenaSurface, {
				Color = UIConfig.ProgressionStyle.Panel,
			}, { Label = label("PANEL") })
		),
		Sheet.slot(
			2,
			"SURFACE · TRANSLUCENT",
			size,
			c(ArenaSurface, {
				Color = C.Ink,
				Transparency = 0.35,
			}, { Label = label("OVERLAY") })
		),
		Sheet.slot(
			3,
			"SURFACE · PINK STROKE",
			size,
			c(ArenaSurface, {
				Color = C.SurfaceWarm,
				StrokeColor = C.Pink,
			}, { Label = label("STROKED") })
		),
		Sheet.slot(4, "HUDSURFACE", size, c(HUDSurface, {}, { Label = label("2:05") })),
		Sheet.slot(
			5,
			"HUDSURFACE · PINK",
			size,
			c(HUDSurface, { Color = C.Pink, Shadow = true }, {
				Label = label("RED 18"),
			})
		),
	})
end

return StoryRoot.story({
	Title = "Surfaces",
	Summary = "CandySurface, CandyPanel, OuchPanel, PanelFrame, CandyTitle and the arena HUD surfaces.",
	States = {
		{
			Name = "CandySurface",
			Note = "Fill, lip, highlight, outline, shadow",
			Size = Vector2.new(1100, 150),
			Element = c(Surfaces),
		},
		{
			Name = "Panels",
			Note = "CandyPanel, OuchPanel, PanelFrame",
			Size = Vector2.new(1180, 420),
			Element = c(Panels),
		},
		{
			Name = "CandyTitle",
			Note = "Short, colours, ModalTitle size, long",
			Size = Vector2.new(1100, 260),
			Element = c(Titles),
		},
		{
			Name = "Arena surfaces",
			Note = "Arena/Surface and Arena/HUDSurface",
			Size = Vector2.new(1300, 130),
			Element = c(Arena),
		},
	},
})
