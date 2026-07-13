---> module declaration
local SlotGradient = {}
SlotGradient.Prototype = {}

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

---> dependencies
local Knit = require(ReplicatedStorage:WaitForChild("Knit"))
local GoodSignal = require(Knit.Util.GoodSignal)
local Promise = require(Knit.Util.Promise)
local Janitor = require(Knit.Util.Janitor)
local Suffix = require(Knit.Util.Suffix)

export type customGradientData = {
	DefaultProperties: {
		[string]: any,
	},
	Speed: number,
	Color: Color3,
}

type _self = {
	_ui_gradient: UIGradient,
	_gradient_type: string,
	_gradient_info: customGradientData,
	_is_active: boolean,
	_janitor: Janitor.Janitor,
}

export type slotGradient = typeof(setmetatable({} :: _self, { __index = SlotGradient.Prototype }))

---> globals
local GradientTweenConstructorMap = {
	Shiny = function(self: slotGradient)
		return function(alpha: number)
			return TweenService:GetValue(alpha, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
			-- self._ui_gradient.Color = self._gradient_info.Color
			-- self._ui_gradient.Offset = Vector2.new(-1, 0)
			-- self._ui_gradient.Rotation = -45
			-- return self._janitor:Add(
			-- 	TweenService:Create(
			-- 		self._ui_gradient,
			-- 		TweenInfo.new(self._gradient_info.Speed * 2, Enum.EasingStyle.Linear),
			-- 		{
			-- 			Offset = Vector2.new(2, 0),
			-- 			Rotation = -45,
			-- 		}
			-- 	),
			-- 	"Destroy"
			-- )
		end
	end,
	Rainbow = function(self: slotGradient)
		return function()
			self._ui_gradient.Color = SlotGradient:_getRainbowColorSequence()
			self._ui_gradient.Offset = Vector2.new(0, 0)
			self._ui_gradient.Rotation = -180
			return self._janitor:Add(
				TweenService:Create(
					self._ui_gradient,
					TweenInfo.new(self._gradient_info.Speed * 2, Enum.EasingStyle.Linear),
					{ Offset = Vector2.new(0, 0), Rotation = 180 }
				),
				"Destroy"
			)
		end
	end,
}

---> private functions
function SlotGradient:_applyDefaultPropertiesToInstances(instancesArray: Instance, propertiesMap: { [string]: any }): ()
	for _, instance: Instance in instancesArray do
		for propertyName: string, propertyValue: any in propertiesMap do
			if instancesArray[propertyName] then
				instancesArray[propertyName] = propertyValue
			else
				warn("[SlotGradient Builder]:", propertyName, "is not a valid property of", instance)
			end
		end
	end
end

function SlotGradient:_getRainbowColorSequence()
	local colorsArray = {}
	local maxColors = 15
	local saturation = 255
	local value = 255

	for i = 1, maxColors do
		local hue = i * 17
		if i == 1 then
			table.insert(
				colorsArray,
				ColorSequenceKeypoint.new(0, Color3.fromHSV(hue / 255, saturation / 255, value / 255))
			)
		else
			table.insert(
				colorsArray,
				ColorSequenceKeypoint.new(i / maxColors, Color3.fromHSV(hue / 255, saturation / 255, value / 255))
			)
		end
	end

	table.sort(colorsArray, function(Min, Max)
		return Min.Time < Max.Time
	end)
	return ColorSequence.new(colorsArray)
end

---> methods
function SlotGradient.Prototype.CreateTweenLoop(self: slotGradient)
	local tweenLoopFunction: () -> Tween = GradientTweenConstructorMap[self._gradient_type](self)
	task.defer(function()
		local function recurseTweenLoop()
			local tweenForThisIteration = tweenLoopFunction()
			tweenForThisIteration:Play()
			tweenForThisIteration.Completed:Once(function()
				if self._is_active then
					recurseTweenLoop()
				end
			end)
		end
		recurseTweenLoop()
	end)
end

function SlotGradient.Prototype.Destroy(self: slotGradient)
	self._is_active = false
	table.clear(self)
	setmetatable(self, nil)
end

---> constructors
function SlotGradient.New(
	uiGradientBaseArray: UIGradient,
	gradientType: string,
	gradientInfo: customGradientData
): slotGradient
	if typeof(uiGradientBaseArray) == "Instance" then
		uiGradientBaseArray = { uiGradientBaseArray }
	end

	if gradientInfo.DefaultProperties then
		SlotGradient:_applyDefaultPropertiesToInstances(uiGradientBaseArray, gradientInfo.DefaultProperties)
	end
	return setmetatable(
		{
			_ui_gradients = uiGradientBaseArray,
			_gradient_type = gradientType,
			_gradient_info = gradientInfo,
			_is_active = true,
			_janitor = Janitor.new(),
		} :: _self,
		{ __index = SlotGradient.Prototype }
	)
end

return SlotGradient
