-- Name: PostMatchScreen.luau
-- Author: Jack C.
-- Description: The responsive post-match results screen, presentation only: scores and placements, personal statistics, rewards and season progress, and the replay and return actions supplied by props.
-- Created: 2026-08-25

--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local PostMatchConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PostMatch"))
local ActivityDots = require(script.Parent.ActivityDots)
local AnimatedButton = require(script.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local PostMatchViewModel = require(script.Parent.Parent.Models.PostMatchViewModel)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local useViewportSize = require(script.Parent.Parent.Hooks.useViewportSize)
local UIFeedback = require(script.Parent.Parent.Services.UIFeedback)

local c = React.createElement

local PANEL_IMAGE = "rbxassetid://124751224634629"
local BLUE_BUTTON = "rbxassetid://136021539696619"
local RED_BUTTON = "rbxassetid://94748581468730"
local PATTERN_IMAGE = "rbxassetid://6794188517"
local LOGO_IMAGE = "rbxassetid://78333957912633"
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(39, 54, 58)

local ACCENTS = {
	Cyan = Color3.fromRGB(53, 226, 218),
	Yellow = Color3.fromRGB(255, 220, 62),
	Pink = Color3.fromRGB(242, 24, 76),
	Purple = Color3.fromRGB(160, 60, 255),
}

local function isGamepadInput(inputType: Enum.UserInputType): boolean
	return string.find(inputType.Name, "Gamepad", 1, true) == 1
end

local function validSelection(selection: GuiObject?): boolean
	return selection ~= nil and selection.Parent ~= nil and selection.Visible and selection.Selectable
end

export type Props = {
	Visible: boolean,
	Result: any?,
	Status: any?,
	Requesting: boolean?,
	PendingAction: PostMatchViewModel.Action?,
	Error: string?,
	OnPlayAgain: () -> (),
	OnReturnToLobby: () -> (),
	OnLeaveParty: () -> (),
}

local function textStroke(thickness: number)
	return c("UIStroke", {
		Color = Color3.fromRGB(28, 36, 38),
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness,
		Transparency = 0.08,
	})
end

local function titleLabel(name: string, text: string, position: UDim2, size: UDim2, maxSize: number, zIndex: number)
	return c(ResponsiveText, {
		HostName = name,
		MeasurementFont = Enum.Font.LuckiestGuy,
		MaxTextSize = maxSize,
		MinTextSize = 12,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
			Position = position,
			Size = size,
			Text = text,
			TextColor3 = WHITE,
			ZIndex = zIndex,
		},
	}, {
		Stroke = textStroke(0.04),
	})
end

local function detailLabel(
	name: string,
	text: string,
	position: UDim2,
	size: UDim2,
	maxSize: number,
	zIndex: number,
	color: Color3?
)
	return c(ResponsiveText, {
		HostName = name,
		MeasurementFont = Enum.Font.Highway,
		MaxTextSize = maxSize,
		MinTextSize = 10,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/HighwayGothic.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = position,
			Size = size,
			Text = text,
			TextColor3 = color or WHITE,
			ZIndex = zIndex,
		},
	}, {
		Stroke = textStroke(0.025),
	})
end

local function boostedValue(total: number, base: number?, multiplier: number?): string
	if base == nil or multiplier == nil or math.abs(multiplier - 1) < 0.001 then
		return `+{total}`
	end
	local formatted = string.format("%.2f", multiplier):gsub("0+$", ""):gsub("%.$", "")
	return `{base} x{formatted} = +{total}`
end

local function safeArea(viewport: Vector2): (number, number, number, number)
	local ok, area = pcall(GuiService.GetInsetArea, GuiService, Enum.ScreenInsets.DeviceSafeInsets)
	if not ok or typeof(area) ~= "Rect" then
		return 0, 0, viewport.X, viewport.Y
	end
	local rect = area :: Rect
	return rect.Min.X, rect.Min.Y, math.max(rect.Max.X - rect.Min.X, 0), math.max(rect.Max.Y - rect.Min.Y, 0)
end

local function panel(native: { [any]: any }, children: { [any]: any })
	local properties = {
		BackgroundTransparency = 1,
		Image = PANEL_IMAGE,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(31, 41, 978, 620),
		SliceScale = 0.38,
	}
	for key, value in native do
		properties[key] = value
	end
	return c("ImageLabel", properties, children)
end

local function actionButton(
	name: string,
	text: string,
	image: string,
	enabled: boolean,
	onActivated: () -> (),
	buttonRef: any?,
	layoutOrder: number,
	primary: boolean
)
	return c(AnimatedButton, {
		Enabled = enabled,
		Style = if primary then "Primary" else "Standard",
		EntranceDelay = if primary then 0.55 else 0.62,
		OnActivated = onActivated,
		ButtonRef = buttonRef,
		Native = {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = image,
			ImageColor3 = if enabled then WHITE else Color3.fromRGB(128, 139, 141),
			LayoutOrder = layoutOrder,
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(if primary then 0.59 else 0.34, 0.86),
			SliceCenter = Rect.new(45, 45, 955, 205),
			SliceScale = 0.28,
			ZIndex = 24,
		},
	}, {
		Label = titleLabel("Label", text, UDim2.fromScale(0.5, 0.47), UDim2.fromScale(0.88, 0.55), 42, 26),
		SizeConstraint = c("UISizeConstraint", {
			MinSize = Vector2.new(120, 44),
		}),
	})
end

local function statRows(stats: { any }, compact: boolean)
	local children = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.025, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index, stat in stats do
		children[`Stat{stat.id or index}`] = c("Frame", {
			BackgroundColor3 = if stat.highlight then Color3.fromRGB(255, 220, 62) else Color3.fromRGB(36, 89, 98),
			BackgroundTransparency = if stat.highlight then 0.04 else 0.12,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromScale(0.9, if compact then 0.2 else 0.18),
			ZIndex = 13,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.22, 0) }),
			Label = detailLabel(
				"Label",
				stat.label,
				UDim2.fromScale(0.34, 0.5),
				UDim2.fromScale(0.58, 0.62),
				if compact then 20 else 26,
				14
			),
			Value = titleLabel(
				"Value",
				tostring(stat.value),
				UDim2.fromScale(0.82, 0.48),
				UDim2.fromScale(0.25, 0.68),
				if compact then 25 else 34,
				14
			),
		})
	end
	return children
end

local function scoreRows(scores: { any }, compact: boolean)
	local children = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.035, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index = 1, math.min(#scores, 3) do
		local score = scores[index]
		children[`Score{score.id}`] = c("Frame", {
			BackgroundColor3 = if index == 1 then Color3.fromRGB(255, 220, 62) else Color3.fromRGB(48, 120, 128),
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromScale(0.9, if compact then 0.23 else 0.21),
			ZIndex = 13,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.22, 0) }),
			Name = detailLabel(
				"Name",
				string.upper(score.label),
				UDim2.fromScale(0.38, 0.5),
				UDim2.fromScale(0.62, 0.63),
				if compact then 19 else 25,
				14
			),
			Score = titleLabel(
				"Score",
				tostring(score.score),
				UDim2.fromScale(0.82, 0.48),
				UDim2.fromScale(0.24, 0.68),
				if compact then 26 else 35,
				14
			),
		})
	end
	return children
end

local function progressRows(
	rewards: any?,
	rewardsPending: boolean?,
	season: any?,
	challenges: { any }?,
	unlocks: { any }?,
	compact: boolean
)
	local values = {}
	if rewards then
		table.insert(values, {
			label = "MATCH XP",
			value = boostedValue(rewards.matchXp, rewards.baseXp, rewards.xpMultiplier),
		})
		table.insert(values, {
			label = "BONKS",
			value = boostedValue(rewards.bonks, rewards.baseBonks, rewards.bonksMultiplier),
		})
	end
	if rewards and rewards.seasonXp ~= nil then
		table.insert(values, { label = "SEASON XP", value = `+{rewards.seasonXp}` })
	end
	if rewardsPending and rewards == nil then
		table.insert(values, { label = "MATCH REWARDS", value = "TOTALING UP", loading = true })
	end
	if season then
		local tierValue = if season.afterTier > season.beforeTier
			then `TIER {season.beforeTier} > {season.afterTier}`
			else `TIER {season.afterTier}`
		table.insert(values, { label = string.upper(season.displayName), value = tierValue })
	end
	for _, unlock in unlocks or {} do
		table.insert(values, { label = "UNLOCKED", value = string.upper(unlock.name) })
	end
	for _, challenge in challenges or {} do
		table.insert(values, {
			label = string.upper(challenge.label),
			value = `{challenge.current} / {challenge.target}`,
		})
	end
	local children = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.015, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	local rowHeight = math.min(if compact then 0.18 else 0.17, (if season then 0.66 else 0.82) / math.max(#values, 1))
	for index, value in values do
		children[`Reward{index}`] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.fromScale(0.9, rowHeight),
			ZIndex = 13,
		}, {
			Label = detailLabel(
				"Label",
				value.label,
				UDim2.fromScale(0.32, 0.5),
				UDim2.fromScale(0.58, 0.72),
				if compact then 19 else 24,
				14
			),
			Value = titleLabel(
				"Value",
				value.value,
				UDim2.fromScale(0.79, 0.48),
				UDim2.fromScale(0.32, 0.78),
				if compact then 24 else 32,
				14
			),
			Loading = if value.loading
				then c(ActivityDots, {
					Active = true,
					Native = {
						Position = UDim2.fromScale(0.93, 0.5),
						Size = UDim2.fromScale(0.1, 0.46),
						ZIndex = 15,
					},
					DotSize = UDim2.fromScale(0.2, 0.7),
				})
				else nil,
		})
	end
	if season then
		local progress = math.clamp(season.xpIntoTier / math.max(season.xpForNextTier, 1), 0, 1)
		children.SeasonProgress = c("Frame", {
			BackgroundColor3 = DARK,
			BorderSizePixel = 0,
			LayoutOrder = #values + 1,
			Size = UDim2.fromScale(0.84, 0.07),
			ZIndex = 13,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = c("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 220, 62),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(progress, 1),
				ZIndex = 14,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		})
	end
	return children
end

local function friendlyError(errorCode: string?): string?
	if errorCode == nil then
		return nil
	end
	if errorCode == "not_party_leader" then
		return "ONLY THE PARTY LEADER CAN START THE NEXT ROUND"
	elseif errorCode == "results_expired" then
		return "THE NEXT ROUND IS ALREADY STARTING"
	elseif errorCode == "return_unavailable" or errorCode == "return_in_progress" then
		return "RETURN TO LOBBY IS ALREADY IN PROGRESS"
	elseif errorCode == "rewards_pending" then
		return "FINISHING YOUR REWARDS - PLEASE TRY AGAIN"
	elseif errorCode == "reveal_in_progress" then
		return "YOUR RESULTS ARE STILL BEING REVEALED"
	elseif errorCode == "leave_party_unavailable" then
		return "YOU CAN ONLY LEAVE A PARTY YOU DO NOT LEAD"
	end
	return "THAT DIDN'T WORK - PLEASE TRY AGAIN"
end

return function(props: Props)
	local result = props.Result
	local viewport = useViewportSize()
	local reducedMotion = useReducedMotion()
	local primaryRef = React.useRef(nil)
	local rootRef = React.useRef(nil)
	local previousSelection = React.useRef(nil)
	local ownsSelection = React.useRef(false)
	local presentationRevision = React.useRef(0)
	local selectionRevision = React.useRef(0)
	local announcedResult = React.useRef("")
	local interactive, setInteractive = React.useState(false)
	local celebrating, setCelebrating = React.useState(false)
	local remainingSeconds, setRemainingSeconds = React.useState(0)
	local gamepadActive, setGamepadActive = React.useState(isGamepadInput(UserInputService:GetLastInputType()))
	local visible = props.Visible and result ~= nil
	local safeX, safeY, safeWidth, safeHeight = safeArea(viewport)
	local canvasWidth, canvasHeight, compact = PostMatchViewModel.canvasSize(safeWidth, safeHeight)
	local styles = ReactSpring.useSpring({
		Scale = if visible then 1 else 0.92,
		Offset = if visible then 0 else 32,
		Transparency = if visible then 0 else 1,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	local celebrationStyles = ReactSpring.useSpring({
		Glow = if celebrating then 1 else 0,
		config = Motion.Modal,
		immediate = reducedMotion,
	})

	React.useEffect(function()
		local connection = UserInputService.LastInputTypeChanged:Connect(function(inputType)
			setGamepadActive(isGamepadInput(inputType))
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local ownedRoot: GuiObject? = rootRef.current
		local function restoreSelection()
			if not ownsSelection.current then
				return
			end
			ownsSelection.current = false
			local previous: GuiObject? = previousSelection.current
			previousSelection.current = nil
			if validSelection(previous) then
				GuiService.SelectedObject = previous
				return
			end
			local selected = GuiService.SelectedObject
			if ownedRoot and selected and selected:IsDescendantOf(ownedRoot) then
				GuiService.SelectedObject = nil
			end
		end

		if visible then
			previousSelection.current = GuiService.SelectedObject
			ownsSelection.current = true
		else
			restoreSelection()
		end
		return function()
			if visible then
				restoreSelection()
			end
		end
	end, { visible })

	React.useEffect(function()
		presentationRevision.current += 1
		local revision = presentationRevision.current
		setInteractive(false)
		setCelebrating(visible and not reducedMotion)
		if not visible then
			return
		end
		if announcedResult.current ~= result.resultId then
			announcedResult.current = result.resultId
			UIFeedback.notification()
		end
		local delaySeconds = math.max((result.interactiveAt or 0) - Workspace:GetServerTimeNow(), 0)
		local thread = task.delay(delaySeconds, function()
			if revision ~= presentationRevision.current then
				return
			end
			setInteractive(true)
		end)
		local celebrationThread = task.delay(PostMatchConfig.CelebrationSeconds, function()
			if revision == presentationRevision.current then
				setCelebrating(false)
			end
		end)
		return function()
			presentationRevision.current += 1
			task.cancel(thread)
			task.cancel(celebrationThread)
		end
	end, { visible, if result then result.resultId else "", reducedMotion })

	React.useEffect(function()
		if not visible then
			setRemainingSeconds(0)
			return
		end
		local previous = -1
		local function update()
			local remaining = PostMatchViewModel.remainingSeconds(result.endsAt, Workspace:GetServerTimeNow())
			if remaining ~= previous then
				previous = remaining
				setRemainingSeconds(remaining)
			end
		end
		update()
		local connection = RunService.Heartbeat:Connect(update)
		return function()
			connection:Disconnect()
		end
	end, { visible, if result then result.resultId else "" })

	React.useEffect(function()
		selectionRevision.current += 1
		local revision = selectionRevision.current
		if not visible or not interactive or not gamepadActive then
			if not gamepadActive then
				local ownedRoot: GuiObject? = rootRef.current
				local selected = GuiService.SelectedObject
				if ownedRoot and selected and selected:IsDescendantOf(ownedRoot) then
					GuiService.SelectedObject = nil
				end
			end
			return
		end
		task.defer(function()
			local button: GuiButton? = primaryRef.current
			if revision == selectionRevision.current and validSelection(button) then
				GuiService.SelectedObject = button
			end
		end)
		return function()
			selectionRevision.current += 1
		end
	end, { visible, interactive, gamepadActive, props.Status })

	if not visible then
		return nil
	end

	local status = props.Status
	local party = if props.Status and props.Status.party then props.Status.party else result.party
	local localUserId = Players.LocalPlayer.UserId
	local actions =
		PostMatchViewModel.actions(localUserId, party, status, props.Requesting == true, props.PendingAction)
	local errorText = friendlyError(props.Error)
	local accent = ACCENTS[result.presentation.accent] or ACCENTS.Cyan
	local hasProgress = result.rewardsPending == true
		or result.rewards ~= nil
		or (result.challenges ~= nil and #result.challenges > 0)
		or (result.unlocks ~= nil and #result.unlocks > 0)
	local hasFutureProgress = (result.challenges ~= nil and #result.challenges > 0)
		or (result.unlocks ~= nil and #result.unlocks > 0)
	local displayedStats = result.personalStats
	if result.firstMatch and #displayedStats > 1 then
		local positive = nil
		for _, stat in displayedStats do
			if stat.highlight then
				positive = stat
				break
			end
		end
		displayedStats = { positive or displayedStats[1] }
	end
	local contentCards = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(if compact then 0.018 else 0.025, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	local cardCount = 1
	if #displayedStats > 0 then
		cardCount += 1
	end
	if hasProgress then
		cardCount += 1
	end
	local cardWidth = math.min((1 - 0.025 * (cardCount - 1)) / cardCount, 0.36)

	if #displayedStats > 0 then
		contentCards.Stats = panel({
			LayoutOrder = 1,
			Size = UDim2.fromScale(cardWidth, 0.96),
			ZIndex = 10,
		}, {
			Title = titleLabel(
				"Title",
				"YOUR ROUND",
				UDim2.fromScale(0.5, 0.13),
				UDim2.fromScale(0.82, 0.18),
				if compact then 28 else 38,
				12
			),
			Rows = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.59),
				Size = UDim2.fromScale(0.9, 0.68),
				ZIndex = 12,
			}, statRows(displayedStats, compact)),
		})
	end

	contentCards.Score = panel({
		LayoutOrder = 2,
		Size = UDim2.fromScale(cardWidth, 0.96),
		ZIndex = 10,
	}, {
		Mode = titleLabel(
			"Mode",
			string.upper(result.modeName),
			UDim2.fromScale(0.5, 0.13),
			UDim2.fromScale(0.84, 0.18),
			if compact then 28 else 38,
			12
		),
		Logo = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = LOGO_IMAGE,
			ImageColor3 = accent,
			Position = UDim2.fromScale(0.5, 0.31),
			Size = UDim2.fromScale(0.28, 0.22),
			ZIndex = 12,
		}, {
			Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1.55 }),
		}),
		Rows = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.66),
			Size = UDim2.fromScale(0.9, 0.54),
			ZIndex = 12,
		}, scoreRows(result.scores, compact)),
	})

	if hasProgress then
		contentCards.Rewards = panel({
			LayoutOrder = 3,
			Size = UDim2.fromScale(cardWidth, 0.96),
			ZIndex = 10,
		}, {
			Title = titleLabel(
				"Title",
				if hasFutureProgress then "PROGRESS" else "REWARDS",
				UDim2.fromScale(0.5, 0.13),
				UDim2.fromScale(0.82, 0.18),
				if compact then 28 else 38,
				12
			),
			Rows = c(
				"Frame",
				{
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.58),
					Size = UDim2.fromScale(0.9, 0.68),
					ZIndex = 12,
				},
				progressRows(
					result.rewards,
					result.rewardsPending,
					result.seasonProgress,
					result.challenges,
					result.unlocks,
					compact
				)
			),
		})
	end

	local canvasPosition = styles.Offset:map(function(offset: number)
		return UDim2.fromOffset(safeX + safeWidth * 0.5, safeY + safeHeight * 0.5 + offset)
	end)
	local returnCallback = if actions.returnAction == "LeaveParty" then props.OnLeaveParty else props.OnReturnToLobby
	local resultDuration = math.max(result.endsAt - result.interactiveAt, 1)
	local expiryProgress = math.clamp(remainingSeconds / resultDuration, 0, 1)

	return c("Frame", {
		ref = rootRef,
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(21, 77, 85),
		BackgroundTransparency = styles.Transparency:map(function(value: number)
			return 0.12 + value * 0.88
		end),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		SelectionGroup = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, {
		Pattern = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = PATTERN_IMAGE,
			ImageColor3 = accent,
			ImageTransparency = celebrationStyles.Glow:map(function(value: number)
				return 0.68 - value * 0.12
			end),
			ScaleType = Enum.ScaleType.Tile,
			Size = UDim2.fromScale(1, 1),
			TileSize = UDim2.fromOffset(220, 220),
			ZIndex = 2,
		}),
		Shade = c("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(30, 100, 108), Color3.fromRGB(13, 45, 53)),
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.12),
				NumberSequenceKeypoint.new(1, 0.42),
			}),
		}),
		Canvas = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = canvasPosition,
			Size = UDim2.fromOffset(canvasWidth, canvasHeight),
			ZIndex = 5,
		}, {
			Scale = c("UIScale", { Scale = styles.Scale }),
			ResultBanner = panel({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, if compact then 0.025 else 0.035),
				Size = UDim2.fromScale(if compact then 0.76 else 0.68, if compact then 0.22 else 0.2),
				ZIndex = 6,
			}, {
				Accent = c("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundColor3 = accent,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.94),
					Size = UDim2.fromScale(0.74, 0.035),
					ZIndex = 8,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
				Eyebrow = detailLabel(
					"Eyebrow",
					result.presentation.eyebrow,
					UDim2.fromScale(0.5, 0.2),
					UDim2.fromScale(0.84, 0.2),
					if compact then 24 else 32,
					8
				),
				Countdown = detailLabel(
					"Countdown",
					`CLOSES IN {remainingSeconds}`,
					UDim2.fromScale(0.86, 0.2),
					UDim2.fromScale(0.2, 0.18),
					if compact then 15 else 20,
					9,
					accent
				),
				Title = titleLabel(
					"Title",
					result.presentation.title,
					UDim2.fromScale(0.5, 0.51),
					UDim2.fromScale(0.9, 0.36),
					if compact then 42 else 64,
					8
				),
				Detail = if result.presentation.detail
					then detailLabel(
						"Detail",
						result.presentation.detail,
						UDim2.fromScale(0.5, 0.8),
						UDim2.fromScale(0.84, 0.2),
						if compact then 22 else 30,
						8
					)
					else nil,
			}),
			Content = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, if compact then 0.5 else 0.51),
				Size = UDim2.fromScale(if compact then 0.96 else 0.9, if compact then 0.48 else 0.5),
				ZIndex = 9,
			}, contentCards),
			Party = if #actions.partyNames > 0
				then detailLabel(
					"Party",
					`PARTY  -  {table.concat(actions.partyNames, "  /  ")}`,
					UDim2.fromScale(0.5, if compact then 0.735 else 0.765),
					UDim2.fromScale(0.86, 0.05),
					if compact then 18 else 23,
					20
				)
				else nil,
			Status = detailLabel(
				"Status",
				errorText or actions.statusText,
				UDim2.fromScale(0.5, if compact then 0.785 else 0.815),
				UDim2.fromScale(0.86, 0.055),
				if compact then 20 else 27,
				20,
				if errorText then ACCENTS.Pink else WHITE
			),
			StatusActivity = if actions.busy and errorText == nil
				then c(ActivityDots, {
					Active = true,
					Native = {
						Position = UDim2.fromScale(0.92, if compact then 0.785 else 0.815),
						Size = UDim2.fromScale(0.055, 0.032),
						ZIndex = 21,
					},
				})
				else nil,
			Expiry = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = DARK,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, if compact then 0.835 else 0.855),
				Size = UDim2.fromScale(if compact then 0.62 else 0.5, 0.012),
				ZIndex = 20,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Fill = c("Frame", {
					BackgroundColor3 = accent,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(expiryProgress, 1),
					ZIndex = 21,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
			}),
			Actions = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.985),
				Size = UDim2.fromScale(if compact then 0.92 else 0.72, 0.13),
				ZIndex = 22,
			}, {
				Layout = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.035, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Primary = actionButton(
					"PlayAgain",
					actions.primaryText,
					if actions.replaySelected then BLUE_BUTTON else RED_BUTTON,
					interactive and actions.isLeader and not actions.busy,
					props.OnPlayAgain,
					if actions.isLeader then primaryRef else nil,
					1,
					true
				),
				Return = actionButton(
					if actions.returnAction == "LeaveParty" then "LeaveParty" else "ReturnToLobby",
					actions.returnText,
					BLUE_BUTTON,
					interactive and not actions.busy,
					returnCallback,
					if actions.isLeader then nil else primaryRef,
					2,
					false
				),
			}),
		}),
	})
end
