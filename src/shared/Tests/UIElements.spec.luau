--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local ElementHandle = require(Client.Modules.UI.Elements.ElementHandle)
local ButtonElement = require(Client.Modules.UI.Elements.ButtonElement)
local TextSizer = require(Client.Modules.UI.TextSizer)

type FakeSignal = {
	Connect: (self: FakeSignal, callback: () -> ()) -> any,
	Fire: (self: FakeSignal) -> (),
}

local buttonConfig = {
	DefaultColor = { r = 0.2, g = 0.3, b = 0.4 },
	SelectedColor = { r = 0.5, g = 0.6, b = 0.7 },
	HoverBrightness = 1.1,
	PressedBrightness = 0.9,
	DefaultScale = 1,
	HoverScale = 1.04,
	PressedScale = 0.94,
	SelectedScale = 1.02,
	Text = {
		MinSize = 12,
		MaxSize = 24,
		Padding = { x = 4, y = 2 },
	},
}

local buttonTweens = {
	Hover = { Time = 0.1 },
	Press = { Time = 0.06 },
	Release = { Time = 0.12 },
	Select = { Time = 0.14 },
}

local function signal(): FakeSignal
	local connections = {}
	local signalObject = {} :: any

	function signalObject:Connect(callback)
		local connection = {
			connected = true,
			callback = callback,
		}
		function connection:Disconnect()
			self.connected = false
		end
		table.insert(connections, connection)
		return connection
	end

	function signalObject:Fire()
		for _, connection in connections do
			if connection.connected then
				connection.callback()
			end
		end
	end

	return signalObject :: FakeSignal
end

local function fakeGui(name: string, className: string): any
	local gui = {
		Name = name,
		ClassName = className,
		Parent = nil,
		Visible = true,
		LayoutOrder = 0,
		ImageColor3 = nil,
		Text = "",
		Active = true,
		AutoButtonColor = true,
		destroyed = false,
		_children = {},
	}

	function gui:IsA(targetClass: string): boolean
		return self.ClassName == targetClass
			or (targetClass == "GuiObject" and (self.ClassName == "Frame" or self.ClassName == "ImageButton"))
	end

	function gui:WaitForChild(childName: string)
		local child = self._children[childName]
		if child == nil then
			error(`missing child {childName}`)
		end
		return child
	end

	function gui:Clone()
		local clone = fakeGui(self.Name, self.ClassName)
		for childName, child in self._children do
			clone._children[childName] = child:Clone()
		end
		if self.ClassName == "ImageButton" then
			clone.MouseEnter = signal()
			clone.MouseLeave = signal()
			clone.MouseButton1Down = signal()
			clone.MouseButton1Up = signal()
			clone.MouseButton1Click = signal()
			clone.Activated = signal()
		end
		return clone
	end

	function gui:Destroy()
		self.destroyed = true
	end

	return gui
end

local function buttonTemplate(): any
	local button = fakeGui("ButtonTemplate", "ImageButton")
	button._children.Label = fakeGui("Label", "TextLabel")
	button.MouseEnter = signal()
	button.MouseLeave = signal()
	button.MouseButton1Down = signal()
	button.MouseButton1Up = signal()
	button.MouseButton1Click = signal()
	button.Activated = signal()
	return button
end

T.describe("UI element handles", function()
	T.it("destroys callbacks and instances once", function()
		local destroyed = 0
		local instance = fakeGui("Mounted", "Frame")
		local handle = ElementHandle.new(instance)

		handle:add(function()
			destroyed += 1
		end)
		handle:add({
			Destroy = function()
				destroyed += 1
			end,
		})

		handle:destroy()
		handle:destroy()

		T.expect(destroyed):toEqual(2)
		T.expect(instance.destroyed):toEqual(true)
		T.expect(handle:isDestroyed()):toEqual(true)
	end)
end)

T.describe("ButtonElement", function()
	T.it("mounts a configured button and cleans up events", function()
		local parent = fakeGui("Side", "Frame")
		local template = buttonTemplate()
		local activated = 0
		local scaleDestroyed = false
		local tweenCancels = 0
		local lastTweenGoal = nil :: any
		local textBound = false

		local handle = ButtonElement.mount(parent, {
			text = "Shop",
			name = "ShopButton",
			color = { r = 0.1, g = 0.2, b = 0.3 },
			layoutOrder = 10,
			activated = function()
				activated += 1
			end,
		}, {
			template = template,
			config = buttonConfig,
			tweens = buttonTweens,
			createScale = function(_button)
				return {
					Scale = 0,
					Destroy = function()
						scaleDestroyed = true
					end,
				}
			end,
			tweenFactory = function(_target, _spec, goals)
				lastTweenGoal = goals
				return {
					Play = function() end,
					Cancel = function()
						tweenCancels += 1
					end,
				}
			end,
			textSizer = {
				bind = function(label, boundsGui, options)
					textBound = label.Name == "Label"
						and boundsGui == label
						and options.maxSize == buttonConfig.Text.MaxSize
					return function() end
				end,
			},
		})

		local button = handle.instance :: any
		local label = button:WaitForChild("Label")

		T.expect(button.Parent):toEqual(parent)
		T.expect(button.Name):toEqual("ShopButton")
		T.expect(button.LayoutOrder):toEqual(10)
		T.expect(label.Text):toEqual("Shop")
		T.expect(button.ImageColor3.r):toBeNear(0.1)
		T.expect(textBound):toEqual(true)

		button.MouseButton1Click:Fire()
		T.expect(activated):toEqual(1)

		button.MouseEnter:Fire()
		T.expect(lastTweenGoal.Scale):toBeNear(buttonConfig.HoverScale)

		handle:setSelected(true)
		T.expect(lastTweenGoal.Scale):toBeNear(buttonConfig.SelectedScale)

		handle:destroy()
		button.MouseButton1Click:Fire()

		T.expect(activated):toEqual(1)
		T.expect(button.destroyed):toEqual(true)
		T.expect(scaleDestroyed):toEqual(true)
		T.expect(tweenCancels > 0):toEqual(true)
	end)
end)

T.describe("TextSizer", function()
	T.it("returns the largest text size that fits the provided bounds", function()
		local textService = {
			GetTextSize = function(_self, text: string, size: number, _font, _bounds)
				return {
					x = #text * size * 0.5,
					y = size,
				}
			end,
		}

		local size = TextSizer.textSizeForBounds("Play", { x = 50, y = 20 }, {
			textService = textService,
			font = "ComicNeueAngularBold",
			minSize = 8,
			maxSize = 30,
			padding = { x = 4, y = 2 },
		})

		T.expect(size):toEqual(16)
	end)
end)

return true
