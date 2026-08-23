--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Config = ReplicatedStorage:WaitForChild("Config")
local CombatConfig = require(Config:WaitForChild("Combat"))
local ThrowUX = require(Config:WaitForChild("ThrowUX"))
local SharedUI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local ResponsiveText = require(SharedUI:WaitForChild("Components"):WaitForChild("ResponsiveText"))
local useExternalStore = require(SharedUI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local useReducedMotion = require(SharedUI:WaitForChild("Hooks"):WaitForChild("useReducedMotion"))
local ChargeAim = require(script.Parent.Parent.Modules.Presentation.ChargeAim)
local ThrowUXClient = require(script.Parent.Parent.Modules.UI.ThrowUXClient)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local c = React.createElement

local function Reticle(props: { snapshot: ThrowUXClient.Snapshot })
	local state = props.snapshot.state
	local target = props.snapshot.targetConfidence > 0
	local full = state == "FullCharge"
	local charging = state == "Charging" or full
	local recovery = state == "Recovery" or state == "Idle"
	local reducedMotion = useReducedMotion()
	local pulse, setPulse = React.useState(false)
	local pulseRevision = React.useRef(0)

	React.useEffect(function()
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
	local styles = ReactSpring.useSpring({
		Scale = scale,
		Rotation = rotation,
		Ring = if charging then math.max(props.snapshot.chargeAlpha, ThrowUX.Reticle.RingMinimumAlpha) else 0,
		config = { mass = 1, tension = 520, friction = 30 },
		immediate = reducedMotion,
	})
	local color = if full
		then ThrowUX.Reticle.FullChargeColor
		else if target then ThrowUX.Reticle.TargetColor else ThrowUX.Reticle.NeutralColor
	local baseTransparency = if recovery
		then ThrowUX.Reticle.UnavailableTransparency
		else ThrowUX.Reticle.ReadyTransparency
	local ringSize = styles.Ring:map(function(alpha: number)
		local resolved = ThrowUX.Reticle.RingStartScale
			+ (ThrowUX.Reticle.RingFullScale - ThrowUX.Reticle.RingStartScale) * alpha
		return UDim2.fromScale(resolved, resolved)
	end)
	local ringThickness = styles.Ring:map(function(alpha: number)
		return ThrowUX.Reticle.RingStartThickness
			+ (ThrowUX.Reticle.RingFullThickness - ThrowUX.Reticle.RingStartThickness) * alpha
	end)
	local ringTransparency = styles.Ring:map(function(alpha: number)
		if alpha <= 0.005 then
			return 1
		end
		return ThrowUX.Reticle.RingStartTransparency
			+ (ThrowUX.Reticle.RingFullTransparency - ThrowUX.Reticle.RingStartTransparency) * alpha
	end)
	local ringColor = styles.Ring:map(function(alpha: number)
		return ThrowUX.Reticle.NeutralColor:Lerp(ThrowUX.Reticle.FullChargeColor, alpha)
	end)
	local glowAlpha = styles.Ring:map(function(alpha: number)
		return math.clamp((alpha - 0.82) / 0.18, 0, 1)
	end)
	local glowSize = glowAlpha:map(function(alpha: number)
		local resolved = 1.2 - alpha * 0.12
		return UDim2.fromScale(resolved, resolved)
	end)
	local glowTransparency = glowAlpha:map(function(alpha: number)
		return 1 - alpha * 0.42
	end)

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
		ChargeRing = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = ringSize,
		}, {
			Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = c("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = ringColor,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = ringThickness,
				Transparency = ringTransparency,
			}),
		}),
		FullChargeGlow = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = glowSize,
		}, {
			Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = c("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = ThrowUX.Reticle.FullChargeColor,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = ThrowUX.Reticle.RingFullThickness * 0.55,
				Transparency = glowTransparency,
			}),
		}),
		Dot = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = baseTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.16, 0.16),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		Left = c("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = baseTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.34, 0.5),
			Size = UDim2.fromScale(0.18, 0.08),
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		Right = c("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = baseTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.66, 0.5),
			Size = UDim2.fromScale(0.18, 0.08),
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		Top = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = color,
			BackgroundTransparency = baseTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.34),
			Size = UDim2.fromScale(0.08, 0.18),
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		Bottom = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = color,
			BackgroundTransparency = baseTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.66),
			Size = UDim2.fromScale(0.08, 0.18),
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

local function HammerButton(props: { visible: boolean })
	local ref = React.useRef(nil)
	local pressing, setPressing = React.useState(false)
	local reducedMotion = useReducedMotion()
	local styles = ReactSpring.useSpring({
		Scale = if pressing then 0.88 else 1,
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
		BackgroundColor3 = Color3.fromRGB(242, 24, 76),
		BorderSizePixel = 0,
		Image = "",
		Position = UDim2.fromScale(0.9, 0.58),
		Selectable = props.visible,
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
		Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Scale = c("UIScale", { Scale = styles.Scale }),
		Stroke = c("UIStroke", {
			Color = Color3.new(1, 1, 1),
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.055,
		}),
		Label = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			Native = {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Size = UDim2.fromScale(1, 1),
				Text = "BONK",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 41,
			},
		}),
	})
end

return function()
	local snapshot = useExternalStore(ThrowUXClient.getSnapshot, ThrowUXClient.subscribe)
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
		Onboarding = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.5, 0.76),
				Size = UDim2.fromScale(0.34, 0.07),
				Text = ThrowUX.Onboarding.Text .. "  ↑",
				TextColor3 = Color3.new(1, 1, 1),
				TextTransparency = 0.12,
				Visible = snapshot.onboardingVisible,
				ZIndex = 35,
			},
		}, {
			Stroke = c("UIStroke", {
				Color = Color3.fromRGB(77, 77, 77),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.035,
				Transparency = 0.2,
			}),
		}),
		Hammer = c(HammerButton, { visible = snapshot.active and snapshot.inputType == "Touch" }),
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
