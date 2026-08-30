-- Name: CombatToolbar.luau
-- Author: Jack C.
-- Description: Renders the compact shared combat dock from derived weapon state without owning gameplay authority.
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
local WHITE = Color3.new(1, 1, 1)
local SURFACE = Color3.fromRGB(233, 251, 253)
local SURFACE_MUTED = Color3.fromRGB(211, 226, 229)
local FOCUS = Color3.fromRGB(255, 224, 78)
local BALL_ACCENT = Color3.fromRGB(97, 255, 237)
local HAMMER_ACCENT = Color3.fromRGB(242, 24, 76)

local function accentFor(weapon: string): Color3
	return if weapon == "Dodgeball" then BALL_ACCENT else HAMMER_ACCENT
end

local function inputImage(keyCode: Enum.KeyCode?): string
	if keyCode == nil then
		return ""
	end
	local ok, image = pcall(UserInputService.GetImageForKeyCode, UserInputService, keyCode)
	return if ok and typeof(image) == "string" then image else ""
end

local function InputBadge(props: {
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
		Position = UDim2.fromScale(0.17, 0.83),
		Size = UDim2.fromScale(0.23, 0.18),
		ZIndex = 67,
	}, {
		Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1.35 }),
		Shadow = c("Frame", {
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.64,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.1),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 67,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.28, 0) }),
		}),
		Plate = c("Frame", {
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 68,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.28, 0) }),
			Glyph = if gamepadImage ~= ""
				then c("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = gamepadImage,
					ImageColor3 = WHITE,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.65, 0.7),
					ZIndex = 69,
				})
				else c(ResponsiveText, {
					MeasurementFont = Enum.Font.Highway,
					MaxTextSize = 15,
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
						ZIndex = 69,
					},
				}),
		}),
	})
end

local function StateBadge(props: {
	Kind: string,
	Transparency: any,
	Scale: any,
	Rotation: any,
})
	local lock = props.Kind == "Locked"
	return c("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = props.Transparency,
		Position = UDim2.fromScale(0.79, 0.63),
		Rotation = props.Rotation,
		Size = UDim2.fromScale(0.19, 0.19),
		ZIndex = 70,
	}, {
		Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Scale = c("UIScale", { Scale = props.Scale }),
		Shadow = c("Frame", {
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.62,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.1),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 70,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		Plate = c("Frame", {
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 71,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Shackle = if lock
				then c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.38),
					Size = UDim2.fromScale(0.4, 0.42),
					ZIndex = 72,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
					Stroke = c("UIStroke", {
						Color = WHITE,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.17,
					}),
				})
				else nil,
			Body = if lock
				then c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = WHITE,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.63),
					Size = UDim2.fromScale(0.58, 0.38),
					ZIndex = 73,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0.18, 0) }),
				})
				else c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = WHITE,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.5, 0.12),
					ZIndex = 73,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
		}),
	})
end

local function Burst(props: { Transparency: any, Scale: any })
	local function sparkle(position: UDim2, rotation: number): any
		return c("Frame", {
			BackgroundColor3 = FOCUS,
			BorderSizePixel = 0,
			Position = position,
			Rotation = rotation,
			Size = UDim2.fromScale(0.055, 0.115),
			ZIndex = 55,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
	end
	return c("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = props.Transparency,
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(0.9, 0.78),
		ZIndex = 55,
	}, {
		Scale = c("UIScale", { Scale = props.Scale }),
		Top = sparkle(UDim2.fromScale(0.47, 0), 25),
		Left = sparkle(UDim2.fromScale(0.03, 0.45), -35),
		Right = sparkle(UDim2.fromScale(0.91, 0.38), 35),
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
	local accent = accentFor(slot.weapon)
	local muted = kind == "Locked" or kind == "Unavailable" or kind == "Disabled"
	local progress = if kind == "Cooldown" or kind == "Charging" then (slot.state :: any).progress else 1

	React.useEffect(function()
		local previous = previousKind.current
		previousKind.current = kind
		feedbackRevision.current += 1
		local revision = feedbackRevision.current
		local nextFeedback = "None"
		local duration = 0
		if previous == "Locked" and kind ~= "Locked" then
			nextFeedback = if slot.selected then "Unlock" else "Ready"
			duration = if nextFeedback == "Unlock" then 0.52 else 0.26
		elseif previous == "Cooldown" and kind == "Ready" then
			nextFeedback = "Ready"
			duration = 0.26
		elseif previous == "Unavailable" and kind == "Ready" then
			nextFeedback = "Available"
			duration = 0.32
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
	end, { kind, slot.selected, reducedMotion })

	local scale = if pressing
		then 0.95
		else if feedback == "Unlock"
			then 1.075
			else if feedback == "Ready" or feedback == "Available"
				then 1.035
				else if slot.selected then 1.04 else 0.985
	local styles = ReactSpring.useSpring({
		Scale = scale,
		Lift = if slot.selected then -0.045 else 0,
		AuraTransparency = if feedback == "Unlock"
			then 0.2
			else if feedback ~= "None" then 0.38 else if slot.selected then 0.58 else 1,
		PodColor = if muted then SURFACE_MUTED else WHITE,
		IconTransparency = if kind == "Disabled"
			then 0.65
			else if kind == "Locked" then 0.46 else if kind == "Unavailable" then 0.5 else if kind == "Cooldown" then 0.28 else 0,
		AccentTransparency = if kind == "Disabled"
			then 0.72
			else if kind == "Locked" then 0.5 else if kind == "Unavailable" then 0.38 else 0,
		RailTransparency = if kind == "Cooldown" or kind == "Charging" then 0 else 1,
		Progress = math.clamp(progress, 0, 1),
		LockTransparency = if kind == "Locked" then 0 else 1,
		UnavailableTransparency = if kind == "Unavailable" then 0 else 1,
		InputTransparency = if muted then 1 else 0,
		LockScale = if feedback == "Unlock" then 1.45 else 1,
		LockRotation = if feedback == "Unlock" then 18 else 0,
		BurstTransparency = if feedback == "Unlock" then 0 else if feedback == "Ready" then 0.34 else 1,
		BurstScale = if feedback == "Unlock" then 1.2 else if feedback == "Ready" then 1.08 else 0.76,
		config = if feedback == "Unlock" then Motion.Pop else Motion.Control,
		immediate = reducedMotion,
	})

	local function endPress()
		setPressing(false)
	end

	local hasPrompt = slot.inputLabel ~= nil
	return c("ImageButton", {
		Active = slot.interactive,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "",
		LayoutOrder = props.LayoutOrder,
		Selectable = false,
		Size = UDim2.fromScale(0.47, 1),
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
		Visual = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = styles.Lift:map(function(lift: number)
				return UDim2.fromScale(0.5, 0.5 + lift)
			end),
			Size = UDim2.fromScale(0.96, 0.94),
			ZIndex = 53,
		}, {
			Scale = c("UIScale", { Scale = styles.Scale }),
			Aura = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = FOCUS,
				BackgroundTransparency = styles.AuraTransparency,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.46),
				Size = UDim2.fromScale(0.92, 0.92),
				ZIndex = 53,
			}, {
				Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
				Corner = c("UICorner", { CornerRadius = UDim.new(0.32, 0) }),
			}),
			Burst = c(Burst, { Transparency = styles.BurstTransparency, Scale = styles.BurstScale }),
			PodShadow = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = INK,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.505),
				Size = UDim2.fromScale(0.76, 0.76),
				ZIndex = 56,
			}, {
				Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
				Corner = c("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
			}),
			AccentLip = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = accent,
				BackgroundTransparency = styles.AccentTransparency,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.49),
				Size = UDim2.fromScale(0.76, 0.76),
				ZIndex = 57,
			}, {
				Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
				Corner = c("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
			}),
			Pod = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = styles.PodColor,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.46),
				Size = UDim2.fromScale(0.76, 0.76),
				ZIndex = 58,
			}, {
				Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
				Corner = c("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
				InnerTint = c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = accent,
					BackgroundTransparency = 0.92,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.84, 0.84),
					ZIndex = 59,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
				}),
			}),
			Icon = c("CanvasGroup", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				GroupTransparency = styles.IconTransparency,
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.fromScale(0.66, 0.66),
				ZIndex = 62,
			}, {
				Preview = c(WeaponViewport, { Weapon = slot.weapon, ItemId = props.ItemId, ZIndex = 62 }),
			}),
			Lock = c(StateBadge, {
				Kind = "Locked",
				Transparency = styles.LockTransparency,
				Scale = styles.LockScale,
				Rotation = styles.LockRotation,
			}),
			Unavailable = c(StateBadge, {
				Kind = "Unavailable",
				Transparency = styles.UnavailableTransparency,
				Scale = 1,
				Rotation = 0,
			}),
			Input = c(InputBadge, {
				Slot = slot,
				DeviceClass = props.DeviceClass,
				Transparency = styles.InputTransparency,
			}),
			Title = c(ResponsiveText, {
				MeasurementFont = Enum.Font.Highway,
				MaxTextSize = 13,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/HighwayGothic.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(if hasPrompt then 0.58 else 0.5, 0.83),
					Size = UDim2.fromScale(if hasPrompt then 0.62 else 0.84, 0.14),
					Text = slot.title,
					TextColor3 = INK,
					TextTransparency = if kind == "Disabled" then 0.5 else if muted then 0.24 else 0,
					TextXAlignment = if hasPrompt then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
					ZIndex = 64,
				},
			}),
			Rail = c("CanvasGroup", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				GroupTransparency = styles.RailTransparency,
				Position = UDim2.fromScale(0.5, 0.95),
				Size = UDim2.fromScale(0.66, 0.045),
				ZIndex = 64,
			}, {
				Track = c("Frame", {
					BackgroundColor3 = INK,
					BackgroundTransparency = 0.22,
					BorderSizePixel = 0,
					ClipsDescendants = true,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 64,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Fill = c("Frame", {
						BackgroundColor3 = if kind == "Charging" then FOCUS else accent,
						BorderSizePixel = 0,
						Size = styles.Progress:map(function(value: number)
							return UDim2.fromScale(value, 1)
						end),
						ZIndex = 65,
					}, {
						Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					}),
				}),
			}),
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
		Offset = if model.visible then 0 else 30,
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
			Padding = UDim.new(0.04, 0),
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
		TrayShadow = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.8),
			Size = UDim2.fromScale(0.92, 0.4),
			ZIndex = 50,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 22) }),
		}),
		TrayLip = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = BALL_ACCENT,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.785),
			Size = UDim2.fromScale(0.92, 0.4),
			ZIndex = 51,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 22) }),
		}),
		Tray = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = SURFACE,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.76),
			Size = UDim2.fromScale(0.92, 0.4),
			ZIndex = 52,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 22) }),
		}),
		Slots = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.48),
			Size = UDim2.fromScale(0.9, 0.96),
			ZIndex = 53,
		}, slots),
	})
end
