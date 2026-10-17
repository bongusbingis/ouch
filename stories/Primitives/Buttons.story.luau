--[[
    Every pressable candy button, side by side at its real size, so a change to the shared press
    recipe (AnimatedButton motion + CandySurface fill/lip/highlight) shows up everywhere at once.

    States:
      PuffyButton   -- every candy fill (Pink, Yellow, Cyan, Lime, Orange, Grape, Surface with ink
                       text), disabled (WellLine fill), wrapped two-line label, no-shadow.
      AnimatedButton -- the bare primitive with a custom Visual (OuchButton plastic skin), enabled
                       and disabled; the Visual receives the PressDepth binding.
      ModalClose    -- the X used by every modal, enabled and disabled (no OnActivated).
      ShopPriceButton -- Bonks price, Robux text, stacked "BUY / price", Red (pink) and disabled.
      Arena ActionButton -- primary (pink), secondary (cyan), completed, disabled.

    Hover, press and gamepad focus are live: point at or click any button (prints to Output).
    Nothing here can force the hover state from data; hover a button to see it.
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)
local Sheet = require(script.Parent.Sheet)

local React = StoryRoot.React
local Components = StoryRoot.Components
local T = StoryRoot.Tokens
local C = T.Colors
local c = React.createElement

local PuffyButton = require(Components:WaitForChild("PuffyButton"))
local AnimatedButton = require(Components:WaitForChild("AnimatedButton"))
local OuchButton = require(Components:WaitForChild("OuchButton"))
local ModalClose = require(Components:WaitForChild("ModalClose"))
local ShopPriceButton = require(Components:WaitForChild("Shop"):WaitForChild("ShopPriceButton"))
local ActionButton = require(Components:WaitForChild("Arena"):WaitForChild("ActionButton"))

local slot, sheet = Sheet.slot, Sheet.sheet

local PILL = Vector2.new(200, 64)
local log = Fixtures.log("Buttons", "pressed")

local function puffy(order: number, label: string, props: { [string]: any }): any
	local merged: { [string]: any } = {
		Text = "PLAY",
		Native = { Size = UDim2.fromScale(1, 1) },
		OnActivated = function()
			log(label)
		end,
	}
	for key, value in props do
		merged[key] = value
	end
	return slot(order, label, PILL, c(PuffyButton, merged))
end

local COLORS = {
	{ "PINK", C.Pink, C.PinkLip },
	{ "YELLOW", C.Yellow, C.YellowLip },
	{ "CYAN", C.Cyan, C.CyanLip },
	{ "LIME", C.Lime, C.LimeLip },
	{ "ORANGE", C.Orange, C.OrangeLip },
	{ "GRAPE", C.Grape, C.GrapeLip },
}

local function Puffies()
	local cells = {}
	for index, entry in COLORS do
		table.insert(cells, puffy(index, entry[1], { Color = entry[2], LipColor = entry[3] }))
	end
	table.insert(
		cells,
		puffy(#cells + 1, "SURFACE · INK TEXT", { Color = C.Surface, LipColor = C.WellLine, TextColor = C.Ink })
	)
	table.insert(cells, puffy(#cells + 1, "DISABLED", { Color = C.Pink, Enabled = false }))
	table.insert(
		cells,
		puffy(#cells + 1, "WRAPPED", {
			Color = C.Cyan,
			Text = "OPEN AGAIN FOR 500",
			TextSize = T.Type.Minimum,
			Wrapped = true,
		})
	)
	table.insert(cells, puffy(#cells + 1, "NO SHADOW", { Color = C.Yellow, Shadow = false, Text = "CLAIM" }))
	return sheet(cells)
end

local function Primitives()
	local function animated(order: number, label: string, enabled: boolean): any
		return slot(
			order,
			label,
			Vector2.new(220, 64),
			c(AnimatedButton, {
				Native = { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "" },
				Enabled = enabled,
				OnActivated = function()
					log(label)
				end,
				Visual = c(OuchButton, { Enabled = enabled }),
			}, {
				Label = c("TextLabel", {
					BackgroundTransparency = 1,
					Font = T.Type.Display,
					Size = UDim2.fromScale(1, 1),
					Text = "OUCH BUTTON",
					TextColor3 = C.Surface,
					TextSize = T.Type.Body,
					ZIndex = 8,
				}, { Stroke = c("UIStroke", { Color = C.Ink, Thickness = 2 }) }),
			})
		)
	end
	local function close(order: number, label: string, enabled: boolean): any
		return slot(
			order,
			label,
			Vector2.new(T.Layout.MinTarget, T.Layout.MinTarget),
			c(ModalClose, {
				AnchorPoint = Vector2.zero,
				Position = UDim2.new(),
				OnActivated = if enabled
					then function()
						log(label)
					end
					else nil,
			})
		)
	end
	return sheet({
		animated(1, "ANIMATED · OUCH VISUAL", true),
		animated(2, "ANIMATED · DISABLED", false),
		close(3, "CLOSE", true),
		close(4, "CLOSE OFF", false),
	})
end

local function PriceButtons()
	local size = Vector2.new(200, 72)
	local function price(order: number, label: string, props: { [string]: any }): any
		local merged: { [string]: any } = {
			AnchorPoint = Vector2.zero,
			Position = UDim2.new(),
			Size = UDim2.fromScale(1, 1),
			OnActivated = function()
				log(label)
			end,
		}
		for key, value in props do
			merged[key] = value
		end
		return slot(order, label, size, c(ShopPriceButton, merged))
	end
	return sheet({
		price(1, "BONKS PRICE", { BonksAmount = 750 }),
		price(2, "ROBUX TEXT", { Text = "R$ 199" }),
		price(3, "STACKED · BONKS", { Text = "BUY", SubBonks = 1500 }),
		price(4, "STACKED · TEXT", { Text = "OPEN 10", SubText = "R$ 899" }),
		price(5, "RED", { Text = "BUY NOW", Red = true }),
		price(6, "GRAPE", { Text = "PREMIUM", Color = C.Grape }),
		price(7, "DISABLED", { BonksAmount = 12000, Enabled = false }),
	})
end

local function ActionButtons()
	local size = Vector2.new(220, 52)
	local function action(order: number, label: string, props: { [string]: any }): any
		local merged: { [string]: any } = {
			Native = { Size = UDim2.fromScale(1, 1) },
			OnActivated = function()
				log(label)
			end,
		}
		for key, value in props do
			merged[key] = value
		end
		return slot(order, label, size, c(ActionButton, merged))
	end
	return sheet({
		action(1, "PRIMARY", { Text = "PLAY AGAIN", Primary = true }),
		action(2, "SECONDARY", { Text = "LOBBY" }),
		action(3, "COMPLETED", { Text = "CLAIMED", Completed = true }),
		action(4, "DISABLED", { Text = "WAITING", Enabled = false }),
	})
end

return StoryRoot.story({
	Title = "Buttons",
	Summary = "Every candy button: PuffyButton in each fill, the bare AnimatedButton, ModalClose, ShopPriceButton and the arena ActionButton. Hover and press are live.",
	States = {
		{
			Name = "PuffyButton",
			Note = "Six candy fills, surface, disabled, wrapped, no shadow",
			Size = Vector2.new(980, 300),
			Element = c(Puffies),
		},
		{
			Name = "AnimatedButton + ModalClose",
			Note = "Custom Visual gets PressDepth; close X on and off",
			Size = Vector2.new(720, 140),
			Element = c(Primitives),
		},
		{
			Name = "ShopPriceButton",
			Note = "Bonks, Robux text, stacked, red, grape, disabled",
			Size = Vector2.new(980, 240),
			Element = c(PriceButtons),
		},
		{
			Name = "Arena ActionButton",
			Note = "Primary, secondary, completed, disabled",
			Size = Vector2.new(1040, 120),
			Element = c(ActionButtons),
		},
	},
})
