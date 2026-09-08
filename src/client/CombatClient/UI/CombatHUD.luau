-- Description: React combat heads-up display: the aim reticle, predicted trajectory, swipe feedback, charge state, and the touch hammer button.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Config = ReplicatedStorage:WaitForChild("Config")
local CombatConfig = require(Config:WaitForChild("Gameplay"):WaitForChild("Combat"))
local ThrowUX = require(Config:WaitForChild("Interface"):WaitForChild("ThrowUX"))
local SharedUI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local ResponsiveText = require(SharedUI:WaitForChild("Components"):WaitForChild("ResponsiveText"))
local CombatToolbar = require(SharedUI:WaitForChild("Components"):WaitForChild("CombatToolbar"))
local WeaponViewport = require(SharedUI:WaitForChild("Components"):WaitForChild("WeaponViewport"))
local GestureGlyph =
	require(SharedUI:WaitForChild("Components"):WaitForChild("Onboarding"):WaitForChild("GestureGlyph"))
local CombatToolbarViewModel = require(SharedUI:WaitForChild("Models"):WaitForChild("CombatToolbarViewModel"))
local useExternalStore = require(SharedUI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local useReducedMotion = require(SharedUI:WaitForChild("Hooks"):WaitForChild("useReducedMotion"))
local useViewportSize = require(SharedUI:WaitForChild("Hooks"):WaitForChild("useViewportSize"))
local ChargeAim = require(script.Parent.Parent.Modules.Presentation.ChargeAim)
local ThrowUXClient = require(script.Parent.Parent.Modules.UI.ThrowUXClient)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local c = React.createElement

local function useEquippedWeaponCosmetics()
	local player = Players.LocalPlayer
	local cosmetics, setCosmetics = React.useState(function()
		return {
			ball = player:GetAttribute("Equip_BallAssets") :: string?,
			hammer = player:GetAttribute("Equip_HammerAssets") :: string?,
		}
	end)
	React.useEffect(function()
		local function update()
			setCosmetics({
				ball = player:GetAttribute("Equip_BallAssets") :: string?,
				hammer = player:GetAttribute("Equip_HammerAssets") :: string?,
			})
		end
		local ballConnection = player:GetAttributeChangedSignal("Equip_BallAssets"):Connect(update)
		local hammerConnection = player:GetAttributeChangedSignal("Equip_HammerAssets"):Connect(update)
		return function()
			ballConnection:Disconnect()
			hammerConnection:Disconnect()
		end
	end, {})
	return cosmetics
end

local function smoothstep(value: number): number
	local alpha = math.clamp(value, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function Reticle(props: { snapshot: ThrowUXClient.Snapshot })
	local state = props.snapshot.state
	local target = props.snapshot.targetConfidence > 0
	local full = state == "FullCharge"
	local charging = state == "Charging" or full
	local recovery = state == "Recovery" or state == "Idle"
	local reducedMotion = useReducedMotion()
	local pulse, setPulse = React.useState(false)
	local pulseRevision = React.useRef(0)
	local observedRevisions = React.useRef({
		release = props.snapshot.releaseRevision,
		ready = props.snapshot.readyRevision,
	})

	React.useEffect(function()
		local observed = observedRevisions.current
		local changed = observed.release ~= props.snapshot.releaseRevision
			or observed.ready ~= props.snapshot.readyRevision
		observed.release = props.snapshot.releaseRevision
		observed.ready = props.snapshot.readyRevision
		if not changed then
			return
		end
		pulseRevision.current += 1
		local revision = pulseRevision.current
		setPulse(true)
		task.delay(0.1, function()
			if pulseRevision.current == revision then
				setPulse(false)
			end
		end)
		return function()
			pulseRevision.current += 1
		end
	end, { props.snapshot.releaseRevision, props.snapshot.readyRevision })

	local scale = if pulse
		then ThrowUX.Reticle.ReleaseScale
		else if full then ThrowUX.Reticle.FullChargeScale else if target then ThrowUX.Reticle.TargetScale else 1
	local rotation = if state == "Cancelled" then -5 else 0
	local restingColor = if target then ThrowUX.Reticle.TargetColor else ThrowUX.Reticle.NeutralColor
	local color = if charging
		then restingColor:Lerp(ThrowUX.Reticle.FullChargeColor, props.snapshot.chargeAlpha)
		else restingColor
	local styles = ReactSpring.useSpring({
		Charge = if charging
			then if reducedMotion then 1 else math.max(props.snapshot.chargeAlpha, ThrowUX.ChargeEffect.MinimumAlpha)
			else 0,
		Color = color,
		Scale = scale,
		Rotation = rotation,
		config = { mass = 1, tension = 520, friction = 30 },
		immediate = reducedMotion,
	})
	local chargeVisual = React.useMemo(function()
		local effect = ThrowUX.ChargeEffect
		return {
			DotSize = styles.Charge:map(function(value: number)
				local size = 0.16 + (effect.FullDotSize - 0.16) * smoothstep(value)
				return UDim2.fromScale(size, size)
			end),
			GlowSize = styles.Charge:map(function(value: number)
				local alpha = smoothstep(value)
				local size = effect.GlowStartSize + (effect.GlowFullSize - effect.GlowStartSize) * alpha
				return UDim2.fromScale(size, size)
			end),
			GlowTransparency = styles.Charge:map(function(value: number)
				return 1 - effect.GlowOpacity * smoothstep(value)
			end),
			HorizontalSize = styles.Charge:map(function(value: number)
				local alpha = smoothstep(value)
				return UDim2.fromScale(
					0.18 + (effect.FullHorizontalSize.X - 0.18) * alpha,
					0.08 + (effect.FullHorizontalSize.Y - 0.08) * alpha
				)
			end),
			VerticalSize = styles.Charge:map(function(value: number)
				local alpha = smoothstep(value)
				return UDim2.fromScale(
					0.08 + (effect.FullVerticalSize.X - 0.08) * alpha,
					0.18 + (effect.FullVerticalSize.Y - 0.18) * alpha
				)
			end),
			LeftPosition = styles.Charge:map(function(value: number)
				return UDim2.fromScale(0.34 + effect.FullInset * smoothstep(value), 0.5)
			end),
			RightPosition = styles.Charge:map(function(value: number)
				return UDim2.fromScale(0.66 - effect.FullInset * smoothstep(value), 0.5)
			end),
			TopPosition = styles.Charge:map(function(value: number)
				return UDim2.fromScale(0.5, 0.34 + effect.FullInset * smoothstep(value))
			end),
			BottomPosition = styles.Charge:map(function(value: number)
				return UDim2.fromScale(0.5, 0.66 - effect.FullInset * smoothstep(value))
			end),
		}
	end, { styles.Charge })
	local baseTransparency = if recovery
		then ThrowUX.Reticle.UnavailableTransparency
		else ThrowUX.Reticle.ReadyTransparency

	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = styles.Rotation,
		Size = UDim2.fromScale(ThrowUX.Reticle.SizeScale, ThrowUX.Reticle.SizeScale),
		Visible = props.snapshot.active,
		ZIndex = 20,
	}, {
		Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Bounds = c("UISizeConstraint", {
			MaxSize = Vector2.new(ThrowUX.Reticle.MaxPixels, ThrowUX.Reticle.MaxPixels),
			MinSize = Vector2.new(ThrowUX.Reticle.MinPixels, ThrowUX.Reticle.MinPixels),
		}),
		Scale = c("UIScale", { Scale = styles.Scale }),
		ChargeGlow = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = styles.Color,
			BackgroundTransparency = chargeVisual.GlowTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = chargeVisual.GlowSize,
			ZIndex = 19,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		Dot = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = styles.Color,
			BackgroundTransparency = baseTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = chargeVisual.DotSize,
			ZIndex = 21,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		Left = c("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = styles.Color,
			BackgroundTransparency = baseTransparency,
			BorderSizePixel = 0,
			Position = chargeVisual.LeftPosition,
			Size = chargeVisual.HorizontalSize,
			ZIndex = 21,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		Right = c("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = styles.Color,
			BackgroundTransparency = baseTransparency,
			BorderSizePixel = 0,
			Position = chargeVisual.RightPosition,
			Size = chargeVisual.HorizontalSize,
			ZIndex = 21,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		Top = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = styles.Color,
			BackgroundTransparency = baseTransparency,
			BorderSizePixel = 0,
			Position = chargeVisual.TopPosition,
			Size = chargeVisual.VerticalSize,
			ZIndex = 21,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		Bottom = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = styles.Color,
			BackgroundTransparency = baseTransparency,
			BorderSizePixel = 0,
			Position = chargeVisual.BottomPosition,
			Size = chargeVisual.VerticalSize,
			ZIndex = 21,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
	})
end

local function Trajectory()
	local dotRefs = React.useRef({})
	local endpointRef = React.useRef(nil)
	React.useEffect(function()
		return ChargeAim.setRenderer(function(snapshot)
			for index = 1, CombatConfig.Dodgeball.Preview.Segments do
				local dot = dotRefs.current[index]
				local point = snapshot.points[index]
				if dot then
					dot.Visible = snapshot.active and point ~= nil and point.visible
					if point then
						dot.Position = UDim2.fromOffset(point.position.X, point.position.Y)
						dot.Size = UDim2.fromOffset(point.size, point.size)
						dot.BackgroundTransparency = point.transparency
					end
				end
			end
			local endpoint = endpointRef.current
			if endpoint then
				endpoint.Visible = snapshot.active and snapshot.endpoint ~= nil
				if snapshot.endpoint then
					endpoint.Position = UDim2.fromOffset(snapshot.endpoint.X, snapshot.endpoint.Y)
				end
			end
		end)
	end, {})
	local children = {}
	for index = 1, CombatConfig.Dodgeball.Preview.Segments do
		children[`Dot{index}`] = c("Frame", {
			ref = function(instance)
				dotRefs.current[index] = instance
			end,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 12,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	children.Endpoint = c("Frame", {
		ref = endpointRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 224, 78),
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(ThrowUX.Trajectory.EndpointPixels, ThrowUX.Trajectory.EndpointPixels * 0.55),
		Visible = false,
		ZIndex = 11,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = c("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.1,
			Transparency = ThrowUX.Trajectory.EndpointTransparency,
		}),
	})
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, children)
end

local function SwipeFeedback(props: { snapshot: ThrowUXClient.Snapshot })
	local gesture = props.snapshot.gesture
	if not gesture.visible or gesture.origin == nil or gesture.position == nil then
		return nil
	end
	local delta = gesture.position - gesture.origin
	local length = math.min(delta.Magnitude, ThrowUX.Swipe.TrailMaxPixels)
	local direction = if delta.Magnitude > 1e-3 then delta.Unit else Vector2.new(0, -1)
	local endPosition = gesture.origin + direction * length
	local midpoint = gesture.origin:Lerp(endPosition, 0.5)
	local recognized = gesture.kind == "SwipeRecognized" or gesture.kind == "TapRecognized"
	local color = if recognized then ThrowUX.Reticle.TargetColor else Color3.new(1, 1, 1)
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 }, {
		Origin = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = if recognized then 0.18 else ThrowUX.Swipe.CandidateTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(gesture.origin.X, gesture.origin.Y),
			Size = UDim2.fromOffset(ThrowUX.Swipe.OriginPixels, ThrowUX.Swipe.OriginPixels),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = c("UIStroke", {
				Color = color,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.08,
				Transparency = 0.25,
			}),
		}),
		Trail = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = if recognized then 0.12 else 0.5,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(midpoint.X, midpoint.Y),
			Rotation = math.deg(math.atan2(delta.Y, delta.X)),
			Size = UDim2.fromOffset(length, ThrowUX.Swipe.TrailThicknessPixels),
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
	})
end

local function SwipeHint(props: { visible: boolean })
	local viewport = useViewportSize()
	local geometry = React.useMemo(function()
		return Combat.inputGeometry()
	end, { viewport })
	if not props.visible or not geometry.swipeEnabled or viewport.X <= 0 then
		return nil
	end
	local travel = geometry.swipeDistancePixels
	local size = math.clamp(math.min(viewport.X, viewport.Y) * 0.06, 34, 58)
	return c(GestureGlyph, {
		Kind = "Swipe",
		Label = ThrowUX.Onboarding.Text,
		TravelPixels = travel,
		SizePixels = size,
		Native = {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(viewport.X * 0.5, geometry.swipeRect.maxY - size - travel * 0.35),
			ZIndex = 35,
		},
	})
end

local function HammerButton(props: { visible: boolean, itemId: string?, cooldownProgress: number })
	local ref = React.useRef(nil)
	local pressing, setPressing = React.useState(false)
	local reducedMotion = useReducedMotion()
	local styles = ReactSpring.useSpring({
		Scale = if pressing then 0.9 else 1,
		IconColor = if props.cooldownProgress < 1 then Color3.fromRGB(202, 218, 220) else Color3.new(1, 1, 1),
		Progress = math.clamp(props.cooldownProgress, 0, 1),
		config = { mass = 1, tension = 700, friction = 30 },
		immediate = reducedMotion,
	})
	React.useEffect(function()
		local button = ref.current
		if button == nil or not props.visible then
			Combat.registerHudExclusion("HammerButton", nil)
			return
		end
		local function register()
			local position, size = button.AbsolutePosition, button.AbsoluteSize
			Combat.registerHudExclusion("HammerButton", {
				minX = position.X,
				minY = position.Y,
				maxX = position.X + size.X,
				maxY = position.Y + size.Y,
			})
		end
		register()
		local p = button:GetPropertyChangedSignal("AbsolutePosition"):Connect(register)
		local s = button:GetPropertyChangedSignal("AbsoluteSize"):Connect(register)
		return function()
			p:Disconnect()
			s:Disconnect()
			Combat.registerHudExclusion("HammerButton", nil)
		end
	end, { props.visible })
	return c("ImageButton", {
		ref = ref,
		Active = props.visible,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		Position = UDim2.fromScale(0.9, 0.58),
		Selectable = false,
		Size = UDim2.fromScale(0.09, 0.09),
		Visible = props.visible,
		ZIndex = 40,
		[React.Event.Activated] = Combat.hammerPressed,
		[React.Event.InputBegan] = function(_, input)
			if input.UserInputType == Enum.UserInputType.Touch then
				setPressing(true)
			end
		end,
		[React.Event.InputEnded] = function()
			setPressing(false)
		end,
	}, {
		Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Bounds = c("UISizeConstraint", { MaxSize = Vector2.new(104, 104), MinSize = Vector2.new(72, 72) }),
		Scale = c("UIScale", { Scale = styles.Scale }),
		Shadow = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(24, 41, 48),
			BackgroundTransparency = 0.34,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(0.94, 0.94),
			ZIndex = 39,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		Plate = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(242, 24, 76),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.94, 0.94),
			ZIndex = 40,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = c("UIStroke", {
				Color = Color3.new(1, 1, 1),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.045,
			}),
			Icon = c("CanvasGroup", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				GroupColor3 = styles.IconColor,
				Position = UDim2.fromScale(0.5, 0.46),
				Size = UDim2.fromScale(0.76, 0.76),
				ZIndex = 41,
			}, {
				Preview = c(WeaponViewport, { Weapon = "Hammer", ItemId = props.itemId, ZIndex = 41 }),
			}),
			ReadyDot = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 224, 78),
				BackgroundTransparency = if props.cooldownProgress >= 1 then 0 else 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.9),
				Size = UDim2.fromScale(0.16, 0.055),
				ZIndex = 43,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			Cooldown = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(24, 41, 48),
				BackgroundTransparency = if props.cooldownProgress < 1 then 0.1 else 1,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.5, 0.82),
				Size = UDim2.fromScale(0.56, 0.055),
				ZIndex = 44,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Fill = c("Frame", {
					BackgroundColor3 = Color3.fromRGB(255, 224, 78),
					BorderSizePixel = 0,
					Size = styles.Progress:map(function(value: number)
						return UDim2.fromScale(value, 1)
					end),
					ZIndex = 45,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
			}),
		}),
	})
end

return function()
	local snapshot = useExternalStore(ThrowUXClient.getSnapshot, ThrowUXClient.subscribe)
	local cosmetics = useEquippedWeaponCosmetics()
	local toolbarModel = CombatToolbarViewModel.fromSnapshot({
		active = snapshot.active,
		weapon = snapshot.weapon,
		holdsBall = snapshot.holdsBall,
		throwCooldown = snapshot.throwCooldown,
		hammerCooldown = snapshot.hammerCooldown,
		weaponLocked = snapshot.weaponLocked,
		throwState = snapshot.state,
		chargeAlpha = snapshot.chargeAlpha,
	}, snapshot.inputType)
	local hammerCooldownProgress = 1
		- math.clamp(snapshot.hammerCooldown / math.max(CombatConfig.Hammer.Cooldown, 1e-3), 0, 1)
	local debugText = string.format(
		"%s  charge %.2f  cooldown %.2f  target %.2f  %s %.2f",
		snapshot.state,
		snapshot.chargeAlpha,
		snapshot.cooldownAlpha,
		snapshot.targetConfidence,
		snapshot.gesture.kind,
		snapshot.gesture.progress
	)
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Trajectory = c(Trajectory),
		Reticle = c(Reticle, { snapshot = snapshot }),
		Swipe = c(SwipeFeedback, { snapshot = snapshot }),
		SwipeHint = c(SwipeHint, { visible = snapshot.onboardingVisible }),
		Toolbar = c(CombatToolbar, {
			Model = toolbarModel,
			BallItemId = cosmetics.ball,
			HammerItemId = cosmetics.hammer,
			OnEquip = Combat.requestWeaponEquip,
			RegisterExclusion = Combat.registerHudExclusion,
		}),
		Hammer = c(HammerButton, {
			visible = snapshot.active and snapshot.inputType == "Touch" and snapshot.weapon == "Hammer",
			itemId = cosmetics.hammer,
			cooldownProgress = hammerCooldownProgress,
		}),
		Debug = c(ResponsiveText, {
			MeasurementFont = Enum.Font.Code,
			Native = {
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = 0.35,
				FontFace = Font.fromEnum(Enum.Font.Code),
				Position = UDim2.fromScale(0.01, 0.1),
				Size = UDim2.fromScale(0.55, 0.05),
				Text = debugText,
				TextColor3 = Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = snapshot.debugEnabled,
				ZIndex = 100,
			},
		}),
	})
end
