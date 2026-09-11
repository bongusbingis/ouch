-- Description: The lobby splash page with the play action and party status, the first screen a player sees in the lobby.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local ButtonSurface = require(script.Parent.ButtonSurface)
local DailyRewardsPanel = require(script.Parent.DailyRewardsPanel)
local PartyStatus = require(script.Parent.PartyStatus)
local QuestsPanel = require(script.Parent.QuestsPanel)
local ResponsiveText = require(script.Parent.ResponsiveText)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local TextMetrics = require(script.Parent.Parent.TextMetrics)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local usePreferredTextSize = require(script.Parent.Parent.Hooks.usePreferredTextSize)
local SeasonStatusCard = require(script.Parent.SeasonStatusCard)

local c = React.createElement
local artwork = UIConfig.LobbyArtwork.Action

local function actionText(
	text: string,
	size: Vector2,
	maximum: number,
	primary: boolean,
	preferredScale: number,
	fittingText: string?
)
	local iconWidth = if primary then artwork.IconPx else 0
	local iconGap = if primary then artwork.IconGapPx else 0
	local padding = math.clamp(size.X * artwork.WidthPaddingScale, artwork.MinPaddingPx, artwork.PaddingPx)
	local inner = size - Vector2.new(padding * 2 + iconWidth + iconGap, artwork.PaddingPx)
	local textSize = TextMetrics.fittingSize(
		fittingText or text,
		Enum.Font.LuckiestGuy,
		inner,
		1,
		math.round(maximum * preferredScale),
		false
	)
	local textWidth = TextService:GetTextSize(text, textSize, Enum.Font.LuckiestGuy, Vector2.new(100000, 100000)).X
	return c("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -artwork.ShadowPx / 2, 0.5, -artwork.ShadowPx / 2),
		Size = UDim2.fromOffset(textWidth + iconWidth + iconGap, size.Y - artwork.PaddingPx),
	}, {
		Label = c("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, artwork.TextOffsetY),
			Size = UDim2.new(0, textWidth, 1, 0),
			Font = Enum.Font.LuckiestGuy,
			Text = text,
			TextSize = textSize,
			TextColor3 = UIConfig.ProgressionStyle.White,
			ZIndex = 2,
		}),
		Icon = if primary
			then c("ImageLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(iconWidth, iconWidth),
				Image = if text == "PLAY" then "rbxassetid://8517323790" else "rbxassetid://103344771690872",
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			})
			else nil,
	})
end

local function buttonText(text: string, compact: boolean?)
	return c(ResponsiveText, {
		MeasurementFont = Enum.Font.LuckiestGuy,
		MinTextSize = if compact then 12 else 16,
		MaxTextSize = if compact then 14 else UIConfig.Layout.Splash.ActionTextPx,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, if compact then -8 else -16, 1, -8),
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 2,
		},
	}, {
		Outline = c("UIStroke", {
			Color = UIConfig.ProgressionStyle.Ink,
			Thickness = 0.045,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		}),
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
	WorldWindowRef: any?,
	DailyReward: any?,
	OnViewDailyReward: (() -> ())?,
	SeasonState: any?,
	QuestState: any?,
	OnClaimQuest: ((questId: string) -> ())?,
	OnClaimSeason: (() -> ())?,
	OnViewSeasonRewards: (() -> ())?,
	PendingClaims: { [string]: boolean }?,
}

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local preferred = usePreferredTextSize()
	local preferredScale = UIConfig.Text.PreferredScale[preferred.Name] or 1
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	local progressPanels = ResponsiveLayout.splashPanels(
		safeArea.size,
		UIConfig.Layout.Splash.ProgressPanels,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local short = not portrait and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx
	local compactProgressPanels = progressPanels.portrait or progressPanels.progressStack ~= nil
	local worldWindow = ResponsiveLayout.splashWorldWindow(safeArea.size, UIConfig.Layout)
	local stack = progressPanels.progressStack
	local tabbed = progressPanels.tabbed == true
	local selectedProgress, setSelectedProgress = React.useState("DAILY")
	local actionWidth = if stack
		then math.min(worldWindow.size.X, if short then 600 else 500)
		else progressPanels.season.size.X
	local actions = UIConfig.Layout.Splash
	local secondarySize = if short
		then Vector2.new(actionWidth * 0.26 - 8, actions.ShortActionButtonHeightPx)
		else if portrait
			then Vector2.new(safeArea.size.X * 0.9 * 0.45, actions.SecondaryActionHeightPx)
			else Vector2.new(actionWidth, actions.ActionHeightPx)
	local primarySize = if short
		then Vector2.new(actionWidth * 0.48 - 8, actions.ShortActionsHeightPx)
		else if portrait
			then Vector2.new(safeArea.size.X * 0.9 * 0.96, actions.PrimaryActionHeightPx)
			else Vector2.new(actionWidth, actions.DesktopPrimaryActionHeightPx)
	local secondaryTextSize = if short then actions.ShortActionTextPx else actions.ActionTextPx
	local secondaryFittingText = if short then "INVITE" else "INVITE FRIENDS"
	local tabHeight = 44
	local tabContentHeight = if stack then math.max(1, stack.size.Y - tabHeight - 12) else 0
	local gap = UIConfig.Layout.Splash.ProgressPanels.GapPx
	local seasonStatus = c(SeasonStatusCard, {
		Compact = compactProgressPanels or progressPanels.season.size.Y < UIConfig.Layout.SeasonDetailedMinHeightPx,
		Native = {
			LayoutOrder = 1,
			Position = if stack
				then nil
				else UDim2.fromOffset(progressPanels.season.position.X, progressPanels.season.position.Y),
			Size = if stack
				then UDim2.new(1, -gap * 2, 0, progressPanels.season.size.Y)
				else UDim2.fromOffset(progressPanels.season.size.X, progressPanels.season.size.Y),
		},
		State = props.SeasonState,
		OnClaim = props.OnClaimSeason,
		OnViewRewards = props.OnViewSeasonRewards,
		Pending = props.PendingClaims and props.PendingClaims.Season,
	})
	local quests = c(QuestsPanel, {
		Short = short,
		Compact = portrait or short,
		Expanded = false,
		Native = {
			LayoutOrder = 3,
			Position = if stack
				then nil
				else UDim2.fromOffset(progressPanels.quests.position.X, progressPanels.quests.position.Y),
			Size = if stack
				then UDim2.new(
					1,
					-gap * 2,
					0,
					if tabbed
						then tabContentHeight
						else math.max(
							44,
							stack.size.Y - progressPanels.season.size.Y - progressPanels.daily.size.Y - gap * 3.5
						)
				)
				else UDim2.fromOffset(progressPanels.quests.size.X, progressPanels.quests.size.Y),
		},
		State = props.QuestState,
		OnClaim = props.OnClaimQuest,
		PendingClaims = props.PendingClaims,
	})
	local dailyRewards = c(DailyRewardsPanel, {
		Compact = (if stack then stack.size.X - gap * 2 else progressPanels.daily.size.X)
			< UIConfig.Layout.DailyCell.FullWeekMinWidthPx,
		Summary = tabbed and tabContentHeight < UIConfig.Layout.Splash.ProgressPanels.DailyMinHeightPx,
		Native = {
			LayoutOrder = 2,
			Position = if stack
				then nil
				else UDim2.fromOffset(progressPanels.daily.position.X, progressPanels.daily.position.Y),
			Size = if stack
				then UDim2.new(
					1,
					-gap * 2,
					0,
					if tabbed
						then math.min(tabContentHeight, progressPanels.daily.size.Y)
						else progressPanels.daily.size.Y
				)
				else UDim2.fromOffset(progressPanels.daily.size.X, progressPanels.daily.size.Y),
		},
		State = props.DailyReward,
		OnClaim = props.OnViewDailyReward,
	})
	local progressTabs = {}
	for index, title in { "SEASON", "DAILY", "QUESTS" } do
		progressTabs[title] = c(AnimatedButton, {
			Visual = c(ButtonSurface, {
				Color = if selectedProgress == title
					then UIConfig.ProgressionStyle.Pink
					else UIConfig.ProgressionStyle.Ink,
				Radius = UDim.new(0, 8),
			}),
			SelectionRadius = UDim.new(0, 8),
			Native = {
				BackgroundTransparency = 1,
				Position = UDim2.new((index - 1) / 3, if index == 1 then 0 else 3, 0, 0),
				Size = UDim2.new(1 / 3, -6, 1, 0),
			},
			OnActivated = function()
				setSelectedProgress(title)
			end,
		}, { Label = buttonText(title, true) })
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Position = props.Position or UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
	}, {
		WorldWindow = c("Frame", {
			ref = props.WorldWindowRef,
			BackgroundTransparency = 1,
			Active = false,
			Position = UDim2.fromOffset(
				safeArea.position.X + worldWindow.position.X,
				safeArea.position.Y + worldWindow.position.Y
			),
			Size = UDim2.fromOffset(worldWindow.size.X, worldWindow.size.Y),
		}),
		BottomRight = c("Frame", {
			AnchorPoint = if stack
				then Vector2.new(0.5, 1)
				else if portrait then Vector2.new(0.5, 1) else Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = if stack
				then UDim2.new(
					0,
					worldWindow.position.X + worldWindow.size.X / 2,
					1,
					if short then -actions.ShortActionsBottomPx else -24
				)
				else if portrait then UDim2.fromScale(0.5, 0.98) else UDim2.new(1, -24, 1, -24),
			Size = if short
				then UDim2.fromOffset(actionWidth, UIConfig.Layout.Splash.ShortActionsHeightPx)
				else if portrait
					then UDim2.new(0.9, 0, 0, UIConfig.Layout.Splash.PortraitActionsHeightPx)
					else UDim2.fromOffset(
						actionWidth,
						actions.DesktopStatusHeightPx
							+ actions.ActionHeightPx * 2
							+ primarySize.Y
							+ actions.ActionsGapPx * 3
					),
		}, {
			Status = if not short and not portrait
				then c("Frame", {
					BackgroundTransparency = 1,
					LayoutOrder = -1,
					Size = UDim2.new(1, 0, 0, actions.DesktopStatusHeightPx),
				}, { Label = c(PartyStatus, { Text = props.PartyState, Active = props.ShowMatchmakingActivity }) })
				else nil,
			UIListLayout = if portrait
				then nil
				else c("UIListLayout", {
					FillDirection = if short then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = if short then UDim.new(0, 12) else UDim.new(0, UIConfig.Layout.Splash.ActionsGapPx),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = if short then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Bottom,
				}),
			UIPadding = c("UIPadding", {
				PaddingBottom = UDim.new(0, 0),
				PaddingRight = UDim.new(0, 0),
			}),
			InviteFriends = c(AnimatedButton, {
				SelectionRadius = UDim.new(0, artwork.CornerPx),
				Native = {
					BackgroundTransparency = 1,
					Image = artwork.Cyan,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = artwork.CyanSlice,
					SliceScale = artwork.SliceScale,
					LayoutOrder = 1,
					Position = if portrait then UDim2.fromScale(0.025, 0) else UDim2.fromScale(0.343431, 0.675873),
					Size = UDim2.fromOffset(secondarySize.X, secondarySize.Y),
				},
				OnActivated = props.OnInvite,
			}, {

				Content = actionText(
					if short then "INVITE" else "INVITE FRIENDS",
					secondarySize,
					secondaryTextSize,
					false,
					preferredScale,
					secondaryFittingText
				),
			}),
			JoinWithCode = c(AnimatedButton, {
				SelectionRadius = UDim.new(0, artwork.CornerPx),
				Native = {
					BackgroundTransparency = 1,
					Image = artwork.Cyan,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = artwork.CyanSlice,
					SliceScale = artwork.SliceScale,
					Position = if portrait then UDim2.fromScale(0.525, 0) else UDim2.fromScale(0.343431, 0.533477),
					Size = UDim2.fromOffset(secondarySize.X, secondarySize.Y),
				},
				OnActivated = props.OnJoinCode,
			}, {

				Content = actionText(
					if short then "JOIN" else "JOIN PARTY",
					secondarySize,
					secondaryTextSize,
					false,
					preferredScale,
					secondaryFittingText
				),
			}),
			PlayButton = c(AnimatedButton, {
				ButtonRef = props.PlayButtonRef,
				SelectionRadius = UDim.new(0, artwork.CornerPx),
				Enabled = props.PlayEnabled,
				Style = "Primary",
				Native = {
					AutoButtonColor = props.PlayEnabled,
					BackgroundTransparency = 1,
					Image = artwork.Pink,
					ImageColor3 = if props.PlayEnabled then Color3.new(1, 1, 1) else Color3.fromRGB(110, 110, 110),
					LayoutOrder = 2,
					AnchorPoint = if portrait then Vector2.new(0.5, 1) else Vector2.zero,
					Position = if portrait then UDim2.fromScale(0.5, 1) else UDim2.fromScale(-0.0570855, 0.787143),
					ScaleType = Enum.ScaleType.Slice,
					Size = UDim2.fromOffset(primarySize.X, primarySize.Y),
					SliceCenter = artwork.PinkSlice,
					SliceScale = artwork.SliceScale,
				},
				OnActivated = props.OnPlay,
			}, {
				Content = actionText(
					props.PlayText,
					primarySize,
					if portrait or short then actions.PrimaryActionTextPx else actions.DesktopPrimaryActionTextPx,
					true,
					preferredScale
				),
			}),
		}),
		BottomMiddle = if (short or portrait) and props.ShowMatchmakingActivity
			then c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = if short
					then UDim2.new(0, worldWindow.position.X + worldWindow.size.X / 2, 1, -70)
					else if portrait and stack
						then UDim2.fromOffset(safeArea.size.X / 2, stack.position.Y + stack.size.Y + 32)
						else UDim2.fromScale(0.445346, 1),
				Size = if short
					then UDim2.fromOffset(worldWindow.size.X, 24)
					else if portrait then UDim2.new(0.9, 0, 0, 24) else UDim2.fromScale(0.409947, 0.564113),
			}, {
				PartyStatus = c(PartyStatus, {
					Text = props.PartyState,
					Active = props.ShowMatchmakingActivity,
				}),
			})
			else nil,
		DailyRewards = if stack then nil else dailyRewards,
		SeasonStatus = if stack then nil else seasonStatus,
		Quests = if stack then nil else quests,
		ProgressStack = if stack and tabbed
			then c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(stack.position.X, stack.position.Y),
				Size = UDim2.fromOffset(stack.size.X, stack.size.Y),
			}, {
				Tabs = c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(gap, 0),
					Size = UDim2.new(1, -gap * 2, 0, tabHeight),
				}, progressTabs),
				Content = c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, tabHeight + 8),
					Size = UDim2.new(1, 0, 1, -tabHeight - 8),
				}, {
					Layout = c("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center }),
					Panel = if selectedProgress == "SEASON"
						then seasonStatus
						elseif selectedProgress == "DAILY" then dailyRewards
						else quests,
				}),
			})
			elseif stack then c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(stack.position.X, stack.position.Y),
				Size = UDim2.fromOffset(stack.size.X, stack.size.Y),
			}, {
				Layout = c("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, gap),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Padding = c("UIPadding", {
					PaddingTop = UDim.new(0, gap * 0.5),
					PaddingBottom = UDim.new(0, gap),
				}),
				SeasonStatus = seasonStatus,
				DailyRewards = dailyRewards,
				Quests = quests,
			})
			else nil,
	})
end
