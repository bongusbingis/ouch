--[[
    The small stamped stickers and the Bonks readouts, at their real sizes.

    States:
      Badge      -- check (default yellow, -10 deg tilt), slot number, NEW!, lock, every candy
                    colour, white text on pink/grape, small (SmallBadgeSize) and upright.
                    The stamp animation (Motion.stampBadge) plays on mount.
      BonksChip  -- the cream wallet pill at 0, 2,450, 12,500 (one coin at every amount) and
                    1,250,000, plus a taller 56 px chip.
      BonksLabel -- the coin + amount line: ink and white text, Framed, and a large amount.
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Sheet = require(script.Parent.Sheet)

local React = StoryRoot.React
local Components = StoryRoot.Components
local T = StoryRoot.Tokens
local C = T.Colors
local c = React.createElement

local Badge = require(Components:WaitForChild("Badge"))
local BonksChip = require(Components:WaitForChild("BonksChip"))
local BonksLabel = require(Components:WaitForChild("BonksLabel"))

local BIG = Vector2.new(T.Layout.BadgeSize, T.Layout.BadgeSize)
local SMALL = Vector2.new(T.Layout.SmallBadgeSize, T.Layout.SmallBadgeSize)

local function badge(order: number, label: string, size: Vector2, props: { [string]: any }): any
	return Sheet.slot(
		order,
		label,
		Vector2.new(math.max(size.X, 96), size.Y),
		c(Badge, Sheet.merge({ Native = { Size = UDim2.fromOffset(size.X, size.Y) } }, props))
	)
end

local function Badges()
	return Sheet.sheet({
		badge(1, "CHECK", BIG, {}),
		badge(2, "SLOT 2", BIG, { Text = "2" }),
		badge(3, "NEW!", Vector2.new(64, 38), { Text = "NEW!", TextSize = T.Type.Minimum }),
		badge(4, "LOCK", BIG, { Lock = true }),
		badge(5, "PINK", BIG, { Color = C.Pink, Text = "!", TextColor = C.Surface }),
		badge(6, "CYAN", BIG, { Color = C.Cyan, Text = "3" }),
		badge(7, "LIME", BIG, { Color = C.Lime }),
		badge(8, "GRAPE", BIG, { Color = C.Grape, Text = "★", TextColor = C.Surface }),
		badge(9, "SMALL", SMALL, { Text = "1", TextSize = T.Type.Minimum }),
		badge(10, "UPRIGHT", BIG, { Tilt = 0 }),
	})
end

local function Chips()
	local function chip(order: number, amount: number, height: number?): any
		local caption = if height then `{amount} · {height}PX` else tostring(amount)
		return Sheet.slot(
			order,
			caption,
			Vector2.new(220, height or T.Layout.MinTarget),
			c(BonksChip, { Amount = amount, HeightPx = height })
		)
	end
	return Sheet.sheet({ chip(1, 0), chip(2, 2450), chip(3, 12500), chip(4, 1250000), chip(5, 2450, 56) })
end

local function Labels()
	local function label(order: number, caption: string, size: Vector2, props: { [string]: any }): any
		return Sheet.slot(
			order,
			caption,
			size,
			c(BonksLabel, Sheet.merge({ Native = { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 } }, props))
		)
	end
	return Sheet.sheet({
		label(1, "150 · INK", Vector2.new(160, 36), { Amount = 150, TextColor = C.Ink, TextStroke = 0 }),
		label(2, "2,450 · WHITE", Vector2.new(180, 36), { Amount = 2450 }),
		label(3, "FRAMED", Vector2.new(200, 44), { Amount = 5000, Framed = true }),
		label(4, "1,250,000 · LARGE", Vector2.new(280, 56), { Amount = 1250000, MaxTextSize = 40 }),
	})
end

return StoryRoot.story({
	Title = "Badges & Bonks",
	Summary = "Badge stickers (check, number, NEW!, lock, colours, small) and the Bonks wallet chip and label.",
	States = {
		{
			Name = "Badge",
			Note = "Stamp animation plays on mount",
			Size = Vector2.new(1260, 120),
			Element = c(Badges),
		},
		{
			Name = "BonksChip",
			Note = "Same coin at every amount",
			Size = Vector2.new(1260, 130),
			Element = c(Chips),
		},
		{
			Name = "BonksLabel",
			Note = "Ink, white, framed, large",
			Size = Vector2.new(1000, 130),
			Element = c(Labels),
		},
	},
})
