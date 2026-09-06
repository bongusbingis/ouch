-- Name: SplashPage.luau
-- Author: Jack C.
-- Description: The lobby splash page with the play action and party status, the first screen a player sees in the lobby.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local DailyRewardsPanel = require(script.Parent.DailyRewardsPanel)
local PartyStatus = require(script.Parent.PartyStatus)
local QuestsPanel = require(script.Parent.QuestsPanel)
local ResponsiveText = require(script.Parent.ResponsiveText)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local SeasonStatusCard = require(script.Parent.SeasonStatusCard)

local c = React.createElement

local function buttonText(text: string)
	return c(ResponsiveText, {
		MeasurementFont = Enum.Font.LuckiestGuy,
		MaxTextSize = 40,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
			Position = UDim2.fromScale(0.5, 0.53533),
			Size = UDim2.fromScale(0.9, 0.614132),
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 2,
		},
	})
end

export type Props = {
	PartyState: string,
	ShowMatchmakingActivity: boolean,
	PlayText: string,
	PlayEnabled: boolean,
	OnPlay: () -> (),
	OnInvite: () -> (),
	OnJoinCode: () -> (),
	Position: any?,
	PlayButtonRef: any?,
	DailyReward: any?,
	OnViewDailyReward: (() -> ())?,
	SeasonState: any?,
	QuestState: any?,
	OnClaimQuest: ((questId: string) -> ())?,
	OnClaimSeason: (() -> ())?,
	PendingClaims: { [string]: boolean }?,
}

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	local short = not portrait and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx
	local progressPanels = ResponsiveLayout.splashPanels(
		safeArea.size,
		UIConfig.Layout.Splash.ProgressPanels,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local compactProgressPanels = progressPanels.portrait
		or safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx
	return c("Frame", {
		BackgroundTransparency = 1,
		Position = props.Position or UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
	}, {
		BottomRight = c("Frame", {
			AnchorPoint = if portrait then Vector2.new(0.5, 1) else Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = if short
				then UDim2.new(1, -12, 1, -UIConfig.Layout.Splash.ShortActionsBottomPx)
				else if portrait then UDim2.fromScale(0.5, 0.98) else UDim2.fromScale(1, 1),
			Size = if short
				then UDim2.new(1, -24, 0, UIConfig.Layout.Splash.ShortActionsHeightPx)
				else if portrait
					then UDim2.new(0.9, 0, 0, UIConfig.Layout.Splash.PortraitActionsHeightPx)
					else UDim2.fromScale(0.424534, 0.564113),
		}, {
			Status = if not short and not portrait
				then c("Frame", {
					BackgroundTransparency = 1,
					LayoutOrder = -1,
					Size = UDim2.new(0.8, 0, 0, 32),
				}, { Label = c(PartyStatus, { Text = props.PartyState, Active = props.ShowMatchmakingActivity }) })
				else nil,
			UIListLayout = if portrait
				then nil
				else c("UIListLayout", {
					FillDirection = if short then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
					HorizontalAlignment = if portrait
						then Enum.HorizontalAlignment.Center
						else Enum.HorizontalAlignment.Right,
					Padding = if short
						then UDim.new(0.02, 0)
						else if portrait then UDim.new(0, 8) else UDim.new(0.01, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = if short then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Bottom,
				}),
			UIPadding = c("UIPadding", {
				PaddingBottom = UDim.new(0.05, 0),
				PaddingRight = if short or portrait then UDim.new(0, 0) else UDim.new(0.05, 0),
			}),
			InviteFriends = c(AnimatedButton, {
				Native = {
					BackgroundTransparency = 1,
					Image = "rbxassetid://123095501298848",
					LayoutOrder = 1,
					Position = if portrait then UDim2.fromScale(0.025, 0) else UDim2.fromScale(0.343431, 0.675873),
					ScaleType = Enum.ScaleType.Slice,
					Size = if short
						then UDim2.new(0.26, 0, 0, UIConfig.Layout.Splash.ShortActionButtonHeightPx)
						else if portrait
							then UDim2.new(0.45, 0, 0, UIConfig.Layout.Splash.SecondaryActionHeightPx)
							else UDim2.new(
								0.6,
								0,
								0,
								math.max(UIConfig.Interaction.MinTargetPx, safeArea.size.X * 0.424534 * 0.6 / 5.44)
							),
					SliceCenter = Rect.new(59, 31, 370, 78),
					SliceScale = 0.9,
				},
				OnActivated = props.OnInvite,
			}, {

				TextLabel = buttonText("INVITE FRIENDS"),
			}),
			JoinWithCode = c(AnimatedButton, {
				Native = {
					BackgroundTransparency = 1,
					Image = "rbxassetid://112649977890456",
					Position = if portrait then UDim2.fromScale(0.525, 0) else UDim2.fromScale(0.343431, 0.533477),
					ScaleType = Enum.ScaleType.Slice,
					Size = if short
						then UDim2.new(0.26, 0, 0, UIConfig.Layout.Splash.ShortActionButtonHeightPx)
						else if portrait
							then UDim2.new(0.45, 0, 0, UIConfig.Layout.Splash.SecondaryActionHeightPx)
							else UDim2.new(
								0.6,
								0,
								0,
								math.max(UIConfig.Interaction.MinTargetPx, safeArea.size.X * 0.424534 * 0.6 / 5.44)
							),
					SliceCenter = Rect.new(59, 31, 370, 78),
					SliceScale = 0.9,
				},
				OnActivated = props.OnJoinCode,
			}, {

				TextLabel = buttonText("JOIN PARTY"),
			}),
			PlayButton = c(AnimatedButton, {
				ButtonRef = props.PlayButtonRef,
				Enabled = props.PlayEnabled,
				Style = "Primary",
				Native = {
					AutoButtonColor = props.PlayEnabled,
					BackgroundTransparency = 1,
					Image = "rbxassetid://94748581468730",
					ImageColor3 = if props.PlayEnabled then Color3.new(1, 1, 1) else Color3.fromRGB(110, 110, 110),
					LayoutOrder = 2,
					AnchorPoint = if portrait then Vector2.new(0.5, 1) else Vector2.zero,
					Position = if portrait then UDim2.fromScale(0.5, 1) else UDim2.fromScale(-0.0570855, 0.787143),
					ScaleType = Enum.ScaleType.Slice,
					Size = if short
						then UDim2.new(0.44, 0, 0, UIConfig.Layout.Splash.ShortActionButtonHeightPx)
						else if portrait
							then UDim2.new(0.96, 0, 0, UIConfig.Layout.Splash.PrimaryActionHeightPx)
							else UDim2.fromScale(0.8, 0.8),
					SliceCenter = Rect.new(198, 228, 841, 468),
					SliceScale = 0.2,
				},
				OnActivated = props.OnPlay,
			}, {
				TextLabel = c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					MaxTextSize = 50,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.453406, 0.599863),
						Size = UDim2.fromScale(0.481093, 0.6712),
						Text = props.PlayText,
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 2,
					},
				}),
				UIAspectRatioConstraint = if short or portrait
					then nil
					else c("UIAspectRatioConstraint", { AspectRatio = 4.35 }),
				ImageLabel = c("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = if props.PlayText == "PLAY"
						then "rbxassetid://8517323790"
						else "rbxassetid://103344771690872",
					LayoutOrder = 2,
					Position = UDim2.fromScale(if props.PlayText == "PLAY" then 0.686431 else 0.765, 0.52),
					Size = UDim2.fromScale(0.100552, 0.421535),
				}),
			}),
		}),
		BottomMiddle = if short or portrait
			then c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = if short
					then UDim2.new(0.5, 0, 1, -72)
					else if portrait then UDim2.fromScale(0.5, 0.72) else UDim2.fromScale(0.445346, 1),
				Size = if short
					then UDim2.new(0.3, 0, 0, 28)
					else if portrait then UDim2.fromScale(0.9, 0.18) else UDim2.fromScale(0.409947, 0.564113),
			}, {
				PartyStatus = c(PartyStatus, {
					Text = props.PartyState,
					Active = props.ShowMatchmakingActivity,
				}),
			})
			else nil,
		Logo = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = "rbxassetid://78333957912633",
			Position = if short
				then UDim2.fromOffset(12, UIConfig.Layout.Splash.ShortLogoTopPx)
				else if portrait then UDim2.fromScale(0.05, 0.09) else UDim2.fromScale(0, 0.1),
			Size = if short
				then UDim2.fromOffset(150, 60)
				else if portrait then UDim2.fromScale(0.42, 0.14) else UDim2.fromScale(0.321542, 0.301659),
		}, {
			uIAspectRatioConstraint = c("UIAspectRatioConstraint", {
				AspectRatio = 1.55,
			}),
		}),
		DailyRewards = c(DailyRewardsPanel, {
			Compact = compactProgressPanels or progressPanels.daily.size.X < UIConfig.Layout.DailyCell.MinWidthPx * 7,
			Native = {
				Position = UDim2.fromOffset(progressPanels.daily.position.X, progressPanels.daily.position.Y),
				Size = UDim2.fromOffset(progressPanels.daily.size.X, progressPanels.daily.size.Y),
			},
			State = props.DailyReward,
			OnClaim = props.OnViewDailyReward,
		}),
		SeasonStatus = c(SeasonStatusCard, {
			Compact = compactProgressPanels or progressPanels.season.size.Y < UIConfig.Layout.SeasonDetailedMinHeightPx,
			Native = {
				Position = UDim2.fromOffset(progressPanels.season.position.X, progressPanels.season.position.Y),
				Size = UDim2.fromOffset(progressPanels.season.size.X, progressPanels.season.size.Y),
			},
			State = props.SeasonState,
			OnClaim = props.OnClaimSeason,
			Pending = props.PendingClaims and props.PendingClaims.Season,
		}),
		Quests = c(QuestsPanel, {
			Short = short,
			Compact = compactProgressPanels,
			Native = {
				Position = UDim2.fromOffset(progressPanels.quests.position.X, progressPanels.quests.position.Y),
				Size = UDim2.fromOffset(progressPanels.quests.size.X, progressPanels.quests.size.Y),
			},
			State = props.QuestState,
			OnClaim = props.OnClaimQuest,
			PendingClaims = props.PendingClaims,
		}),
	})
end
