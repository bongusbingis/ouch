--!strict

local ElementFactory = require(script.Parent.ElementFactory)
local ElementTypes = require(script.Parent.ElementTypes)
local TextSizer = require(script.Parent.Parent.TextSizer)

type ButtonProps = ElementTypes.ButtonProps
type ButtonHandle = ElementTypes.ButtonHandle
type ColorValue = ElementTypes.ColorValue
type TweenSpec = ElementTypes.TweenSpec

type ButtonConfig = {
	DefaultColor: ColorValue,
	SelectedColor: ColorValue,
	HoverBrightness: number,
	PressedBrightness: number,
	DefaultScale: number,
	HoverScale: number,
	PressedScale: number,
	SelectedScale: number,
	Text: {
		MinSize: number,
		MaxSize: number,
		Padding: { x: number, y: number }?,
	},
}

type ButtonTweens = {
	Hover: TweenSpec,
	Press: TweenSpec,
	Release: TweenSpec,
	Select: TweenSpec,
}

type MountOptions = {
	template: ImageButton?,
	config: ButtonConfig?,
	tweens: ButtonTweens?,
	textSizer: any?,
	tweenFactory: ((target: any, spec: TweenSpec, goals: { [string]: any }) -> any)?,
	createScale: ((button: ImageButton) -> any)?,
}

local ButtonElement = {}

local function resolveTemplate(): ImageButton
	return ElementFactory.resolveTemplate("ButtonTemplate", "ImageButton") :: ImageButton
end

local function resolveConfig(): (ButtonConfig, ButtonTweens)
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local uiConfig = require(replicatedStorage:WaitForChild("Config"):WaitForChild("UI"))
	return uiConfig.Elements.Button, uiConfig.Tweens.Button
end

local function resolveLabel(button: ImageButton): TextLabel
	local label = button:WaitForChild("Label")
	assert(label:IsA("TextLabel"), "[ButtonElement] ButtonTemplate.Label must be a TextLabel")
	return label
end

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function brighten(color: ColorValue, multiplier: number): ColorValue
	return {
		r = clamp01(color.r * multiplier),
		g = clamp01(color.g * multiplier),
		b = clamp01(color.b * multiplier),
	}
end

local function toRobloxColor(color: ColorValue): any
	if Color3 ~= nil then
		return Color3.new(color.r, color.g, color.b)
	end
	return color
end

local function createTween(target: any, spec: TweenSpec, goals: { [string]: any }, tweenFactory)
	if tweenFactory then
		return tweenFactory(target, spec, goals)
	end

	local tweenService = game:GetService("TweenService")
	local info = TweenInfo.new(spec.Time, spec.EasingStyle, spec.EasingDirection)
	return tweenService:Create(target, info, goals)
end

local function playTween(
	activeTween: { current: any? },
	target: any,
	spec: TweenSpec,
	goals: { [string]: any },
	tweenFactory
)
	if activeTween.current and type(activeTween.current.Cancel) == "function" then
		activeTween.current:Cancel()
	end

	local tween = createTween(target, spec, goals, tweenFactory)
	activeTween.current = tween
	if tween and type(tween.Play) == "function" then
		tween:Play()
	end
	return tween
end

local function createScale(button: ImageButton, options: MountOptions?): any
	if options and options.createScale then
		return options.createScale(button)
	end

	local scale = Instance.new("UIScale")
	scale.Name = "InteractionScale"
	scale.Parent = button
	return scale
end

local function connect(handle, signal: any, callback: () -> ())
	if signal and type(signal.Connect) == "function" then
		handle:add(signal:Connect(callback))
	end
end

function ButtonElement.mount(parent: Instance, props: ButtonProps, options: MountOptions?): ButtonHandle
	local config: ButtonConfig
	local tweens: ButtonTweens
	if options and options.config and options.tweens then
		config = options.config
		tweens = options.tweens
	else
		config, tweens = resolveConfig()
	end

	local template = if options and options.template then options.template else resolveTemplate()
	local button, handle = ElementFactory.cloneMount(template, parent)
	assert(button:IsA("ImageButton"), "[ButtonElement] mounted template must be an ImageButton")

	local imageButton = button :: ImageButton
	local label = resolveLabel(imageButton)
	local scale = createScale(imageButton, options)
	local activeTween = { current = nil :: any? }
	local enabled = true
	local hovering = false
	local pressing = false
	local selected = props.selected == true
	local baseColor = props.color or config.DefaultColor
	local selectedColor = props.selectedColor or config.SelectedColor

	imageButton.Name = props.name or props.text
	imageButton.Visible = true
	imageButton.ImageColor3 = toRobloxColor(if selected then selectedColor else baseColor)
	imageButton.LayoutOrder = props.layoutOrder or 0
	label.Visible = true
	label.Text = props.text
	scale.Scale = if selected then config.SelectedScale else config.DefaultScale
	handle:add((if options and options.textSizer then options.textSizer else TextSizer).bind(label, label, {
		minSize = config.Text.MinSize,
		maxSize = config.Text.MaxSize,
		padding = config.Text.Padding,
	}))

	local function targetColor(): ColorValue
		local color = if selected then selectedColor else baseColor
		if pressing then
			return brighten(color, config.PressedBrightness)
		end
		if hovering then
			return brighten(color, config.HoverBrightness)
		end
		return color
	end

	local function targetScale(): number
		if pressing then
			return config.PressedScale
		end
		if selected then
			return config.SelectedScale
		end
		if hovering then
			return config.HoverScale
		end
		return config.DefaultScale
	end

	local function animate(spec: TweenSpec)
		playTween(activeTween, scale, spec, { Scale = targetScale() }, if options then options.tweenFactory else nil)
		imageButton.ImageColor3 = toRobloxColor(targetColor())
	end

	connect(handle, imageButton.MouseEnter, function()
		hovering = true
		if enabled then
			animate(tweens.Hover)
		end
	end)
	connect(handle, imageButton.MouseLeave, function()
		hovering = false
		pressing = false
		if enabled then
			animate(tweens.Release)
		end
	end)
	connect(handle, imageButton.MouseButton1Down, function()
		pressing = true
		if enabled then
			animate(tweens.Press)
		end
	end)
	connect(handle, imageButton.MouseButton1Up, function()
		pressing = false
		if enabled then
			animate(tweens.Release)
		end
	end)

	local function activate()
		if enabled and props.activated then
			props.activated()
		end
	end

	connect(handle, imageButton.MouseButton1Click, activate)

	handle:add(scale)
	handle:add(function()
		if activeTween.current and type(activeTween.current.Cancel) == "function" then
			activeTween.current:Cancel()
			activeTween.current = nil
		end
	end)

	local buttonHandle = handle :: any
	buttonHandle.instance = imageButton

	function buttonHandle:setSelected(nextSelected: boolean)
		if selected == nextSelected then
			return
		end
		selected = nextSelected
		animate(tweens.Select)
	end

	function buttonHandle:setEnabled(nextEnabled: boolean)
		enabled = nextEnabled
		imageButton.Active = enabled
		imageButton.AutoButtonColor = false
		if not enabled then
			hovering = false
			pressing = false
		end
		animate(tweens.Release)
	end

	imageButton.AutoButtonColor = false

	return buttonHandle :: ButtonHandle
end

return ButtonElement
