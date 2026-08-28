--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local CosmeticVisualFactory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CosmeticVisualFactory")
)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveText = require(script.Parent.ResponsiveText)
local UIFeedback = require(script.Parent.Parent.Services.UIFeedback)

local c = React.createElement
local PANEL_IMAGE = "rbxassetid://136021539696619"
local ACCENT = Color3.fromRGB(97, 255, 237)
local SELECTED = Color3.fromRGB(0, 255, 80)
local SURFACE = Color3.fromRGB(45, 48, 56)
local MUTED = Color3.fromRGB(125, 130, 138)

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function WeaponPreview(props)
	local viewportRef = React.useRef(nil)
	local cameraRef = React.useRef(nil)
	local worldRef = React.useRef(nil)

	React.useEffect(function()
		local viewport: ViewportFrame? = viewportRef.current
		local camera: Camera? = cameraRef.current
		local world: WorldModel? = worldRef.current
		if viewport == nil or camera == nil or world == nil then
			return
		end
		viewport.CurrentCamera = camera
		local category = if props.Weapon == "Dodgeball" then "BallAssets" else "HammerAssets"
		local object = CosmeticVisualFactory.create(category, props.ItemId)
		prepare(object)
		if props.Weapon == "Dodgeball" then
			object.Size *= 1.2
			object.CFrame = CFrame.Angles(math.rad(-12), math.rad(24), 0)
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.1, 4.4), Vector3.zero)
		else
			object.Size *= 0.72
			object.CFrame = CFrame.Angles(math.rad(-8), math.rad(-24), math.rad(-28))
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 8.5), Vector3.zero)
		end
		object.Parent = world
		return function()
			if viewport.CurrentCamera == camera then
				viewport.CurrentCamera = nil
			end
			object:Destroy()
		end
	end, { props.Weapon, props.ItemId })

	return c("ViewportFrame", {
		ref = viewportRef,
		Ambient = Color3.fromRGB(190, 190, 190),
		BackgroundTransparency = 1,
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Position = UDim2.fromScale(0.08, 0.19),
		Size = UDim2.fromScale(0.84, 0.58),
		ZIndex = 54,
	}, {
		PreviewCamera = c("Camera", { ref = cameraRef }),
		PreviewWorld = c("WorldModel", { ref = worldRef }),
	})
end

local function inputImage(keyCode: Enum.KeyCode?): string
	if keyCode == nil then
		return ""
	end
	local ok, image = pcall(UserInputService.GetImageForKeyCode, UserInputService, keyCode)
	return if ok and typeof(image) == "string" then image else ""
end

local function WeaponSlot(props)
	local pressing, setPressing = React.useState(false)
	local reducedMotion = useReducedMotion()
	local slot = props.Slot
	local scale = if pressing then 0.94 else if slot.equipped then 1.045 else 1
	local styles = ReactSpring.useSpring({
		Scale = scale,
		Lift = if slot.equipped then -0.035 else 0,
		GlowTransparency = if slot.equipped then 0.22 else 1,
		CardColor = if slot.equipped then SELECTED else if slot.available then SURFACE else MUTED,
		config = { mass = 1, tension = 520, friction = 30 },
		immediate = reducedMotion,
	})
	local gamepadImage = if props.DeviceClass == "Gamepad" then inputImage(slot.inputKeyCode) else ""
	local active = slot.interactive
	local fill = math.clamp(1 - slot.cooldownAlpha, 0, 1)

	local function endPress()
		setPressing(false)
	end

	return c("ImageButton", {
		Active = active,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "",
		LayoutOrder = props.LayoutOrder,
		Selectable = false,
		Size = UDim2.fromScale(0.465, 1),
		[React.Event.Activated] = if active
			then function()
				UIFeedback.click()
				props.OnActivated(slot.weapon)
			end
			else nil,
		[React.Event.InputBegan] = if active
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
			Position = styles.Lift:map(function(lift)
				return UDim2.fromScale(0.5, 0.47 + lift)
			end),
			Size = UDim2.fromScale(0.94, 0.86),
			ZIndex = 51,
		}, {
			Scale = c("UIScale", { Scale = styles.Scale }),
			Glow = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = SELECTED,
				BackgroundTransparency = styles.GlowTransparency,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1.08, 1.08),
				ZIndex = 50,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.12, 0) }),
			}),
			Outline = c("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 51,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.1, 0) }),
				Stroke = c("UIStroke", {
					Color = if slot.equipped then SELECTED else Color3.new(1, 1, 1),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = if slot.equipped then 0.035 else 0.022,
				}),
				Panel = c("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = PANEL_IMAGE,
					ImageColor3 = styles.CardColor,
					Position = UDim2.fromScale(0.5, 0.5),
					ScaleType = Enum.ScaleType.Slice,
					Size = UDim2.fromScale(0.97, 0.97),
					SliceCenter = Rect.new(224, 202, 770, 474),
					SliceScale = 0.08,
					ZIndex = 52,
				}),
				Title = c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					MaxTextSize = 24,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.06, 0.035),
						Size = UDim2.fromScale(0.88, 0.16),
						Text = slot.title,
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 55,
					},
				}),
				Preview = c(WeaponPreview, { Weapon = slot.weapon, ItemId = props.ItemId }),
				Status = c("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundColor3 = Color3.fromRGB(39, 42, 49),
					BorderSizePixel = 0,
					ClipsDescendants = true,
					Position = UDim2.fromScale(0.5, 0.95),
					Size = UDim2.fromScale(0.84, 0.15),
					ZIndex = 55,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0.35, 0) }),
					Fill = c("Frame", {
						BackgroundColor3 = if slot.available then ACCENT else MUTED,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(fill, 1),
						ZIndex = 55,
					}, {
						Corner = c("UICorner", { CornerRadius = UDim.new(0.35, 0) }),
					}),
					Text = c(ResponsiveText, {
						MeasurementFont = Enum.Font.SourceSansBold,
						MaxTextSize = 16,
						Native = {
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Size = UDim2.fromScale(1, 1),
							Text = slot.statusText,
							TextColor3 = Color3.new(1, 1, 1),
							ZIndex = 56,
						},
					}),
				}),
			}),
		}),
		Keycap = if slot.inputLabel ~= nil
			then c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(39, 42, 49),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(0.28, 0.17),
				ZIndex = 57,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.2, 0) }),
				Stroke = c("UIStroke", {
					Color = Color3.new(1, 1, 1),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.06,
				}),
				Icon = if gamepadImage ~= ""
					then c("ImageLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = gamepadImage,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.72, 0.72),
						ZIndex = 58,
					})
					else c(ResponsiveText, {
						MeasurementFont = Enum.Font.SourceSansBold,
						MaxTextSize = 20,
						Native = {
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Size = UDim2.fromScale(1, 1),
							Text = slot.inputLabel,
							TextColor3 = Color3.new(1, 1, 1),
							ZIndex = 58,
						},
					}),
			})
			else nil,
	})
end

export type Props = {
	Model: any,
	BallItemId: string?,
	HammerItemId: string?,
	OnEquip: (string) -> (),
	RegisterExclusion: (string, any?) -> (),
}

return function(props: Props)
	local holderRef = React.useRef(nil)
	local reducedMotion = useReducedMotion()
	local model = props.Model
	local styles = ReactSpring.useSpring({
		Transparency = if model.visible then 0 else 1,
		Offset = if model.visible then 0 else 0.12,
		config = { mass = 1, tension = 360, friction = 34 },
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
	end, { model.visible, model.deviceClass, props.RegisterExclusion })

	local children = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.035, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index, slot in model.slots do
		children[slot.weapon] = c(WeaponSlot, {
			DeviceClass = model.deviceClass,
			ItemId = if slot.weapon == "Dodgeball" then props.BallItemId else props.HammerItemId,
			LayoutOrder = index,
			OnActivated = props.OnEquip,
			Slot = slot,
		})
	end

	return c("CanvasGroup", {
		ref = holderRef,
		Active = model.visible and model.deviceClass == "Touch",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		GroupTransparency = styles.Transparency,
		Position = styles.Offset:map(function(offset)
			return UDim2.fromScale(0.5, 0.985 + offset)
		end),
		Size = UDim2.fromScale(0.28, 0.235),
		ZIndex = 50,
	}, {
		Bounds = c("UISizeConstraint", {
			MaxSize = Vector2.new(390, 220),
			MinSize = Vector2.new(210, 118),
		}),
		Aspect = c("UIAspectRatioConstraint", {
			AspectRatio = 1.82,
			AspectType = Enum.AspectType.FitWithinMaxSize,
		}),
		Slots = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, children),
	})
end
