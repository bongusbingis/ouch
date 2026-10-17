--[[
    Ouch!'s type and colour vocabulary in one place: every Tokens.Type size drawn in both families,
    the text components the pages use, the section headers, and the Tokens.Colors palette.

    States:
      Type scale       -- Title 52, Section 30 / ModalTitle 30, Tab 26, TileLabel 22, Body 20,
                          Minimum 18 (menu floor) and HudMinimum 16 (in-match floor), each in
                          Display (Fredoka One) beside Label (Builder Sans ExtraBold).
      Text components  -- LobbyText (ink label, wraps), OuchText (outlined face, fitted),
                          ResponsiveText (fits a box, wrapped and truncated), PageTitle
                          (Luckiest Guy heading, left and centre aligned).
      Section headers  -- SectionHeader (white underlined lettering, with a countdown accessory)
                          and the Candy variant (ink text over the striped yellow ribbon, tilted).
      Palette          -- every Tokens.Colors entry as a labelled swatch, lips beside fills.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Sheet = require(script.Parent.Sheet)

local React = StoryRoot.React
local Components = StoryRoot.Components
local T = StoryRoot.Tokens
local C = T.Colors
local c = React.createElement

local LobbyText = require(Components:WaitForChild("LobbyText"))
local OuchText = require(Components:WaitForChild("OuchText"))
local ResponsiveText = require(Components:WaitForChild("ResponsiveText"))
local PageTitle = require(Components:WaitForChild("PageTitle"))
local SectionHeader = require(Components:WaitForChild("SectionHeader"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))

local SCALE = {
	{ "TITLE", T.Type.Title },
	{ "SECTION / MODALTITLE", T.Type.Section },
	{ "TAB", T.Type.Tab },
	{ "TILELABEL", T.Type.TileLabel },
	{ "BODY", T.Type.Body },
	{ "MINIMUM (MENUS)", T.Type.Minimum },
	{ "HUDMINIMUM (IN MATCH)", T.Type.HudMinimum },
}

local function TypeScale()
	local rows: { [string]: any } = {
		Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 24), PaddingTop = UDim.new(0, 16) }),
		Layout = c("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, entry in SCALE do
		local size = entry[2]
		rows[`Row{index}`] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.new(1, -48, 0, size + 8),
		}, {
			Name = StoryRoot.Text({
				Size = UDim2.new(0, 230, 1, 0),
				Text = `{entry[1]} · {size}`,
				TextColor3 = C.InkSoft,
				TextSize = 14,
			}),
			Display = c("TextLabel", {
				BackgroundTransparency = 1,
				Font = T.Type.Display,
				Position = UDim2.fromOffset(240, 0),
				Size = UDim2.new(0.5, -130, 1, 0),
				Text = "SPLASH THEM ALL",
				TextColor3 = C.Surface,
				TextSize = size,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, { Stroke = c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline }) }),
			Label = c("TextLabel", {
				BackgroundTransparency = 1,
				Font = T.Type.Label,
				Position = UDim2.new(0.5, 120, 0, 0),
				Size = UDim2.new(0.5, -130, 1, 0),
				Text = "Catch 3 dodgeballs",
				TextColor3 = C.Ink,
				TextSize = size,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
	end
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, rows)
end

local function TextComponents()
	local box = Vector2.new(280, 64)
	return Sheet.sheet({
		Sheet.slot(
			1,
			"LOBBYTEXT",
			box,
			c(LobbyText, {
				Size = UDim2.fromScale(1, 1),
				Text = "Throw 10 dodgeballs to earn 125 Bonks.",
			})
		),
		Sheet.slot(
			2,
			"OUCHTEXT",
			box,
			c(OuchText, {
				Native = {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "FIRST SPLAT",
					TextColor3 = C.Surface,
				},
				MaxTextSize = 40,
			})
		),
		Sheet.slot(
			3,
			"RESPONSIVETEXT · WRAPPED",
			box,
			c(ResponsiveText, {
				MeasurementFont = UIConfig.Text.BodyFont,
				Wrapped = true,
				MaxTextSize = 28,
				Native = {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Font = T.Type.Label,
					Text = "A LONG LABEL THAT HAS TO FIT INSIDE ITS BOX",
					TextColor3 = C.Ink,
				},
			})
		),
		Sheet.slot(
			4,
			"RESPONSIVETEXT · TRUNCATED",
			Vector2.new(180, 40),
			c(ResponsiveText, {
				MeasurementFont = UIConfig.Text.BodyFont,
				Truncate = true,
				MinTextSize = 18,
				MaxTextSize = 24,
				Native = {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Font = T.Type.Label,
					Text = "SUPER LONG CANDY ARCHIPELAGO",
					TextColor3 = C.Ink,
				},
			})
		),
		Sheet.slot(
			5,
			"PAGETITLE · CENTRE",
			Vector2.new(320, 64),
			c(PageTitle, {
				Text = "BACKPACK",
				Native = { Size = UDim2.fromScale(1, 1) },
			})
		),
		Sheet.slot(
			6,
			"PAGETITLE · LEFT",
			Vector2.new(320, 64),
			c(PageTitle, {
				Text = "SETTINGS",
				Alignment = Enum.TextXAlignment.Left,
				Native = { Size = UDim2.fromScale(1, 1) },
			})
		),
	})
end

local function Headers()
	local width = 520
	local countdown = StoryRoot.Text({
		Size = UDim2.fromScale(1, 1),
		Text = "NEW IN 6H 12M",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Surface,
	})
	return Sheet.sheet({
		Sheet.slot(1, "SECTIONHEADER", Vector2.new(width, 54), c(SectionHeader, { Text = "DAILY OFFERS" })),
		Sheet.slot(
			2,
			"SECTIONHEADER · ACCESSORY",
			Vector2.new(width, 54),
			c(SectionHeader, { Text = "FEATURED", Accessory = countdown, AccessoryWidthPx = 160 })
		),
		Sheet.slot(3, "CANDY", Vector2.new(width, 54), c(SectionHeader, { Candy = true, Text = "OUTFITS" })),
		Sheet.slot(
			4,
			"CANDY · ACCESSORY · LIME",
			Vector2.new(width, 54),
			c(SectionHeader, {
				Candy = true,
				Text = "EMOTES",
				Color = C.Lime,
				Accessory = StoryRoot.Text({
					Size = UDim2.fromScale(1, 1),
					Text = "SCROLL ›",
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				AccessoryWidthPx = 120,
			})
		),
	})
end

local PALETTE = {
	"BackdropTop",
	"BackdropMid",
	"BackdropBottom",
	"Ink",
	"InkSoft",
	"Surface",
	"SurfaceWarm",
	"Well",
	"WellLine",
	"NeutralTile",
	"Pink",
	"PinkLip",
	"Yellow",
	"YellowLip",
	"Cyan",
	"CyanLip",
	"Lime",
	"LimeLip",
	"Orange",
	"OrangeLip",
	"Grape",
	"GrapeLip",
	"Gold",
	"GoldLip",
}

local function Palette()
	local cells = {}
	for index, name in PALETTE do
		local color: Color3 = (C :: any)[name]
		table.insert(
			cells,
			Sheet.slot(
				index,
				name,
				Vector2.new(120, 64),
				c("Frame", {
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }),
					Stroke = c("UIStroke", { Color = C.Ink, Thickness = 2 }),
					Hex = StoryRoot.Text({
						Size = UDim2.fromScale(1, 1),
						Text = `#{color:ToHex()}`,
						TextSize = 14,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextColor3 = if name == "Ink" or name == "InkSoft" then C.Surface else C.Ink,
					}),
				})
			)
		)
	end
	return Sheet.sheet(cells, 16)
end

return StoryRoot.story({
	Title = "Text & Palette",
	Summary = "Every Tokens.Type size in both families, the text components, section headers and the Tokens.Colors palette.",
	States = {
		{
			Name = "Type scale",
			Note = "Display (left) and Label (right) at every token size",
			Size = Vector2.new(1200, 330),
			Element = c(TypeScale),
		},
		{
			Name = "Text components",
			Note = "LobbyText, OuchText, ResponsiveText, PageTitle",
			Size = Vector2.new(1100, 240),
			Element = c(TextComponents),
		},
		{
			Name = "Section headers",
			Note = "SectionHeader and the Candy variant, with accessories",
			Size = Vector2.new(1180, 220),
			Element = c(Headers),
		},
		{ Name = "Palette", Note = "Tokens.Colors", Size = Vector2.new(1180, 380), Element = c(Palette) },
	},
})
