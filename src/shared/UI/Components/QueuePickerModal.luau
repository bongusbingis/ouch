--!strict
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local React = require(RS.Packages.react)
local Spring = require(RS.Packages["react-spring"])
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local Selection = require(script.Parent.Parent.Services.Selection)
local Panel = require(script.Parent.CandyPanel)
local CandyTitle = require(script.Parent.CandyTitle)
local Close = require(script.Parent.ModalClose)
local Scroll = require(script.Parent.ScrollFrame)
local Picker = require(script.Parent.QueuePicker)
local modalSurface = require(script.Parent.ModalSurface)
local c, C, S = React.createElement, T.Colors, T.ModePicker

-- Card anatomy shared with QueuePicker: the select pill, its bottom inset, and the gaps around the copy.
local PILL_HEIGHT = 40
local CARD_INSET = 16
local COPY_GAP = 8
local TEXT_AFTER_ART = 58
local COMPACT_TEXT_TOP = 52
local MIN_ART_HEIGHT = 110

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
	-- Size every card to its longest description (measured, not guessed) so the copy never runs into
	-- the select pill; the tallest card sets the height for all siblings.
	local descriptionSize = if compact then T.Type.Minimum else T.Type.Body
	local cardsWidth = width - inset * 2 - 52
	local cardWidth = if stacked
		then cardsWidth
		else (cardsWidth - S.Gap * (math.max(#props.Options, 1) - 1)) / math.max(#props.Options, 1)
	local textWidth = if compact then cardWidth * 0.61 - 16 else cardWidth - 36
	local descriptionHeight = 0
	for _, option in props.Options do
		descriptionHeight = math.max(
			descriptionHeight,
			math.ceil(
				TextService:GetTextSize(
					option.description or option.title,
					descriptionSize,
					T.Type.Label,
					Vector2.new(math.max(textWidth, 1), 10000)
				).Y
			) + 4
		)
	end
	local copyBottom = descriptionHeight + COPY_GAP + PILL_HEIGHT + CARD_INSET
	local artHeight = nil
	if compact then
		cardHeight = math.max(cardHeight, COMPACT_TEXT_TOP + copyBottom)
	else
		artHeight = math.clamp(cardHeight - TEXT_AFTER_ART - copyBottom, MIN_ART_HEIGHT, math.floor(cardHeight * 0.5))
		cardHeight = math.max(cardHeight, artHeight + TEXT_AFTER_ART + copyBottom)
	end
	-- One title size for the family (CandyTitle sticker), stepped down only if it would meet the close button.
	local titleLeft = inset + (if compact then 8 else 12)
	local titleWidth = width - titleLeft - inset - T.Layout.MinTarget - T.Layout.CompactGap
	local titleSize = T.Type.ModalTitle
	while
		titleSize > T.Type.Minimum + 4
		and TextService:GetTextSize("CHOOSE GAME MODE", titleSize, T.Type.Display, Vector2.new(100000, 1000)).X
				+ 36
			> titleWidth
	do
		titleSize -= 2
	end
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
			Title = c(CandyTitle, {
				Text = "CHOOSE GAME MODE",
				TextSize = titleSize,
				Native = {
					Position = UDim2.fromOffset(titleLeft, if compact then 2 else -18),
					Size = UDim2.fromOffset(titleWidth, if compact then 48 else 70),
					ZIndex = 120,
				},
			}),
			Close = c(Close, {
				ButtonRef = closeRef,
				OnActivated = props.OnClose,
				Position = UDim2.new(1, -inset, 0, if compact then 8 else 14),
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
				ScrollBarThickness = T.Layout.ScrollBar,
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
					ArtHeight = artHeight,
					DescriptionSize = descriptionSize,
					DescriptionHeight = descriptionHeight,
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
