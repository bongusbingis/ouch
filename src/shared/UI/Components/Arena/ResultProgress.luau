-- Personal match rewards remain a read-only projection, including delayed persistence.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local T = require(script.Parent.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Parent.Motion)
local Model = require(script.Parent.Parent.Parent.Models.PostMatchViewModel)
local formatNumber = require(script.Parent.Parent.Parent.Models.NumberText)
local useReducedMotion = require(script.Parent.Parent.Parent.Hooks.useReducedMotion)
local Badge = require(script.Parent.Parent.Badge)
local CandyPanel = require(script.Parent.Parent.CandyPanel)
local CandyProgressBar = require(script.Parent.Parent.CandyProgressBar)
local CandySurface = require(script.Parent.Parent.CandySurface)
local c, C, R = React.createElement, T.Colors, T.Results

-- The one Bonks glyph, identical to the coin BonksLabel draws beside every other amount.
local COIN = "rbxassetid://106703644238993"
local function text(props: { [string]: any })
	local native = table.clone(props)
	native.BackgroundTransparency = 1
	native.Font = native.Font or T.Type.Label
	native.TextColor3 = native.TextColor3 or C.Ink
	native.TextTruncate = if native.TextWrapped then nil else Enum.TextTruncate.AtEnd
	native.ZIndex = native.ZIndex or 16
	return c("TextLabel", native)
end

local function chip(color: Color3, lip: Color3, native: { [string]: any }, children)
	native.BackgroundTransparency = 1
	native.ZIndex = 15
	return c("Frame", native, {
		Surface = c(CandySurface, {
			Color = color,
			LipColor = lip,
			Radius = T.Shape.RadiusCard,
			Shadow = false,
			ZIndex = 15,
		}),
		Content = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -T.Shape.LipHeight),
			ZIndex = 18,
		}, children),
	})
end

local function rewardChips(rewards, height: number, order: number, widthOffset: number)
	local textSize = if height < 56 then 20 else 24
	return c(
		"Frame",
		{ BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.new(1, -widthOffset, 0, height) },
		{
			XP = chip(C.Cyan, C.CyanLip, { Size = UDim2.new(0.5, -4, 1, 0) }, {
				Amount = text({
					Font = T.Type.Display,
					Text = `+{formatNumber(rewards.matchXp)} XP`,
					TextSize = textSize,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 19,
				}),
			}),
			Bonks = chip(
				C.Yellow,
				C.YellowLip,
				{ Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0) },
				{
					Layout = c("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Coin = c("ImageLabel", {
						BackgroundTransparency = 1,
						Image = COIN,
						LayoutOrder = 1,
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromOffset(textSize, textSize),
						ZIndex = 19,
					}),
					Amount = text({
						AutomaticSize = Enum.AutomaticSize.X,
						Font = T.Type.Display,
						LayoutOrder = 2,
						Text = `+{formatNumber(rewards.bonks)}`,
						TextSize = textSize,
						Size = UDim2.fromScale(0, 1),
						ZIndex = 19,
					}),
				}
			),
		}
	)
end

local function boostLine(rewards, order: number, widthOffset: number)
	local parts = {}
	-- A boost line only makes sense under a reward it actually multiplied.
	if rewards.xpMultiplier and rewards.xpMultiplier > 1 and rewards.matchXp > 0 then
		table.insert(parts, `×{rewards.xpMultiplier} XP`)
	end
	if rewards.bonksMultiplier and rewards.bonksMultiplier > 1 and rewards.bonks > 0 then
		table.insert(parts, `×{rewards.bonksMultiplier} BONKS`)
	end
	if #parts == 0 then
		return nil
	end
	return text({
		LayoutOrder = order,
		Text = table.concat(parts, " · ") .. " BOOST APPLIED",
		TextColor3 = C.InkSoft,
		TextSize = T.Type.HudMinimum,
		Size = UDim2.new(1, -widthOffset, 0, 20),
	})
end

local function pendingChip(saving: boolean, height: number, order: number, widthOffset: number)
	return chip(C.Well, C.WellLine, { LayoutOrder = order, Size = UDim2.new(1, -widthOffset, 0, height) }, {
		Label = text({
			Text = if saving then "SAVING YOUR REWARDS…" else "LOADING YOUR REWARDS…",
			TextColor3 = C.InkSoft,
			TextSize = T.Type.HudMinimum,
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 20),
			ZIndex = 19,
		}),
		Bar = c(CandyProgressBar, {
			Progress = 1,
			Animated = true,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(0.7, 0, 0, 10),
				ZIndex = 19,
			},
		}),
	})
end

local function statRow(stat, rowHeight: number, order: number)
	local value = Model.statText(stat)
	local valueWidth = if rowHeight < 36 then 70 else 84
	return c("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.new(1, 0, 0, rowHeight) }, {
		Name = text({
			Text = stat.label,
			TextColor3 = C.InkSoft,
			TextSize = if rowHeight < 36 then T.Type.HudMinimum else 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -valueWidth - 20, 1, 0),
		}),
		Value = if stat.highlight
			then c("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -4, 0.5, 0),
				Size = UDim2.new(0, valueWidth, 1, -6),
				ZIndex = 16,
			}, {
				Surface = c(CandySurface, { Color = C.Yellow, LipColor = C.YellowLip, Shadow = false, ZIndex = 16 }),
				Text = text({
					Font = T.Type.Display,
					Text = value,
					TextSize = if rowHeight < 36 then 17 else 20,
					Size = UDim2.new(1, 0, 1, -T.Shape.LipHeight),
					ZIndex = 20,
				}),
			})
			else text({
				AnchorPoint = Vector2.new(1, 0),
				Font = T.Type.Display,
				Text = value,
				TextSize = if rowHeight < 36 then 18 else 22,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(1, -8, 0, 0),
				Size = UDim2.new(0, valueWidth - 4, 1, 0),
			}),
	})
end

local function well(order: number, children, widthOffset: number)
	children.Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) })
	children.Outline = c("UIStroke", { Color = C.WellLine, Thickness = T.Shape.StrokeInner })
	children.Padding = c("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	children.Layout = c("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	return c("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Well,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1, -widthOffset, 0, 0),
		ZIndex = 15,
	}, children)
end

local function SeasonBlock(props)
	local season = props.Season
	local reveal = Model.seasonReveal(season)
	local badgeWidth = if props.Compact then 88 else 100
	local reduced = useReducedMotion()
	local styles, api = ReactSpring.useSpring(function()
		return { Progress = reveal.startFraction }
	end)
	local tierBadge, setTierBadge = React.useState(reduced and reveal.tierUp)
	React.useEffect(function()
		if not props.Shown then
			return nil
		end
		local active = true
		api.start({ Progress = reveal.endFraction, config = Motion.Modal, immediate = reduced }):andThen(function()
			if active and reveal.tierUp then
				setTierBadge(true)
			end
		end)
		return function()
			active = false
		end
	end, { props.Shown, props.Key })
	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, -props.WidthOffset, 0, R.SeasonHeight),
	}, {
		Title = text({
			Font = T.Type.Display,
			Text = if season.afterTier >= 1 then `SEASON TIER {season.afterTier}` else "SEASON PROGRESS",
			TextSize = if props.Compact then 18 else 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, if tierBadge then -badgeWidth - 10 else -4, 0, 26),
		}),
		TierUp = c(Badge, {
			Text = "TIER UP!",
			TextSize = T.Type.HudMinimum,
			Visible = tierBadge,
			Native = {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, -2),
				Size = UDim2.fromOffset(badgeWidth, 28),
				ZIndex = 20,
			},
		}),
		Bar = c(CandyProgressBar, {
			Progress = styles.Progress,
			Native = {
				Position = UDim2.fromOffset(0, 30),
				Size = UDim2.new(1, 0, 0, R.SeasonBarHeight),
				ZIndex = 16,
			},
		}),
		Caption = text({
			Text = `{formatNumber(season.xpIntoTier)} / {formatNumber(season.xpForNextTier)} XP`,
			TextColor3 = C.InkSoft,
			TextSize = T.Type.HudMinimum,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(0, 30 + R.SeasonBarHeight + 4),
			Size = UDim2.new(1, 0, 0, 20),
		}),
	})
end

return function(props)
	local result = props.Result
	local inset = props.Inset
	local rewards = result.rewards
	local scrollInset = R.PersonalScrollInset
	local widthOffset = scrollInset * 2 + T.Layout.ScrollBar + R.PersonalScrollClearance
	local stats = {}
	for _, stat in result.personalStats do
		if stat.id ~= "Placement" then
			table.insert(stats, stat)
		end
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local rows: { [string]: any } = {
		Layout = c("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, R.RowGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, scrollInset),
			PaddingBottom = UDim.new(0, scrollInset),
		}),
	}
	if rewards then
		rows.Rewards = rewardChips(rewards, props.ChipHeight, nextOrder(), widthOffset)
		rows.Boost = boostLine(rewards, nextOrder(), widthOffset)
	else
		rows.Pending = pendingChip(result.rewardsPending == true, props.ChipHeight, nextOrder(), widthOffset)
	end
	if #stats > 0 then
		local statChildren = {}
		for index, stat in stats do
			statChildren[stat.id] = statRow(stat, props.RowHeight, index)
		end
		rows.Stats = well(nextOrder(), statChildren, widthOffset)
	end
	if result.seasonProgress then
		rows.Season = c(SeasonBlock, {
			Season = result.seasonProgress,
			Shown = props.Shown,
			Key = result.resultId,
			LayoutOrder = nextOrder(),
			WidthOffset = widthOffset,
			Compact = props.RowHeight < 36,
		})
	end
	if result.challenges and #result.challenges > 0 then
		local challengeChildren = {}
		for index, challenge in result.challenges do
			challengeChildren[challenge.id] = statRow({
				id = challenge.id,
				label = challenge.label,
				value = challenge.current,
				highlight = challenge.complete,
			}, props.RowHeight, index)
		end
		rows.Challenges = well(nextOrder(), challengeChildren, widthOffset)
	end
	for _, unlock in result.unlocks or {} do
		rows["Unlock" .. unlock.id] = chip(
			C.SurfaceWarm,
			C.WellLine,
			{ LayoutOrder = nextOrder(), Size = UDim2.new(1, -widthOffset, 0, props.RowHeight + 8) },
			{
				Mark = c(Badge, {
					Text = "NEW",
					TextSize = T.Type.HudMinimum,
					Native = {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 6, 0.5, 0),
						Size = UDim2.fromOffset(56, 28),
						ZIndex = 20,
					},
				}),
				Label = text({
					Font = T.Type.Display,
					Text = `UNLOCKED · {unlock.name}`,
					TextSize = 18,
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(68, 0),
					Size = UDim2.new(1, -76, 1, 0),
					ZIndex = 19,
				}),
			}
		)
	end
	local top = inset + R.SectionHeight + 2
	return c(CandyPanel, { Native = { Size = UDim2.fromScale(1, 1), ZIndex = 12 } }, {
		Header = text({
			Font = T.Type.Display,
			Text = "YOUR ROUND",
			TextSize = if props.Inset < 16 then 22 else 26,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(inset + widthOffset / 2, inset - 6),
			Size = UDim2.new(1, -(inset + widthOffset / 2) * 2, 0, R.SectionHeight),
		}),
		Scroll = c("ScrollingFrame", {
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromOffset(inset, top),
			ScrollBarImageColor3 = C.Pink,
			ScrollBarThickness = T.Layout.ScrollBar,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Selectable = false,
			Size = UDim2.new(1, -inset * 2, 1, -top - inset),
			ZIndex = 14,
		}, rows),
	})
end
