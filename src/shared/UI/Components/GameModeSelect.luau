-- Description: The game mode ballot screen: lays out the mode cards, the countdown bar, and the local player's selection, purely from the snapshot passed in.

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local GameModeCard = require(script.Parent.GameModeCard)
local CandyTitle = require(script.Parent.CandyTitle)
local VoteLoadingBar = require(script.Parent.VoteLoadingBar)
local Badge = require(script.Parent.Badge)
local MapVoteChip = require(script.Parent.MapVoteChip)
local VoteModel = require(script.Parent.Parent.Models.GameModeVoteViewModel)
local Motion = require(script.Parent.Parent.Motion)
local T = require(script.Parent.Parent.Tokens)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Selection = require(script.Parent.Parent.Services.Selection)

local c = React.createElement

export type Props = {
	Active: boolean,
	Prepared: boolean?,
	Modes: { GameModeCard.Mode },
	EndsAt: number,
	DurationSeconds: number,
	OnVote: (string) -> (),
	Maps: { MapVoteChip.Map }?,
	OnVoteMap: ((string) -> ())?,
	OnPrepared: (() -> ())?,
	OnPresented: (() -> ())?,
}

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.None)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, 1)
	local short = VoteModel.isShort(safeArea.size)
	local compact = not portrait and short
	local maps = props.Maps or {}
	local hasMaps = #maps >= 2 and props.OnVoteMap ~= nil
	local title = VoteModel.title(hasMaps)
	local dock = if hasMaps then VoteModel.dockLayout(safeArea.size, #maps) else nil
	local cardHeight = math.clamp(safeArea.size.Y * 0.56 - 24, 288, 350)
	local titleSize = if portrait or compact then T.Type.ModalTitle else T.Type.Title
	local titleWidth = math.min(
		TextService:GetTextSize(title, titleSize, T.Type.Display, Vector2.new(100000, 1000)).X + 36,
		safeArea.size.X * 0.88
	)
	local present, setPresent = React.useState(props.Active or props.Prepared == true)
	local revision = React.useRef(0)
	local focusRevision = React.useRef(0)
	local firstButtonRef = React.useRef(nil)
	local previousSelection = React.useRef(nil)
	local reducedMotion = useReducedMotion()
	local styles, api = ReactSpring.useSpring(function()
		return {
			Position = UDim2.fromScale(0, 0.06),
		}
	end)

	React.useEffect(function()
		revision.current += 1
		local currentRevision = revision.current
		local shouldPresent = props.Active or props.Prepared == true
		if shouldPresent then
			setPresent(true)
			api.start(if props.Active
				then {
					Position = UDim2.fromScale(0, 0),
					config = Motion.Modal,
					immediate = reducedMotion,
				}
				else {
					Position = UDim2.fromScale(0, 0.06),
					immediate = true,
				})
		else
			api.start({
				Position = UDim2.fromScale(0, 0.06),
				config = Motion.Modal,
				immediate = reducedMotion,
			}):andThen(function()
				if revision.current == currentRevision then
					setPresent(false)
				end
			end)
		end
		return function()
			revision.current += 1
		end
	end, { props.Active, props.Prepared, reducedMotion })

	React.useEffect(function()
		if not present or #props.Modes == 0 then
			return
		end
		local currentRevision = revision.current
		task.defer(function()
			if revision.current ~= currentRevision then
				return
			end
			local button = firstButtonRef.current
			if button and button.Parent then
				if props.OnPrepared then
					props.OnPrepared()
				end
				if props.Active and props.OnPresented then
					task.spawn(function()
						RunService.RenderStepped:Wait()
						if revision.current == currentRevision and button.Parent and button.Visible then
							props.OnPresented()
						end
					end)
				end
			end
		end)
	end, { present, props.Active, props.Modes, props.OnPrepared, props.OnPresented })

	React.useEffect(function()
		focusRevision.current += 1
		local currentFocusRevision = focusRevision.current
		if props.Active then
			if previousSelection.current == nil then
				previousSelection.current = GuiService.SelectedObject
			end
			task.defer(function()
				if focusRevision.current ~= currentFocusRevision then
					return
				end
				local button = firstButtonRef.current
				if Selection.isSelectable(button) then
					GuiService.SelectedObject = button
				end
			end)
		else
			local selection = previousSelection.current
			previousSelection.current = nil
			if Selection.isSelectable(selection) then
				GuiService.SelectedObject = selection
			end
		end
		return function()
			focusRevision.current += 1
		end
	end, { props.Active })

	React.useEffect(function()
		return function()
			api.stop()
		end
	end, {})

	if not present then
		return nil
	end

	local cards = {
		UIListLayout = c("UIListLayout", {
			FillDirection = if portrait then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			HorizontalFlex = if portrait then Enum.UIFlexAlignment.None else Enum.UIFlexAlignment.SpaceEvenly,
			Padding = if portrait then UDim.new(0, 16) else UDim.new(0, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = if portrait then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Center,
		}),
		Padding = if portrait
			then c("UIPadding", {
				PaddingTop = UDim.new(0, T.Layout.CompactGap),
				PaddingBottom = UDim.new(0, T.Layout.CompactGap),
				PaddingLeft = UDim.new(0, T.Layout.CompactGap),
				PaddingRight = UDim.new(0, T.Layout.CompactGap),
			})
			else nil,
	}
	for index, mode in props.Modes do
		cards[mode.Id] = c(GameModeCard, {
			Mode = mode,
			Enabled = props.Active,
			OnVote = props.OnVote,
			ButtonRef = if index == 1 then firstButtonRef else nil,
			Portrait = portrait,
			Compact = short,
			CardHeight = cardHeight,
		})
	end
	local holderHeight = safeArea.size.Y * 0.56
	local shrink = if dock then dock.holderShrink else 0

	-- Map dock: one row with the countdown bar when it fits, else its own row above.
	local barWidth = math.min(T.MapVote.BarMaxWidth, safeArea.size.X * 0.82)
	local barHeight = if portrait or compact then T.MapVote.CompactBarHeight else T.MapVote.BarHeight
	local barPosition = UDim2.fromScale(0.5, 0.975)
	local dockChildren: { [string]: any }? = nil
	local dockSize = UDim2.new()
	local dockPosition = UDim2.new()
	local dockAnchor = Vector2.new(0, 1)
	if dock then
		local chipsWidth = #maps * dock.chipWidth + (#maps - 1) * dock.gap
		barWidth = dock.barWidth
		barHeight = dock.barHeight
		dockSize = UDim2.fromOffset(chipsWidth, dock.chipHeight)
		if dock.stacked then
			dockAnchor = Vector2.new(0.5, 1)
			dockPosition = UDim2.new(0.5, 0, 0.975, -(dock.barHeight + dock.gap))
		else
			local rowLeft = math.floor((safeArea.size.X - (chipsWidth + dock.gap + barWidth)) / 2)
			dockPosition = UDim2.new(0, rowLeft, 0.975, 0)
			barPosition = UDim2.new(0, rowLeft + chipsWidth + dock.gap + barWidth / 2, 0.975, 0)
		end
		local sticker = if compact then T.Shop.CompactStickerHeight else T.Shop.StickerHeight
		local chips: { [string]: any } = {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, dock.gap),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
		}
		for index, map in maps do
			chips[map.Id] = c(MapVoteChip, {
				Map = map,
				Enabled = props.Active,
				OnVote = props.OnVoteMap :: (string) -> (),
				Height = dock.chipHeight,
				Width = dock.chipWidth,
				Compact = short or portrait,
				EntranceDelay = (#props.Modes + index - 1) * 0.025,
				LayoutOrder = index,
			})
		end
		dockChildren = {
			Chips = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, chips),
			Sticker = c(Badge, {
				Text = "MAP",
				TextSize = T.Type.Minimum,
				Tilt = T.Shop.StickerTilt,
				Native = {
					Position = UDim2.fromOffset(-T.Shop.StickerOverhang, -math.floor(sticker / 2)),
					Size = UDim2.fromOffset(T.Shop.StickerPadding + 34, sticker),
					ZIndex = 20,
				},
			}),
		}
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Position = styles.Position,
		SelectionGroup = true,
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		Size = UDim2.fromScale(1, 1),
		Visible = props.Active,
	}, {
		SafeArea = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(safeArea.position.X, safeArea.position.Y),
			Size = UDim2.fromOffset(safeArea.size.X, safeArea.size.Y),
		}, {
			Logo = c("ImageLabel", {
				BackgroundTransparency = 1,
				Image = "rbxassetid://78333957912633",
				Position = if portrait then UDim2.fromScale(0.04, 0.015) else UDim2.fromScale(0, 0),
				Size = if portrait
					then UDim2.fromScale(0.5, 0.2)
					else if compact then UDim2.fromScale(0.25, 0.2) else UDim2.fromScale(0.321542, 0.301659),
			}, {
				UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
					AspectRatio = 1.55,
				}),
			}),
			VoteText = c(CandyTitle, {
				Text = title,
				TextSize = titleSize,
				Tilt = T.Shape.TiltTitle,
				Native = {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, if portrait then 0.285 else if compact then 0.225 else 0.27),
					Size = UDim2.fromOffset(
						titleWidth,
						if portrait or compact then T.Layout.CompactTitleHeight else T.Layout.TitleHeight
					),
					ZIndex = 10,
				},
			}),
			ModesHolder = c(if portrait then "ScrollingFrame" else "Frame", {
				Active = if portrait then true else nil,
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutomaticCanvasSize = if portrait then Enum.AutomaticSize.Y else nil,
				BackgroundTransparency = 1,
				CanvasSize = if portrait then UDim2.fromOffset(0, 0) else nil,
				Position = UDim2.new(
					0.5,
					0,
					if portrait then 0.6 else if compact then 0.57 else 0.573,
					-math.floor(shrink / 2)
				),
				ScrollBarImageColor3 = if portrait then T.Colors.InkSoft else nil,
				ScrollBarThickness = if portrait then T.Layout.ScrollBar else nil,
				Size = if portrait
					then UDim2.new(0.92, 0, 0, holderHeight - shrink)
					else UDim2.new(0.94, 0, if compact then 0.60 else 0.56, -shrink),
				VerticalScrollBarInset = if portrait then Enum.ScrollBarInset.ScrollBar else nil,
			}, cards),
			MapDock = if dockChildren
				then c("Frame", {
					AnchorPoint = dockAnchor,
					BackgroundTransparency = 1,
					Position = dockPosition,
					Size = dockSize,
				}, dockChildren)
				else nil,
			LoadingBar = c(VoteLoadingBar, {
				Active = props.Active,
				EndsAt = props.EndsAt,
				DurationSeconds = props.DurationSeconds,
				Position = barPosition,
				Size = UDim2.fromOffset(barWidth, barHeight),
			}),
		}),
	})
end
