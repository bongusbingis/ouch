--!strict
local T = require(script.Parent.Parent.Tokens)
-- Description: Animated modal that presents the daily reward claim: spring entrance, 7-day progress strip, reward display, and a dismiss button.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local AnimatedButton = require(script.Parent.PuffyButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local DeviceClass = require(script.Parent.Parent.Parent.Game.Input.DeviceClass)
local Selection = require(script.Parent.Parent.Services.Selection)

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))

local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)

local modalSurface = require(script.Parent.ModalSurface)

local Icon = require(script.Parent.Icon)
local ModalClose = require(script.Parent.ModalClose)
local CollectibleFace = require(script.Parent.CollectibleFace)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))

local c = React.createElement
local Title = require(script.Parent.CandyTitle)

local Surface = require(script.Parent.CandyPanel)
local K = T.Collectible

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

local function label(text: string, position: UDim2, size: UDim2, maximum: number, color: Color3?)
	local light = color == T.Colors.Surface
	return c(ResponsiveText, {
		MeasurementFont = T.Type.Display,
		MinTextSize = T.Type.Minimum,
		MaxTextSize = maximum,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = T.Type.Display,
			Text = text,
			TextColor3 = color or T.Colors.Ink,
			ZIndex = 3,
		},
	}, {
		Outline = if light then c("UIStroke", { Color = T.Colors.Ink, Thickness = T.Type.Outline }) else nil,
	})
end

-- Today is pink with a white outlined number, claimed days are lime with an ink
-- check, and days still to come stay pale with a soft ink number.
local function MiniDay(dayProps: { Day: PublicDay, Order: number })
	local day = dayProps.Day
	local claimed = day.claimed and not day.available
	local fill = if day.available then T.Colors.Pink elseif claimed then T.Colors.Lime else T.Colors.Surface
	return c("Frame", {
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		LayoutOrder = dayProps.Order,
		Size = UDim2.new(1 / 7, -36 / 7, 1, 0),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, K.WellRadius) }),
		Outline = c("UIStroke", {
			Color = if day.available or claimed then T.Colors.Ink else T.Colors.WellLine,
			Thickness = T.Shape.StrokeInner,
		}),
		Number = if claimed
			then c(Icon, {
				Name = "Check",
				Color = T.Colors.Ink,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.62, 0.62),
					ZIndex = 3,
				},
			}, { Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }) })
			else label(
				tostring(day.day),
				UDim2.fromOffset(2, 1),
				UDim2.new(1, -4, 1, -2),
				T.Type.TileLabel,
				if day.available then T.Colors.Surface else T.Colors.InkSoft
			),
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
	local actionText = if props.Pending then "CLAIMING…" elseif state.canClaim then "CLAIM" else "DONE"
	local rewardItem = if currentReward and currentReward.itemId then Cosmetics.Items[currentReward.itemId] else nil
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
		BackgroundColor3 = T.Colors.Ink,
		BackgroundTransparency = 0.35,
		ZIndex = 120,
	}, {
		Panel = c(Surface, {
			Color = T.Colors.SurfaceWarm,
			Radius = T.Shape.RadiusPanel,
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
			Title = c(Title, {
				Text = "DAILY REWARDS",
				TextSize = T.Type.ModalTitle,
				Native = {
					Position = UDim2.fromOffset(padding - 4, padding - 12),
					Size = UDim2.fromOffset(innerWidth - 54, 52),
					ZIndex = 10,
				},
			}),
			CloseButton = c(ModalClose, {
				ButtonRef = actionRef,
				Enabled = props.FocusEnabled ~= false,
				OnActivated = props.OnClose,
				Position = UDim2.new(1, -padding, 0, padding),
				ZIndex = 4,
			}),
			DayStrip = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(padding, dayY),
				Size = UDim2.fromOffset(innerWidth, dayHeight),
			}, miniDays),
			-- Today's prize is a collectible window: a tinted art well with the day (or
			-- CLAIMED!) on its seam tag, the same card language as every cosmetic.
			RewardArea = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(padding - K.Pad, rewardY - K.Pad),
				Size = UDim2.fromOffset(innerWidth + K.Pad * 2, rewardHeight + K.Pad * 2),
				ZIndex = 2,
			}, {
				Card = c(CollectibleFace, {
					Width = innerWidth + K.Pad * 2,
					Height = rewardHeight + K.Pad * 2,
					Rarity = if rewardItem then rewardItem.Rarity else nil,
					WellColor = if rewardItem then nil else T.Colors.Yellow:Lerp(T.Colors.Surface, K.WellTint),
					TagText = if claimed then "CLAIMED!" else `DAY {currentDayNumber}`,
					TagColor = if claimed then T.Colors.Lime else T.Colors.Pink,
					Art = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, {
						Error = if props.ErrorText
							then c("TextLabel", {
								BackgroundTransparency = 1,
								Size = UDim2.new(1, 0, 0, K.FooterHeight),
								Font = T.Type.Label,
								Text = props.ErrorText,
								TextSize = T.Type.Minimum,
								TextColor3 = T.Colors.Ink,
								TextTruncate = Enum.TextTruncate.AtEnd,
								ZIndex = 5,
							})
							else nil,
						Reward = if currentReward and currentReward.kind == "Bonks"
							then c(BonksLabel, {
								Amount = currentReward.amount or 0,
								MaxTextSize = if compact then 52 else 68,
								TextColor = T.Colors.Ink,
								TextStroke = 0,
								Native = {
									Position = UDim2.fromOffset(0, if props.ErrorText then K.FooterHeight else 0),
									Size = UDim2.new(1, 0, 1, if props.ErrorText then -K.FooterHeight else 0),
									ZIndex = 5,
								},
							}, { Pop = c("UIScale", { Scale = rewardStyles.Scale }) })
							elseif rewardItem then c("Frame", {
								BackgroundTransparency = 1,
								Position = UDim2.fromOffset(0, if props.ErrorText then K.FooterHeight else 0),
								Size = UDim2.new(1, 0, 1, if props.ErrorText then -K.FooterHeight else 0),
								ZIndex = 5,
							}, {
								Pop = c("UIScale", { Scale = rewardStyles.Scale }),
								Preview = c(ShopPreview, {
									Items = {
										{
											itemId = currentReward and currentReward.itemId,
											category = rewardItem.Category,
											definition = rewardItem,
										},
									},
									TextColor = T.Colors.Ink,
									TextStroke = 0,
									ZIndex = 6,
								}),
							})
							else nil,
					}),
					ZIndex = 3,
				}),
			}),
			-- The pink primary uses white outlined Fredoka like every other pink primary.
			ActionButton = c(AnimatedButton, {
				Text = actionText,
				TextSize = if compact then T.Type.Tab else T.Type.Section,
				TextColor = if state.canClaim then T.Colors.Surface else T.Colors.Ink,
				Color = if state.canClaim then T.Colors.Pink else T.Colors.Surface,
				LipColor = if state.canClaim then T.Colors.PinkLip else T.Colors.WellLine,
				Shadow = false,
				Enabled = enabled and (if state.canClaim then props.OnClaim ~= nil else props.OnClose ~= nil),
				Style = "Primary",
				OnActivated = if state.canClaim then props.OnClaim else props.OnClose,
				Native = {
					Position = UDim2.fromOffset(padding, actionY),
					Size = UDim2.fromOffset(innerWidth, actionHeight),
					ZIndex = 4,
				},
			}),
		}),
	})
end
