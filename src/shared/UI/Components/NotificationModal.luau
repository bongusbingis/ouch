-- Description: The shared notification and confirmation modal, rendering a title, message, and action buttons for whatever the notification context has queued.

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Selection = require(script.Parent.Parent.Services.Selection)

local modalSurface = require(script.Parent.ModalSurface)

local c = React.createElement
local Palette = UIConfig.ProgressionStyle

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

local function notificationButton(
	definition: ButtonDefinition,
	order: number,
	onChoose: (any) -> (),
	buttonRef: any?,
	width: number
)
	local red = definition.Color == "Red"
	return c(ShopPriceButton, {
		ButtonRef = buttonRef,
		EntranceDelay = (order - 2) * 0.025,
		Red = red,
		Text = definition.Text,
		TextSize = 24,
		LayoutOrder = order,
		AnchorPoint = Vector2.zero,
		Size = UDim2.fromScale(width, 1),
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

	local buttons = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.03, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index, definition in request.Buttons do
		buttons[`Button{index}`] = notificationButton(
			definition,
			index + 1,
			props.OnChoose,
			if index == 1 then firstButtonRef else nil,
			(1 - 0.03 * (math.max(#request.Buttons, 2) - 1)) / math.max(#request.Buttons, 2)
		)
	end

	return modalSurface({
		ref = modalRef,
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.35,
		Selectable = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 130,
	}, {
		Panel = c("ImageLabel", {
			Active = true,
			ZIndex = 131,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = UIConfig.Layout.PageSurface.Image,
			Position = UDim2.fromScale(0.5, 0.57),
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
			Title = c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 44,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.177439),
					Size = UDim2.fromScale(0.9, 0.204474),
					Text = request.Title,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 2,
				},
			}, {
				Outline = c("UIStroke", {
					Color = Palette.Ink,
					Thickness = 0.045,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				}),
			}),
			Frame = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.265),
				Size = UDim2.new(0.8, 0, 0, 2),
			}),
			Description = c(ResponsiveText, {
				HostName = "Description",
				Wrapped = true,
				MaxTextSize = 26,
				MeasurementFont = UIConfig.Text.BodyFont,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Font = UIConfig.Text.BodyFont,
					Position = UDim2.fromScale(0.5, 0.34),
					Size = UDim2.new(0.9, 0, 0, math.max(30, panelSize.Y * 0.65 - 74)),
					Text = request.Description,
					TextWrapped = true,
					TextStrokeColor3 = Palette.Ink,
					TextStrokeTransparency = 0.35,
					TextColor3 = Color3.new(1, 1, 1),
					TextYAlignment = Enum.TextYAlignment.Top,
					ZIndex = 2,
				},
			}, {
				UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = 26 }),
			}),
			Buttons = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 1, -UIConfig.Spacing.PageInsetPx - 4),
				Size = UDim2.new(0.86, 0, 0, 54),
			}, buttons),
		}),
	})
end
