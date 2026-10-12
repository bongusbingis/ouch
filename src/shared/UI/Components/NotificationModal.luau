--!strict
local T = require(script.Parent.Parent.Tokens)
-- Description: The shared notification and confirmation modal, rendering a title, message, and action buttons for whatever the notification context has queued.

local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Selection = require(script.Parent.Parent.Services.Selection)

local modalSurface = require(script.Parent.ModalSurface)

local CandyTitle = require(script.Parent.CandyTitle)
local ModalClose = require(script.Parent.ModalClose)
local c = React.createElement
local CandyPanel = require(script.Parent.CandyPanel)

export type ButtonDefinition = {
	Color: "Red" | "Blue",
	Text: string,
	Value: any,
}

export type Request = {
	Title: string,
	Description: string,
	Buttons: { ButtonDefinition },
}

export type Props = {
	Request: Request?,
	OnChoose: (any) -> (),
	FocusEnabled: boolean?,
}

local BUTTON_HEIGHT = 54
local BUTTON_GAP = 12
-- A lone action is the one thing to press, so it is the pink primary; a pair keeps its authored colours.
local SINGLE_BUTTON_MAX_WIDTH = 420
local BODY_GAP = 12
local FOOTER_GAP = 16

local function notificationButton(
	definition: ButtonDefinition,
	order: number,
	onChoose: (any) -> (),
	buttonRef: any?,
	columns: number,
	primary: boolean
)
	local red = primary or definition.Color == "Red"
	local column = (order - 2) % columns
	local row = math.floor((order - 2) / columns)
	return c(ShopPriceButton, {
		ButtonRef = buttonRef,
		EntranceDelay = (order - 2) * 0.025,
		Red = red,
		Text = definition.Text,
		TextSize = 24,
		LayoutOrder = order,
		AnchorPoint = Vector2.zero,
		-- Columns share the row exactly: width = (W - gap * (columns - 1)) / columns.
		Position = UDim2.new(column / columns, column * BUTTON_GAP / columns, 0, row * (BUTTON_HEIGHT + BUTTON_GAP)),
		Size = UDim2.new(1 / columns, -BUTTON_GAP * (columns - 1) / columns, 0, BUTTON_HEIGHT),
		ZIndex = 136,
		OnActivated = function()
			onChoose(definition.Value)
		end,
	})
end

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local panelSize = ResponsiveLayout.panelSize(
		safeArea.size,
		UIConfig.Layout.Panels.Notification,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local firstButtonRef = React.useRef(nil)
	local modalRef = React.useRef(nil)
	local reducedMotion = useReducedMotion()
	local styles = ReactSpring.useSpring({
		Scale = if props.Request then 1 else 0.82,
		Rotation = if props.Request then 0 else -2,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	local request = props.Request
	React.useEffect(function()
		if not request or props.FocusEnabled == false then
			return
		end
		local previous = GuiService.SelectedObject
		local modal = modalRef.current
		local active = true
		task.defer(function()
			local button = firstButtonRef.current
			if active and Selection.isSelectable(button) then
				GuiService.SelectedObject = button
			end
		end)
		return function()
			active = false
			local selected = GuiService.SelectedObject
			if
				(selected == nil or (modal ~= nil and selected:IsDescendantOf(modal)))
				and Selection.isSelectable(previous)
			then
				GuiService.SelectedObject = previous
			end
		end
	end, { request, props.FocusEnabled })
	if not request then
		return nil
	end

	local inset = T.Layout.Inset
	local closeSize = T.Layout.MinTarget
	local titleSize = T.Type.ModalTitle
	-- The title sticker stops short of the close button instead of running under it.
	local titleWidth = panelSize.X - inset * 2 - closeSize - T.Layout.CompactGap
	local titleHeight = math.max(
		60,
		TextService:GetTextSize(request.Title, titleSize, T.Type.Display, Vector2.new(titleWidth - 36, 10000)).Y + 20
	)
	local descriptionHeight = TextService:GetTextSize(
		request.Description,
		T.Type.Body,
		T.Type.Label,
		Vector2.new(panelSize.X - inset * 2 - 16, 10000)
	).Y + 8
	local single = #request.Buttons == 1
	local contentWidth = panelSize.X - inset * 2
	local columns = math.max(1, math.min(#request.Buttons, math.floor(contentWidth / 150)))
	local footerWidth = if single then math.min(contentWidth, SINGLE_BUTTON_MAX_WIDTH) else contentWidth
	local footerHeight = math.ceil(math.max(#request.Buttons, 1) / columns) * (BUTTON_HEIGHT + BUTTON_GAP) - BUTTON_GAP
	-- The panel hugs its content (title, message, actions); only a very long message scrolls.
	local bodyTop = inset + titleHeight + BODY_GAP
	local desired = bodyTop + descriptionHeight + FOOTER_GAP + footerHeight + inset
	panelSize = Vector2.new(panelSize.X, math.min(safeArea.size.Y - 32, desired))
	local bodyHeight = math.max(44, panelSize.Y - bodyTop - FOOTER_GAP - footerHeight - inset)
	local buttons = {}
	for index, definition in request.Buttons do
		buttons[`Button{index}`] = notificationButton(
			definition,
			index + 1,
			props.OnChoose,
			if index == 1 then firstButtonRef else nil,
			columns,
			single
		)
	end

	return modalSurface({
		ref = modalRef,
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = T.Colors.Ink,
		BackgroundTransparency = 0.35,
		Selectable = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 130,
		-- A tap outside the card dismisses it; the panel below is Active so taps on it never reach here.
		[React.Event.Activated] = function()
			props.OnChoose(false)
		end,
	}, {
		Panel = c(CandyPanel, {
			Active = true,
			ZIndex = 131,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = UIConfig.Layout.PageSurface.Image,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = styles.Rotation,
			ScaleType = Enum.ScaleType.Slice,
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
			SliceCenter = UIConfig.Layout.PageSurface.SliceCenter,
			SliceScale = UIConfig.Layout.PageSurface.SliceScale,
			Visible = true,
		}, {
			ModalScale = c("UIScale", { Scale = styles.Scale }),
			Title = c(CandyTitle, {
				Text = request.Title,
				TextSize = titleSize,
				Native = {
					Position = UDim2.fromOffset(inset, inset),
					Size = UDim2.fromOffset(titleWidth, titleHeight),
					ZIndex = 134,
				},
			}),
			Close = c(ModalClose, {
				Position = UDim2.new(1, -inset, 0, inset + (titleHeight - closeSize) / 2),
				SizePx = closeSize,
				OnActivated = function()
					props.OnChoose(false)
				end,
				ZIndex = 138,
			}),
			Description = c("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(inset, bodyTop),
				Size = UDim2.new(1, -inset * 2, 0, bodyHeight),
				CanvasSize = UDim2.fromOffset(0, descriptionHeight),
				ScrollBarThickness = T.Layout.ScrollBar,
				ScrollBarImageColor3 = T.Colors.Pink,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Selectable = false,
				ZIndex = 134,
			}, {
				Text = c("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(4, 0),
					Size = UDim2.new(1, -16, 0, descriptionHeight),
					Font = T.Type.Label,
					Text = request.Description,
					TextSize = T.Type.Body,
					TextColor3 = T.Colors.Ink,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					ZIndex = 135,
				}),
			}),
			Buttons = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 1, -inset),
				Size = UDim2.fromOffset(footerWidth, footerHeight),
				ZIndex = 135,
			}, buttons),
		}),
	})
end
