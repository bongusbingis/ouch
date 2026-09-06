-- Name: NotificationModal.luau
-- Author: Jack C.
-- Description: The shared notification and confirmation modal, rendering a title, message, and action buttons for whatever the notification context has queued.
-- Created: 2026-08-17

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)

local c = React.createElement

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
}

local function notificationButton(definition: ButtonDefinition, order: number, onChoose: (any) -> (), buttonRef: any?)
	local red = definition.Color == "Red"
	return c(AnimatedButton, {
		ButtonRef = buttonRef,
		EntranceDelay = (order - 2) * 0.025,
		Native = {
			BackgroundTransparency = 1,
			Image = if red then "rbxassetid://94748581468730" else "rbxassetid://136021539696619",
			LayoutOrder = order,
			Position = if red then UDim2.fromScale(0.520694, 0) else UDim2.fromScale(0.153547, 0),
			ScaleType = Enum.ScaleType.Slice,
			Size = if red then UDim2.fromScale(0.335, 1) else UDim2.fromScale(0.334921, 1),
			SliceCenter = Rect.new(198, 228, 841, 468),
			SliceScale = 0.2,
		},
		OnActivated = function()
			onChoose(definition.Value)
		end,
	}, {
		TextLabel = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = if red then UDim2.fromScale(0.463449, 0.57964) else UDim2.fromScale(0.48792, 0.57964),
				Size = if red then UDim2.fromScale(0.680654, 0.6712) else UDim2.fromScale(0.8, 0.671),
				Text = definition.Text,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 2,
			},
		}),
		UIAspectRatioConstraint = c("UIAspectRatioConstraint", { AspectRatio = 2.9 }),
		UISizeConstraint = c("UISizeConstraint", {
			MinSize = Vector2.new(0, UIConfig.Interaction.MinTargetPx),
		}),
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
	local reducedMotion = useReducedMotion()
	local styles = ReactSpring.useSpring({
		Scale = if props.Request then 1 else 0.82,
		Rotation = if props.Request then 0 else -2,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	local request = props.Request
	React.useEffect(function()
		if not request then
			return
		end
		local previous = GuiService.SelectedObject
		local active = true
		task.defer(function()
			local button = firstButtonRef.current
			if active and button and button.Parent and button.Visible and button.Selectable then
				GuiService.SelectedObject = button
			end
		end)
		return function()
			active = false
			if previous and previous.Parent and previous.Visible and previous.Selectable then
				GuiService.SelectedObject = previous
			end
		end
	end, { request })
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
		buttons[`Button{index}`] =
			notificationButton(definition, index + 1, props.OnChoose, if index == 1 then firstButtonRef else nil)
	end

	return c("TextButton", {
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
			Image = "rbxassetid://124751224634629",
			Position = UDim2.fromScale(0.5, 0.57),
			Rotation = styles.Rotation,
			ScaleType = Enum.ScaleType.Slice,
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
			SliceCenter = Rect.new(31, 41, 978, 620),
			SliceScale = 0.5,
			Visible = true,
		}, {
			ModalScale = c("UIScale", { Scale = styles.Scale }),
			Title = c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 54,
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
			}),
			Frame = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.265),
				Size = UDim2.fromScale(0.8, 0.015),
			}),
			Description = c(ResponsiveText, {
				HostName = "Description",
				MaxTextSize = 50,
				MeasurementFont = Enum.Font.Highway,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
					Position = UDim2.fromScale(0.498537, 0.506245),
					Size = UDim2.fromScale(0.9, 0.323246),
					Text = request.Description,
					TextColor3 = Color3.new(1, 1, 1),
					TextYAlignment = Enum.TextYAlignment.Top,
					ZIndex = 2,
				},
			}, {
				UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = 50 }),
			}),
			Buttons = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.944206),
				Size = UDim2.new(0.86, 0, 0, 54),
			}, buttons),
		}),
	})
end
