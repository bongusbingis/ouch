--[[
    The recessed containers that cards and rows sit in, and the scrolling well every list uses.

    States:
      Well       -- the default (Claimed fill, white outline, drop shadow), Ouch (the Figma 9-slice
                    skin over OuchPanel), Candy (light Well fill with a WellLine outline, card
                    radius) and a custom colour with no shadow.
      WellScroll -- a Candy and an Ouch scrolling well with more rows than fit, so the scrollbar,
                    clipping and inset are visible. Scroll it; select it with a gamepad to see the
                    yellow focus outline (ScrollFrame).
      ScrollFrame -- the bare scroller with the same overflowing rows.
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Sheet = require(script.Parent.Sheet)

local React = StoryRoot.React
local Components = StoryRoot.Components
local T = StoryRoot.Tokens
local C = T.Colors
local c = React.createElement

local Well = require(Components:WaitForChild("Well"))
local WellScroll = require(Components:WaitForChild("WellScroll"))
local ScrollFrame = require(Components:WaitForChild("ScrollFrame"))

local function label(text: string): any
	return StoryRoot.Text({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 20,
	})
end

local function rows(count: number): { [string]: any }
	local children: { [string]: any } = {
		Layout = c("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 12) }),
	}
	for index = 1, count do
		children[`Row{index}`] = c("Frame", {
			BackgroundColor3 = if index % 2 == 0 then C.SurfaceWarm else C.Surface,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 44),
			ZIndex = 6,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Label = StoryRoot.Text({
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -24, 1, 0),
				Text = `ROW {index} · CATCH 3 DODGEBALLS`,
				ZIndex = 7,
			}),
		})
	end
	return children
end

local function scrollProps(): { [string]: any }
	return {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = T.Layout.ScrollBar,
		ScrollBarImageColor3 = C.Ink,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	}
end

local function Wells()
	local size = Vector2.new(240, 150)
	return Sheet.sheet({
		Sheet.slot(1, "DEFAULT", size, c(Well, {}, { Label = label("DEFAULT") })),
		Sheet.slot(2, "OUCH (9-SLICE)", size, c(Well, { Ouch = true }, { Label = label("OUCH") })),
		Sheet.slot(3, "CANDY", size, c(Well, { Candy = true }, { Label = label("CANDY") })),
		Sheet.slot(
			4,
			"CUSTOM · NO SHADOW",
			size,
			c(Well, { Color = C.NeutralTile, Shadow = false }, { Label = label("CUSTOM") })
		),
	})
end

local function Scrolls()
	local size = Vector2.new(340, 260)
	return Sheet.sheet({
		Sheet.slot(1, "WELLSCROLL · CANDY", size, c(WellScroll, { Candy = true, Native = scrollProps() }, rows(10))),
		Sheet.slot(2, "WELLSCROLL · OUCH", size, c(WellScroll, { Ouch = true, Native = scrollProps() }, rows(10))),
		Sheet.slot(
			3,
			"SCROLLFRAME",
			size,
			c(
				ScrollFrame,
				Sheet.merge(
					scrollProps(),
					{ BackgroundColor3 = C.Well, BackgroundTransparency = 0, BorderSizePixel = 0 }
				),
				rows(10)
			)
		),
	})
end

return StoryRoot.story({
	Title = "Wells & Scrolling",
	Summary = "Well (default, Ouch, Candy, custom), WellScroll with overflowing rows and the bare ScrollFrame.",
	States = {
		{
			Name = "Well",
			Note = "Default, Ouch skin, Candy, custom",
			Size = Vector2.new(1120, 220),
			Element = c(Wells),
		},
		{
			Name = "Scrolling",
			Note = "Ten rows in each; scroll them",
			Size = Vector2.new(1160, 330),
			Element = c(Scrolls),
		},
	},
})
