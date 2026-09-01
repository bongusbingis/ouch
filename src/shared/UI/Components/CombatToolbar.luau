-- Name: CombatToolbar.luau
-- Author: Jack C.
-- Description: Renders one compact combat action bar from derived weapon state without owning gameplay authority.
-- Created: 2026-08-28

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local CombatToolbarViewModel = require(script.Parent.Parent.Models.CombatToolbarViewModel)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local useViewportSize = require(script.Parent.Parent.Hooks.useViewportSize)
local ResponsiveText = require(script.Parent.ResponsiveText)
local WeaponViewport = require(script.Parent.WeaponViewport)
local UIFeedback = require(script.Parent.Parent.Services.UIFeedback)

local c = React.createElement
local INK = Color3.fromRGB(24, 41, 48)
local SHADOW = Color3.fromRGB(10, 19, 24)
local BAR_TOP = Color3.fromRGB(48, 77, 84)
local BAR_BOTTOM = Color3.fromRGB(31, 55, 63)
local SELECTED_SURFACE = Color3.fromRGB(65, 103, 108)
local SELECTED_ACCENT = Color3.fromRGB(97, 255, 237)
local WARNING = Color3.fromRGB(255, 224, 78)
local WHITE = Color3.new(1, 1, 1)
local BAR_INSET_X = 8
local BAR_INSET_Y = 14
local SHADOW_OFFSET = 5
local SELECTED_LIFT = -3

local function inputImage(keyCode: Enum.KeyCode?): string
	if keyCode == nil then
		return ""
	end
	local ok, image = pcall(UserInputService.GetImageForKeyCode, UserInputService, keyCode)
	return if ok and typeof(image) == "string" then image else ""
end

local function textStroke(color: Color3, thickness: number, transparency: number?)
	return c("UIStroke", {
		Color = color,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness,
		Transparency = transparency or 0,
	})
end

local function InputCue(props: {
	Slot: CombatToolbarViewModel.Slot,
	DeviceClass: string,
	Transparency: any,
})
	if props.Slot.inputLabel == nil then
		return nil
	end
	local gamepadImage = if props.DeviceClass == "Gamepad" then inputImage(props.Slot.inputKeyCode) else ""
	return c("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = props.Transparency,
		Position = UDim2.fromScale(0.13, 0.17),
		Size = UDim2.fromScale(0.18, 0.2),
		ZIndex = 59,
	}, {
		Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1.08 }),
		Plate = c("Frame", {
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 59,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.24, 0) }),
			Stroke = textStroke(WHITE, 0.035, 0.55),
			Glyph = if gamepadImage ~= ""
				then c("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = gamepadImage,
					ImageColor3 = WHITE,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.68, 0.7),
					ZIndex = 60,
				})
				else c(ResponsiveText, {
					MeasurementFont = Enum.Font.Highway,
					MaxTextSize = 17,
					MinTextSize = 12,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/HighwayGothic.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Size = UDim2.fromScale(1, 1),
						Text = props.Slot.inputLabel,
						TextColor3 = WHITE,
						ZIndex = 60,
					},
				}),
		}),
	})
end

local function StateLabel(props: { Kind: string, Transparency: any, Scale: any })
	local label = if props.Kind == "Locked" then "LOCKED" else if props.Kind == "Unavailable" then "NO BALL" else ""
	local color = if props.Kind == "Locked" then WARNING else WHITE
	return c("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = props.Transparency,
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromScale(0.68, 0.14),
		ZIndex = 61,
	}, {
		Scale = c("UIScale", { Scale = props.Scale }),
		Label = c(ResponsiveText, {
			MeasurementFont = Enum.Font.Highway,
			MaxTextSize = 15,
			MinTextSize = 11,
			Native = {
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/HighwayGothic.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Size = UDim2.fromScale(1, 1),
				Text = label,
				TextColor3 = color,
				ZIndex = 61,
			},
		}, {
			Stroke = textStroke(INK, 0.06, 0.04),
		}),
	})
end

local function ProgressLine(props: {
	Kind: string,
	Progress: any,
	Transparency: any,
})
	return c("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = props.Transparency,
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromScale(0.68, 0.035),
		ZIndex = 61,
	}, {
		Track = c("Frame", {
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.18,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 61,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = c("Frame", {
				BackgroundColor3 = if props.Kind == "Charging" then WARNING else SELECTED_ACCENT,
				BorderSizePixel = 0,
				Size = props.Progress:map(function(value: number)
					return UDim2.fromScale(value, 1)
				end),
				ZIndex = 62,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
	})
end

local function ActionSlot(props: {
	Slot: CombatToolbarViewModel.Slot,
	DeviceClass: string,
	ItemId: string?,
	LayoutOrder: number,
	OnActivated: (string) -> (),
})
	local pressing, setPressing = React.useState(false)
	local feedback, setFeedback = React.useState("None")
	local feedbackRevision = React.useRef(0)
	local previousKind = React.useRef(props.Slot.state.kind)
	local reducedMotion = useReducedMotion()
	local slot = props.Slot
	local kind = slot.state.kind
	local muted = kind == "Locked" or kind == "Unavailable" or kind == "Disabled"
	local statusVisible = kind == "Locked" or kind == "Unavailable"
	local progressVisible = kind == "Cooldown" or kind == "Charging"
	local progress = if progressVisible then (slot.state :: any).progress else 0

	React.useEffect(function()
		local previous = previousKind.current
		previousKind.current = kind
		feedbackRevision.current += 1
		local revision = feedbackRevision.current
		local nextFeedback = "None"
		local duration = 0
		if previous == "Locked" and kind ~= "Locked" then
			nextFeedback = "Unlock"
			duration = 0.46
		elseif previous == "Cooldown" and kind == "Ready" then
			nextFeedback = "Ready"
			duration = 0.24
		elseif previous == "Unavailable" and kind == "Ready" then
			nextFeedback = "Available"
			duration = 0.28
		end
		if nextFeedback == "None" or reducedMotion then
			setFeedback("None")
			return
		end
		setFeedback(nextFeedback)
		task.delay(duration, function()
			if feedbackRevision.current == revision then
				setFeedback("None")
			end
		end)
		return function()
			feedbackRevision.current += 1
		end
	end, { kind, reducedMotion })

	local scale = if pressing
		then 0.94
		else if feedback == "Unlock"
			then 1.08
			else if feedback == "Ready" or feedback == "Available"
				then 1.045
				else if slot.selected then 1.035 else 1
	local styles = ReactSpring.useSpring({
		Scale = scale,
		Lift = if slot.selected then SELECTED_LIFT else 0,
		SurfaceTransparency = if slot.selected then 0 else 1,
		WashTransparency = if muted then 0.72 else 1,
		IconTransparency = if kind == "Disabled"
			then 0.62
			else if kind == "Locked"
				then 0.3
				else if kind == "Unavailable" then 0.24 else if kind == "Cooldown" then 0.12 else 0,
		TitleTransparency = if kind == "Disabled" then 0.55 else if muted then 0.12 else 0,
		InputTransparency = if muted then 0.32 else 0,
		SelectionTransparency = if slot.selected then 0 else 1,
		StatusTransparency = if statusVisible then 0 else 1,
		StatusScale = if feedback == "Unlock" then 1.12 else 1,
		ProgressTransparency = if progressVisible then 0 else 1,
		Progress = math.clamp(progress, 0, 1),
		config = if feedback == "Unlock" then Motion.Pop else Motion.Control,
		immediate = reducedMotion,
	})

	local function endPress()
		setPressing(false)
	end

	return c("ImageButton", {
		Active = slot.interactive,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "",
		LayoutOrder = props.LayoutOrder,
		Selectable = false,
		Size = UDim2.fromScale(0.5, 1),
		ZIndex = 54,
		[React.Event.Activated] = if slot.interactive
			then function()
				UIFeedback.click()
				props.OnActivated(slot.weapon)
			end
			else nil,
		[React.Event.InputBegan] = if slot.interactive
			then function(_, input)
				if input.UserInputType == Enum.UserInputType.Touch then
					setPressing(true)
				end
			end
			else nil,
		[React.Event.InputEnded] = endPress,
	}, {
		SelectedSurface = c("Frame", {
			BackgroundColor3 = SELECTED_SURFACE,
			BackgroundTransparency = styles.SurfaceTransparency,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 54,
		}, {
			Gradient = c("UIGradient", {
				Color = ColorSequence.new(SELECTED_SURFACE, BAR_BOTTOM),
				Rotation = 90,
			}),
		}),
		MutedWash = c("Frame", {
			BackgroundColor3 = INK,
			BackgroundTransparency = styles.WashTransparency,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 55,
		}),
		Content = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = styles.Lift:map(function(lift: number)
				return UDim2.new(0.5, 0, 0.5, lift)
			end),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 57,
		}, {
			Scale = c("UIScale", { Scale = styles.Scale }),
			Input = c(InputCue, {
				Slot = slot,
				DeviceClass = props.DeviceClass,
				Transparency = styles.InputTransparency,
			}),
			Icon = c("CanvasGroup", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				GroupTransparency = styles.IconTransparency,
				Position = UDim2.fromScale(
					if slot.weapon == "Hammer" then 0.52 else 0.5,
					if slot.weapon == "Hammer" then 0.39 else 0.4
				),
				Size = UDim2.fromScale(
					if slot.weapon == "Hammer" then 0.9 else 0.68,
					if slot.weapon == "Hammer" then 0.68 else 0.62
				),
				ZIndex = 58,
			}, {
				Preview = c(WeaponViewport, {
					Weapon = slot.weapon,
					ItemId = props.ItemId,
					Zoom = if slot.weapon == "Hammer" then 1.58 else 1.17,
					ZIndex = 58,
				}),
			}),
			Status = c(StateLabel, {
				Kind = kind,
				Transparency = styles.StatusTransparency,
				Scale = styles.StatusScale,
			}),
			Progress = c(ProgressLine, {
				Kind = kind,
				Progress = styles.Progress,
				Transparency = styles.ProgressTransparency,
			}),
			Title = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 19,
				MinTextSize = 13,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.83),
					Size = UDim2.fromScale(0.78, 0.2),
					Text = slot.title,
					TextColor3 = WHITE,
					TextTransparency = styles.TitleTransparency,
					ZIndex = 62,
				},
			}, {
				Stroke = textStroke(INK, 0.05, 0.04),
			}),
		}),
		Selection = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = SELECTED_ACCENT,
			BackgroundTransparency = styles.SelectionTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.985),
			Size = UDim2.new(0.42, 0, 0, 4),
			ZIndex = 63,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
	})
end

local function bottomSafeInset(viewport: Vector2): number
	local ok, area = pcall(GuiService.GetInsetArea, GuiService, Enum.ScreenInsets.DeviceSafeInsets)
	if not ok or typeof(area) ~= "Rect" then
		return 0
	end
	return math.max(viewport.Y - (area :: Rect).Max.Y, 0)
end

export type Props = {
	Model: CombatToolbarViewModel.Model,
	BallItemId: string?,
	HammerItemId: string?,
	OnEquip: (string) -> (),
	RegisterExclusion: (string, any?) -> (),
}

return function(props: Props)
	local holderRef = React.useRef(nil)
	local reducedMotion = useReducedMotion()
	local viewport = useViewportSize()
	local model = props.Model
	local layout = CombatToolbarViewModel.layout(viewport, model.deviceClass)
	local bottomGap = layout.bottomGap + bottomSafeInset(viewport)
	local styles = ReactSpring.useSpring({
		Transparency = if model.visible then 0 else 1,
		Offset = if model.visible then 0 else 20,
		config = Motion.Modal,
		immediate = reducedMotion,
	})

	React.useEffect(function()
		local holder: GuiObject? = holderRef.current
		if holder == nil or not model.visible or model.deviceClass ~= "Touch" then
			props.RegisterExclusion("CombatToolbar", nil)
			return
		end
		local function register()
			local position = holder.AbsolutePosition
			local size = holder.AbsoluteSize
			props.RegisterExclusion("CombatToolbar", {
				minX = position.X,
				minY = position.Y,
				maxX = position.X + size.X,
				maxY = position.Y + size.Y,
			})
		end
		register()
		local positionConnection = holder:GetPropertyChangedSignal("AbsolutePosition"):Connect(register)
		local sizeConnection = holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(register)
		return function()
			positionConnection:Disconnect()
			sizeConnection:Disconnect()
			props.RegisterExclusion("CombatToolbar", nil)
		end
	end, { model.visible, model.deviceClass, props.RegisterExclusion, layout.width, layout.height, bottomGap })

	local slots: { [string]: any } = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index, slot in model.slots do
		slots[slot.weapon] = c(ActionSlot, {
			Slot = slot,
			DeviceClass = model.deviceClass,
			ItemId = if slot.weapon == "Dodgeball" then props.BallItemId else props.HammerItemId,
			LayoutOrder = index,
			OnActivated = props.OnEquip,
		})
	end

	return c("CanvasGroup", {
		ref = holderRef,
		Active = model.visible and model.deviceClass == "Touch",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		GroupTransparency = styles.Transparency,
		Position = styles.Offset:map(function(offset: number)
			return UDim2.new(0.5, 0, 1, -bottomGap + offset)
		end),
		Size = UDim2.fromOffset(layout.width, layout.height),
		ZIndex = 50,
	}, {
		Shadow = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = SHADOW,
			BackgroundTransparency = 0.34,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET),
			Size = UDim2.new(1, -BAR_INSET_X, 1, -BAR_INSET_Y),
			ZIndex = 50,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.22, 0) }),
		}),
		Bar = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = BAR_TOP,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.new(0.5, 0, 0.5, -1),
			Size = UDim2.new(1, -BAR_INSET_X, 1, -BAR_INSET_Y),
			ZIndex = 51,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.22, 0) }),
			Stroke = textStroke(INK, 0.012, 0.08),
			Gradient = c("UIGradient", {
				Color = ColorSequence.new(BAR_TOP, BAR_BOTTOM),
				Rotation = 90,
			}),
			Slots = c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 53,
			}, slots),
			Divider = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.82,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, 2, 0.58, 0),
				ZIndex = 64,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
	})
end
