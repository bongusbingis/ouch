---> module declaration
local GlowButton = {}
GlowButton.Prototype = {}

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

---> dependencies
local Knit = require(ReplicatedStorage:WaitForChild("Knit"))
local ViewModel = require(Knit.Util.Viewport)
local GoodSignal = require(Knit.Util.GoodSignal)
local Promise = require(Knit.Util.Promise)
local Janitor = require(Knit.Util.Janitor)
local Suffix = require(Knit.Util.Suffix)

---> globals
local Player = Players.LocalPlayer
local PlayerGui: PlayerGui = Player:WaitForChild("PlayerGui")
local UI = PlayerGui:WaitForChild("MainGUI")

local SharedStorage: Folder = ReplicatedStorage:WaitForChild("SharedStorage")
local UISharedStorage = SharedStorage:WaitForChild("UI")
local GlowButtonTemplate: Frame = UISharedStorage:WaitForChild("GlowButton")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = Shared:WaitForChild("UI"):WaitForChild("Components")
local Classes = Shared:WaitForChild("Classes")

---> constants
local DEFAULT_SCALE = 1
local CLICK_SCALE = 0.9

local GRADIENT_START_OFFSET = Vector2.new(-1, 0)
local GRADIENT_END_OFFSET = Vector2.new(1, 0)

local CLICK_TWEEN_INFO = TweenInfo.new(0.1)
local HOVER_TWEEN_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Circular)
local CHECK_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back)

local STYLE_MAP = {
	Blue = "rbxassetid://74840727733788",
	Red = "rbxassetid://104936340787344",
	Yellow = "rbxassetid://114710397812767",
}

---> types
type _self = {
	_base: Frame,
	_button: ImageButton,
	_ui_gradient: UIGradient,
	_ui_scale: UIScale,
	_janitor: Janitor.Janitor,
	_checkmark_on_click: boolean,
	Activated: RBXScriptSignal,
}

export type glowButton = typeof(setmetatable({} :: _self, { __index = GlowButton.Prototype }))

function GlowButton.Prototype.SetText(self: glowButton, text: string): glowButton
	self._button.TextLabel.Text = text
	return self
end

function GlowButton.Prototype.SetStyle(self: glowButton, styleName: string): glowButton
	assert(STYLE_MAP[styleName], "Invalid style name provided")
	self._button.Image = STYLE_MAP[styleName]
	return self
end

function GlowButton.Prototype.Mount(self: glowButton, parentFrame: Frame): glowButton
	self._base.HoverBounds.MouseEnter:Connect(function(x, y)
		self._ui_gradient.Offset = GRADIENT_START_OFFSET
		self._ui_gradient.Rotation = 0
		TweenService:Create(self._ui_gradient, HOVER_TWEEN_INFO, {
			Offset = GRADIENT_END_OFFSET,
			Rotation = 15,
		}):Play()
		TweenService:Create(self._button, TweenInfo.new(HOVER_TWEEN_INFO.Time + 0.05), {
			ImageColor3 = Color3.fromRGB(200, 200, 200),
		}):Play()
	end)
	self._base.HoverBounds.MouseLeave:Connect(function(x, y)
		-- TweenService:Create(self._ui_gradient, HOVER_TWEEN_INFO, {
		--     Offset = Vector2.new(0.75, 0),
		--     Rotation = 0,
		-- }):Play()
		TweenService:Create(self._button, HOVER_TWEEN_INFO, {
			ImageColor3 = Color3.fromRGB(255, 255, 255),
		}):Play()
	end)
	self._janitor:Add(self._button.MouseButton1Down:Connect(function(inputObject, clickCount)
		TweenService:Create(self._ui_scale, CLICK_TWEEN_INFO, { Scale = CLICK_SCALE }):Play()
	end))
	self._janitor:Add(self._button.MouseButton1Up:Connect(function(x, y)
		TweenService:Create(self._ui_scale, CLICK_TWEEN_INFO, { Scale = DEFAULT_SCALE }):Play()
	end))

	self._base.Parent = parentFrame
	self._base.Visible = true
	return self
end

function GlowButton.Prototype.BindToActivationWithCheckmark(self: glowButton, callbackFunction: () -> boolean?) -- spaghetti
	local baseSize = self._base.Size
	local indicatorImage: ImageLabel = self._button.Indicator
	local indicatorAbsSize: Vector2 = self._button.Indicator.AbsoluteSize
	self._button.TextLabel.Size =
		UDim2.new(0, self._button.TextLabel.TextBounds.X, self._button.TextLabel.Size.Y.Scale, 0)
	self._janitor:Add(self.Activated:Connect(function()
		if self._base.Size == baseSize then
			local callbackResult = callbackFunction()
			if callbackResult ~= true then
				return
			end
		else
			return
		end
		task.wait(0.2)
		self._button.Indicator.Size = UDim2.fromScale(0, 0)
		self._button.Indicator.Visible = true
		TweenService:Create(
			self._base,
			CHECK_TWEEN_INFO,
			{ Size = UDim2.new(baseSize.X.Scale + 0.01, indicatorAbsSize.X, baseSize.Y.Scale, 0) }
		):Play()
		--task.delay(CHECK_TWEEN_INFO.Time / 2, function()
			TweenService:Create(self._button.Indicator, CHECK_TWEEN_INFO, { Size = UDim2.fromScale(0.45, 0.45) }):Play()
		--end)

		task.wait(0.5)
		TweenService:Create(self._base, CHECK_TWEEN_INFO, { Size = baseSize }):Play()
		local revertTween =
			TweenService:Create(self._button.Indicator, CLICK_TWEEN_INFO, { Size = UDim2.fromScale(0, 0) })
		revertTween:Play()
		revertTween.Completed:Wait()
		self._button.Indicator.Visible = false
	end))
end

function GlowButton.Prototype.SetSize(self: glowButton, size: UDim2): glowButton
	self._base.Size = size
	return self
end

function GlowButton.Prototype.SetEnabled(self: glowButton, isEnabled: boolean): glowButton
	self._base.Visible = isEnabled
end

function GlowButton.Prototype.Destroy(self: glowButton)
	self._janitor:Cleanup()
	self._base:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end

function GlowButton.New(checkmarkOnClick: boolean)
	local newGlowButton: Frame = GlowButtonTemplate:Clone()
	local componentButton: ImageButton = newGlowButton.Button
	local uiGradient: UIGradient = componentButton.UIGradient
	local uiScale: UIScale = componentButton.UIScale

	return setmetatable(
		{
			_base = newGlowButton,
			_button = componentButton,
			_ui_gradient = uiGradient,
			_ui_scale = uiScale,
			_janitor = Janitor.new(),
			_checkmark_on_click = checkmarkOnClick or false,
			Activated = componentButton.Activated,
		} :: _self,
		{ __index = GlowButton.Prototype }
	)
end

return GlowButton
