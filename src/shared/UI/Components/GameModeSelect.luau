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
local Motion = require(script.Parent.Parent.Motion)
local T = require(script.Parent.Parent.Tokens)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Selection = require(script.Parent.Parent.Services.Selection)

local c = React.createElement
local TITLE = "VOTE FOR A MODE"

export type Props = {
	Active: boolean,
	Prepared: boolean?,
	Modes: { GameModeCard.Mode },
	EndsAt: number,
	DurationSeconds: number,
	OnVote: (string) -> (),
	OnPrepared: (() -> ())?,
	OnPresented: (() -> ())?,
}

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.None)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, 1)
	local short = safeArea.size.Y <= 500
	local compact = not portrait and short
	local cardHeight = math.clamp(safeArea.size.Y * 0.56 - 24, 288, 350)
	local titleSize = if portrait then 28 else if compact then 30 else 44
	local titleWidth = math.min(
		TextService:GetTextSize(TITLE, titleSize, T.Type.Display, Vector2.new(100000, 1000)).X + 36,
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
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 12),
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
				Position = if portrait then UDim2.fromScale(0.04, 0.015) else UDim2.fromScale(0, -0.000749383),
				Size = if portrait
					then UDim2.fromScale(0.5, 0.2)
					else if compact then UDim2.fromScale(0.25, 0.2) else UDim2.fromScale(0.321542, 0.301659),
			}, {
				UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
					AspectRatio = 1.55,
				}),
			}),
			VoteText = c(CandyTitle, {
				Text = TITLE,
				TextSize = titleSize,
				Tilt = T.Shape.TiltTitle,
				Native = {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, if portrait then 0.285 else if compact then 0.225 else 0.27),
					Size = UDim2.fromOffset(titleWidth, if portrait then 45 else if compact then 48 else 66),
					ZIndex = 10,
				},
			}),
			ModesHolder = c(if portrait then "ScrollingFrame" else "Frame", {
				Active = if portrait then true else nil,
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutomaticCanvasSize = if portrait then Enum.AutomaticSize.Y else nil,
				BackgroundTransparency = 1,
				CanvasSize = if portrait then UDim2.fromOffset(0, 0) else nil,
				Position = UDim2.fromScale(0.5, if portrait then 0.6 else if compact then 0.57 else 0.573),
				ScrollBarImageColor3 = if portrait then T.Colors.InkSoft else nil,
				ScrollBarThickness = if portrait then 6 else nil,
				Size = if portrait
					then UDim2.new(0.92, 0, 0, holderHeight)
					else UDim2.fromScale(0.94, if compact then 0.60 else 0.56),
				VerticalScrollBarInset = if portrait then Enum.ScrollBarInset.ScrollBar else nil,
			}, cards),
			LoadingBar = c(VoteLoadingBar, {
				Active = props.Active,
				EndsAt = props.EndsAt,
				DurationSeconds = props.DurationSeconds,
				Position = UDim2.fromScale(0.5, 0.975),
				Size = UDim2.fromOffset(math.min(540, safeArea.size.X * 0.82), if portrait or compact then 48 else 56),
			}),
		}),
	})
end
