-- The button owns a stable layout and hitbox; its face and foreground share one animated visual.

--!strict

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local useButtonMotion = require(script.Parent.Parent.Hooks.useButtonMotion)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local UIFeedback = require(script.Parent.Parent.Services.UIFeedback)
local Selection = require(script.Parent.Parent.Services.Selection)
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))

local c = React.createElement

local function merge(...): { [any]: any }
	local result = {}
	for index = 1, select("#", ...) do
		local source = select(index, ...)
		if source then
			for key, value in source do
				result[key] = value
			end
		end
	end
	return result
end

export type Props = {
	Native: { [any]: any },
	Enabled: boolean?,
	Style: "Standard" | "Primary" | "Card"?,
	HoverRotation: boolean?,
	OnActivated: (() -> ())?,
	OnSelectionGained: ((GuiButton) -> ())?,
	ButtonRef: any?,
	SelectionRadius: UDim?,
	EntranceDelay: number?,
	Visual: any?,
	children: { [any]: any }?,
}

return function(props: Props)
	local buttonRef = React.useRef(nil)
	local selectionImageRef = React.useRef(nil)
	local enabled = props.Enabled ~= false
	local entered, setEntered = React.useState(props.EntranceDelay == nil)
	local entranceRevision = React.useRef(0)
	local hovering, setHovering = React.useState(false)
	local focused, setFocused = React.useState(false)
	local pressing, setPressing = React.useState(false)
	local reducedMotion = useReducedMotion()
	local preset = Motion.Controls[props.Style or "Standard"]
	local scale = if not entered
		then 0.82
		else if not enabled then 1 else if pressing then preset.pressed else if hovering then preset.hover else 1
	local rotation = if enabled
			and hovering
			and not pressing
			and props.HoverRotation ~= false
		then preset.rotation
		else 0
	local styles = useButtonMotion(scale, rotation, pressing and enabled, reducedMotion)
	local visualRotation = styles.Rotation:map(function(value: number)
		return value + (props.Native.Rotation or 0)
	end)
	local layoutChildren = {}
	local visualChildren = {}
	for key, child in props.children or {} do
		local childType = if React.isValidElement(child) then child.type else nil
		if childType == "UIAspectRatioConstraint" or childType == "UISizeConstraint" or childType == "UIScale" then
			layoutChildren[key] = child
		else
			visualChildren[key] = child
		end
	end
	local children = merge(layoutChildren, {
		SelectionImage = c("Frame", {
			ref = selectionImageRef,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = (props.Native.ZIndex or 1) + 10,
		}, {
			Corner = c(
				"UICorner",
				{ CornerRadius = props.SelectionRadius or UDim.new(0, UIConfig.Interaction.FocusCornerPx) }
			),
			Outline = c("UIStroke", {
				Color = UIConfig.ProgressionStyle.Yellow,
				Thickness = UIConfig.Interaction.FocusStrokePx,
				Transparency = if focused and enabled then 0 else 1,
			}),
		}),
		InteractionVisual = c(
			"ImageLabel",
			{
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = props.Native.BackgroundColor3,
				BackgroundTransparency = props.Native.BackgroundTransparency,
				BorderColor3 = props.Native.BorderColor3,
				BorderMode = props.Native.BorderMode,
				BorderSizePixel = props.Native.BorderSizePixel,
				Image = props.Native.Image,
				ImageColor3 = props.Native.ImageColor3,
				ImageRectOffset = props.Native.ImageRectOffset,
				ImageRectSize = props.Native.ImageRectSize,
				ImageTransparency = props.Native.ImageTransparency,
				Position = UDim2.fromScale(0.5, 0.5),
				ResampleMode = props.Native.ResampleMode,
				Rotation = visualRotation,
				ScaleType = props.Native.ScaleType,
				Size = UDim2.fromScale(1, 1),
				SliceCenter = props.Native.SliceCenter,
				SliceScale = props.Native.SliceScale,
				TileSize = props.Native.TileSize,
				ZIndex = props.Native.ZIndex or 1,
			},
			merge(visualChildren, {
				Visual = if props.Visual
					then React.cloneElement(props.Visual, { PressDepth = styles.PressDepth })
					else nil,
				InteractionScale = c("UIScale", {
					Scale = styles.Scale,
				}),
			})
		),
	})
	React.useEffect(function()
		local button: ImageButton? = buttonRef.current
		local selectionImage: GuiObject? = selectionImageRef.current
		if button and selectionImage then
			button.SelectionImageObject = selectionImage
		end
		if props.ButtonRef then
			props.ButtonRef.current = button
		end
		return function()
			if button and button.SelectionImageObject == selectionImage then
				button.SelectionImageObject = nil
			end
			if props.ButtonRef and props.ButtonRef.current == button then
				props.ButtonRef.current = nil
			end
		end
	end, { props.ButtonRef })
	React.useEffect(function()
		if props.EntranceDelay == nil then
			setEntered(true)
			return
		end
		entranceRevision.current += 1
		local revision = entranceRevision.current
		setEntered(false)
		task.delay(props.EntranceDelay, function()
			if revision == entranceRevision.current then
				setEntered(true)
			end
		end)
		return function()
			entranceRevision.current += 1
		end
	end, { props.EntranceDelay })

	local function isPressInput(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
	end

	-- Releases outside the hitbox and focus loss must never leave a control sunk.
	React.useEffect(function()
		local release = UserInputService.InputEnded:Connect(function(input)
			if isPressInput(input) then
				setPressing(false)
			end
		end)
		local blur = UserInputService.WindowFocusReleased:Connect(function()
			setPressing(false)
			setHovering(false)
		end)
		return function()
			release:Disconnect()
			blur:Disconnect()
		end
	end, {})
	React.useEffect(function()
		if not enabled then
			setPressing(false)
			setHovering(false)
		end
	end, { enabled })

	local function beginHover()
		if enabled and not hovering then
			setHovering(true)
			UIFeedback.hover()
		end
	end

	local function endHover()
		setHovering(false)
		setPressing(false)
	end

	return c(
		"ImageButton",
		merge(props.Native, {
			ref = buttonRef,
			Active = enabled,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ImageTransparency = 1,
			Selectable = enabled,
			Rotation = 0,
			[React.Event.Activated] = if enabled
				then function()
					UIFeedback.click()
					if props.OnActivated then
						props.OnActivated()
					end
				end
				else nil,
			[React.Event.MouseEnter] = beginHover,
			[React.Event.MouseLeave] = endHover,
			[React.Event.MouseButton1Down] = if enabled
				then function()
					setPressing(true)
				end
				else nil,
			[React.Event.MouseButton1Up] = if enabled
				then function()
					setPressing(false)
				end
				else nil,
			[React.Event.InputBegan] = if enabled
				then function(button, input)
					local pointerInput = input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch
					local selected = GuiService.SelectedObject
					if pointerInput and selected then
						local screen = button:FindFirstAncestorWhichIsA("ScreenGui")
						if screen and selected:IsDescendantOf(screen) then
							GuiService.SelectedObject = nil
							if selected == button then
								setHovering(input.UserInputType == Enum.UserInputType.MouseButton1)
							end
						end
					end
					if isPressInput(input) then
						setPressing(true)
					end
				end
				else nil,
			[React.Event.InputEnded] = if enabled
				then function(_button, input)
					if isPressInput(input) then
						setPressing(false)
					end
				end
				else nil,
			[React.Event.SelectionGained] = function(button)
				setFocused(true)
				if GuiService.SelectedObject ~= nil then
					beginHover()
				end
				if props.OnSelectionGained then
					props.OnSelectionGained(button)
				else
					Selection.scrollIntoView(button)
				end
			end,
			[React.Event.SelectionLost] = function()
				setFocused(false)
				endHover()
			end,
		}),
		children
	)
end
