--[[
    TabPill, the tilted candy tab used by the Backpack, Shop and progression hub. Shown at the
    Backpack's real tab size so tilt, fill and text size read as they do in game.

    States:
      TabPill states -- active (pink, white text), inactive (surface, ink text), disabled (no data
                        yet), forced upright (Tilt = 0, the short-landscape layout), and the
                        compact label size (T.Type.Minimum).
      Backpack row   -- the real Backpack tab list (Config.Cosmetics.Inventory.Tabs) as a live,
                        clickable row: click a tab to move the active state. Default tilt
                        alternates by LayoutOrder, exactly as the Backpack lays it out.

    Hover/press motion is live; hover any pill.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)
local Sheet = require(script.Parent.Sheet)

local React = StoryRoot.React
local T = StoryRoot.Tokens
local c = React.createElement

local TabPill = require(StoryRoot.Components:WaitForChild("TabPill"))
local Inventory = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))

local TAB = Vector2.new(170, T.Layout.TabHeight)
local log = Fixtures.log("Tabs", "tab")

local function pill(order: number, label: string, props: { [string]: any }): any
	return Sheet.slot(
		order,
		label,
		TAB,
		c(
			TabPill,
			Sheet.merge({
				Text = "SKINS",
				Native = { Size = UDim2.fromScale(1, 1), LayoutOrder = 1 },
				OnActivated = function()
					log(label)
				end,
			}, props)
		)
	)
end

local function Singles()
	return Sheet.sheet({
		pill(1, "ACTIVE", { Active = true }),
		pill(2, "INACTIVE", { Active = false }),
		pill(3, "DISABLED", { Enabled = false }),
		pill(4, "UPRIGHT (TILT 0)", { Active = true, Tilt = 0 }),
		pill(5, "COMPACT TEXT", { Text = "EFFECTS", TextSize = T.Type.Minimum }),
	})
end

local function BackpackRow()
	local selected, setSelected = React.useState(Inventory.Tabs[1].Id)
	local children: { [string]: any } = {
		Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 24), PaddingTop = UDim.new(0, 24) }),
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, T.Layout.CompactGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for order, definition in Inventory.Tabs do
		children[definition.Id] = c(TabPill, {
			Active = selected == definition.Id,
			Text = definition.Id,
			Native = { LayoutOrder = order, Size = UDim2.fromOffset(TAB.X, TAB.Y) },
			OnActivated = function()
				setSelected(definition.Id)
				log(definition.Id)
			end,
		})
	end
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, children)
end

return StoryRoot.story({
	Title = "Tabs",
	Summary = "TabPill in every state, and the Backpack's real tab row (click to switch).",
	States = {
		{
			Name = "TabPill states",
			Note = "Active, inactive, disabled, upright, compact text",
			Size = Vector2.new(1040, 120),
			Element = c(Singles),
		},
		{
			Name = "Backpack tab row",
			Note = "Config.Cosmetics.Inventory.Tabs; click a tab",
			Size = Vector2.new(980, 110),
			Element = c(BackpackRow),
		},
	},
})
