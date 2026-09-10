-- Description: Animated modal that presents the daily reward claim: spring entrance, 7-day progress strip, reward display, and a dismiss button.

--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local DeviceClass = require(script.Parent.Parent.Parent.Game.Input.DeviceClass)
local Selection = require(script.Parent.Parent.Services.Selection)

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Palette = UIConfig.ProgressionStyle

local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)

local modalSurface = require(script.Parent.ModalSurface)

local c = React.createElement

local Surface = require(script.Parent.Arena.Surface)
local artwork = UIConfig.LobbyArtwork.Action

export type PublicDay = {
	day: number,
	reward: { kind: string, amount: number?, itemId: string? },
	claimed: boolean,
	available: boolean,
	current: boolean,
}

export type PublicState = {
	canClaim: boolean,
	currentDay: number,
	nextDay: number,
	days: { PublicDay },
	totalClaimed: number,
}

export type Props = {
	Visible: boolean,
	State: PublicState?,
	OnClaim: (() -> ())?,
	Pending: boolean?,
	ErrorText: string?,
	FocusEnabled: boolean?,
	OnClose: (() -> ())?,
}

local function label(text: string, position: UDim2, size: UDim2, maximum: number, left: boolean?)
	return c(ResponsiveText, {
		MeasurementFont = Enum.Font.LuckiestGuy,
		MaxTextSize = maximum,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = Enum.Font.LuckiestGuy,
			Text = text,
			TextColor3 = Palette.White,
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			ZIndex = 3,
		},
	}, {
		Outline = c(
			"UIStroke",
			{ Color = Palette.Ink, Thickness = 0.045, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize }
		),
	})
end

local function MiniDay(dayProps: { Day: PublicDay, Order: number })
	local day = dayProps.Day
	local claimed = day.claimed and not day.available
	return c("Frame", {
		BackgroundColor3 = if day.available then Palette.Pink else Palette.Claimed,
		BorderSizePixel = 0,
		LayoutOrder = dayProps.Order,
		Size = UDim2.new(1 / 7, -36 / 7, 1, 0),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Tile) }),
		Outline = c(
			"UIStroke",
			{ Color = Palette.White, Thickness = 1.5, Transparency = if day.available then 0 else 0.45 }
		),
		Number = if claimed
			then c("ImageLabel", {
				BackgroundTransparency = 1,
				Image = "rbxassetid://168702841",
				ImageColor3 = Palette.White,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.55, 0.65),
				ScaleType = Enum.ScaleType.Fit,
			})
			else label(tostring(day.day), UDim2.fromOffset(2, 1), UDim2.new(1, -4, 1, -2), 23),
	})
end

return function(props: Props)
	local actionRef = React.useRef(nil)
	React.useEffect(function()
		if not props.Visible or props.FocusEnabled == false then
			return
		end
		local previous = GuiService.SelectedObject
		local panel = if actionRef.current then actionRef.current.Parent else nil
		local active = true
		local function focus()
			local button = actionRef.current
			if not active or DeviceClass.current() ~= "Gamepad" or not Selection.isSelectable(button) then
				return
			end
			local selected = GuiService.SelectedObject
			if selected and not selected:IsDescendantOf(Players.LocalPlayer.PlayerGui) then
				return
			end
			local ownRoot = button:FindFirstAncestorWhichIsA("ScreenGui")
			local selectedRoot = if selected then selected:FindFirstAncestorWhichIsA("ScreenGui") else nil
			if selectedRoot and ownRoot and selectedRoot.DisplayOrder > ownRoot.DisplayOrder then
				return
			end
			if not (selected and panel and selected:IsDescendantOf(panel) and Selection.isSelectable(selected)) then
				GuiService.SelectedObject = button
			end
		end
		local disconnect = DeviceClass.observe(function(input)
			if input == "Gamepad" then
				task.defer(focus)
			end
		end)
		return function()
			active = false
			disconnect()
			local selected = GuiService.SelectedObject
			if
				DeviceClass.current() == "Gamepad"
				and (selected == nil or (panel and selected:IsDescendantOf(panel)))
				and Selection.isSelectable(previous)
			then
				GuiService.SelectedObject = previous
			end
		end
	end, { props.Visible, props.FocusEnabled })
	local reducedMotion = useReducedMotion()
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local panelSize = ResponsiveLayout.panelSize(
		safeArea.size,
		UIConfig.Layout.Panels.DailyReward,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local claimed = props.State ~= nil and not props.State.canClaim
	local styles = ReactSpring.useSpring({
		Scale = if props.Visible then 1 else 0.82,
		Rotation = if props.Visible then 0 else -2,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	local rewardStyles = ReactSpring.useSpring({
		Scale = if claimed then 1.04 else 1,
		config = Motion.Pop,
		immediate = reducedMotion,
	})

	if not props.Visible then
		return nil
	end

	local state = props.State
	if state == nil then
		return nil
	end

	local currentReward: { kind: string, amount: number?, itemId: string? }? = nil
	local currentDayNumber = if state.canClaim then state.nextDay else state.currentDay
	for _, day in state.days do
		if day.day == currentDayNumber then
			currentReward = day.reward
			break
		end
	end

	local width = math.min(520, math.max(420, panelSize.X), safeArea.size.X - 24)
	local height = math.min(360, math.max(280, panelSize.Y), safeArea.size.Y - 24)
	local compact = height < 300
	local padding = if height < 240 then 10 else if compact then 16 else 24
	local gap = if height < 240 then 8 else if compact then 12 else 16
	local dayHeight = if height < 240 then 24 else if compact then 30 else 36
	local actionHeight = if height < 240 then 44 else if compact then 48 else 52
	local innerWidth = width - padding * 2
	local dayY = padding + 44 + gap
	local rewardY = dayY + dayHeight + gap
	local actionY = height - padding - actionHeight
	local rewardHeight = actionY - gap - rewardY
	local enabled = not props.Pending and props.FocusEnabled ~= false
	local miniDays = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	}
	for index, day in state.days do
		miniDays[`Day{index}`] = c(MiniDay, { Day = day, Order = index })
	end
	return modalSurface({
		Active = true,
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.35,
		ZIndex = 120,
	}, {
		Panel = c(Surface, {
			Color = Palette.Panel,
			Radius = UIConfig.Radius.Panel,
			Native = {
				Active = true,
				ZIndex = 121,
				SelectionGroup = true,
				SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
				SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
				SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
				SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(
					safeArea.position.X + safeArea.size.X / 2,
					safeArea.position.Y + safeArea.size.Y / 2
				),
				Size = UDim2.fromOffset(width, height),
				Rotation = styles.Rotation,
			},
		}, {
			ModalScale = c("UIScale", { Scale = styles.Scale }),
			Title = label(
				"DAILY REWARDS",
				UDim2.fromOffset(padding, padding + 2),
				UDim2.fromOffset(innerWidth - 44 - gap, 40),
				if compact then 29 else 34,
				true
			),
			CloseButton = c(AnimatedButton, {
				ButtonRef = actionRef,
				SelectionRadius = UDim.new(0, artwork.CornerPx),
				Enabled = props.OnClose ~= nil and props.FocusEnabled ~= false,
				OnActivated = props.OnClose,
				Native = {
					BackgroundTransparency = 1,
					Image = artwork.Pink,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = artwork.PinkSlice,
					SliceScale = artwork.SliceScale,
					Position = UDim2.fromOffset(width - padding - 44, padding),
					Size = UDim2.fromOffset(44, 44),
					ZIndex = 4,
				},
			}, { Label = label("X", UDim2.fromOffset(0, 1), UDim2.fromScale(1, 1), 30) }),
			DayStrip = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(padding, dayY),
				Size = UDim2.fromOffset(innerWidth, dayHeight),
			}, miniDays),
			RewardArea = c(Surface, {
				Color = Palette.Claimed,
				Radius = UIConfig.Radius.Control,
				Shadow = false,
				StrokeTransparency = 0.55,
				Native = {
					Position = UDim2.fromOffset(padding, rewardY),
					Size = UDim2.fromOffset(innerWidth, rewardHeight),
				},
			}, {
				Status = label(
					props.ErrorText or (if claimed then "CLAIMED!" else `DAY {currentDayNumber}`),
					UDim2.fromOffset(10, 6),
					UDim2.new(1, -20, 0, 22),
					if props.ErrorText then 16 else 20
				),
				Reward = if currentReward and currentReward.kind == "Bonks"
					then c(BonksLabel, {
						Amount = currentReward.amount or 0,
						MaxTextSize = if compact then 52 else 68,
						TextColor = Palette.White,
						TextStroke = 0.045,
						Native = { Position = UDim2.fromOffset(12, 27), Size = UDim2.new(1, -24, 1, -33), ZIndex = 3 },
					}, { Pop = c("UIScale", { Scale = rewardStyles.Scale }) })
					else nil,
			}),
			ActionButton = c(AnimatedButton, {
				SelectionRadius = UDim.new(0, artwork.CornerPx),
				Enabled = enabled and (if state.canClaim then props.OnClaim ~= nil else props.OnClose ~= nil),
				Style = "Primary",
				OnActivated = if state.canClaim then props.OnClaim else props.OnClose,
				Native = {
					BackgroundTransparency = 1,
					Image = if state.canClaim then artwork.Pink else artwork.Cyan,
					ImageColor3 = if enabled then Palette.White else Color3.fromRGB(140, 140, 140),
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = if state.canClaim then artwork.PinkSlice else artwork.CyanSlice,
					SliceScale = artwork.SliceScale,
					Position = UDim2.fromOffset(padding, actionY),
					Size = UDim2.fromOffset(innerWidth, actionHeight),
					ZIndex = 4,
				},
			}, {
				Label = label(
					if props.Pending then "CLAIMING…" elseif state.canClaim then "CLAIM" else "DONE",
					UDim2.fromOffset(10, 2),
					UDim2.new(1, -20, 1, -4),
					if compact then 28 else 32
				),
			}),
		}),
	})
end
