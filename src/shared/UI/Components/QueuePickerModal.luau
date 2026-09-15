--!strict
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local React = require(RS.Packages.react)
local Spring = require(RS.Packages["react-spring"])
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local Selection = require(script.Parent.Parent.Services.Selection)
local Panel = require(script.Parent.CandyPanel)
local Text = require(script.Parent.LobbyText)
local Close = require(script.Parent.ModalClose)
local Scroll = require(script.Parent.ScrollFrame)
local Picker = require(script.Parent.QueuePicker)
local modalSurface = require(script.Parent.ModalSurface)
local c, C, S = React.createElement, T.Colors, T.ModePicker

return function(props)
	local safe = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local compact = safe.size.Y < 520 or safe.size.X < 600
	local stacked = safe.size.X < 600
	local edge = if compact then 12 else S.Edge
	local width = math.min(S.MaxWidth, safe.size.X - edge * 2)
	local height = math.min(S.MaxHeight, safe.size.Y - edge * 2)
	local header = if compact then S.CompactHeaderHeight else S.HeaderHeight
	local inset = if compact then 16 else S.ModalInset
	local cardHeight =
		math.max(if compact then S.CompactCardMinHeight else S.CardMinHeight, height - header - inset - 16)
	local closeRef, selectedRef, modalRef = React.useRef(nil), React.useRef(nil), React.useRef(nil)
	local firstRef = React.useRef(nil)
	local reduced = useReducedMotion()
	local styles =
		Spring.useSpring({ Scale = if props.Open then 1 else 0.92, config = Motion.Modal, immediate = reduced })
	React.useEffect(function()
		if not props.Open or props.FocusEnabled == false then
			return
		end
		local previous, modal, active = GuiService.SelectedObject, modalRef.current, true
		task.defer(function()
			local target = selectedRef.current or firstRef.current or closeRef.current
			if active and Selection.isSelectable(target) then
				GuiService.SelectedObject = target
			end
		end)
		return function()
			active = false
			local selected = GuiService.SelectedObject
			if (selected == nil or (modal and selected:IsDescendantOf(modal))) and Selection.isSelectable(previous) then
				GuiService.SelectedObject = previous
			end
		end
	end, { props.Open, props.FocusEnabled })
	if not props.Open then
		return nil
	end
	return modalSurface({
		ref = modalRef,
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.25,
		Text = "",
		Selectable = false,
		ZIndex = 110,
	}, {
		Panel = c(Panel, {
			Tilt = 0,
			Native = {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(safe.position.X + safe.size.X / 2, safe.position.Y + safe.size.Y / 2),
				Size = UDim2.fromOffset(width, height),
				ZIndex = 111,
				SelectionGroup = true,
				SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
				SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
				SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
				SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			},
		}, {
			Entrance = c("UIScale", { Scale = styles.Scale }),
			Title = c(Text, {
				Text = "CHOOSE GAME MODE",
				Font = T.Type.Display,
				TextSize = if compact then 26 else 34,
				Position = UDim2.fromOffset(inset, 8),
				Size = UDim2.new(1, -inset * 2 - 56, 0, header - 12),
				ZIndex = 114,
			}),
			Close = c(Close, {
				ButtonRef = closeRef,
				OnActivated = props.OnClose,
				Position = UDim2.new(1, -inset, 0, 10),
				ZIndex = 124,
			}),
			Cards = c(Scroll, {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(inset - 6, header - 6),
				Size = UDim2.new(1, -inset * 2 + 12, 1, -header - inset + 12),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = C.Pink,
				ZIndex = 115,
			}, {
				Padding = c("UIPadding", {
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),
				Modes = c(Picker, {
					Options = props.Options,
					SelectedId = props.SelectedId,
					Enabled = props.Enabled and props.FocusEnabled ~= false,
					OnSelect = props.OnSelect,
					Compact = compact,
					Stacked = stacked,
					CardHeight = cardHeight,
					SelectedButtonRef = selectedRef,
					FirstButtonRef = firstRef,
					Native = {
						Size = UDim2.new(
							1,
							-28,
							0,
							if stacked
								then #props.Options * cardHeight + math.max(0, #props.Options - 1) * S.Gap
								else cardHeight
						),
						ZIndex = 116,
					},
				}),
			}),
		}),
	})
end
