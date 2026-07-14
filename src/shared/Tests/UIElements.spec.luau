--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local ElementHandle = require(Client.Modules.UI.Elements.ElementHandle)
local ButtonElement = require(Client.Modules.UI.Elements.ButtonElement)
local QuestCardElement = require(Client.Modules.UI.Elements.QuestCardElement)
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
		LayoutOrder = 0,
		AnchorPoint = { X = 0, Y = 0 },
		Position = { X = { Scale = 0, Offset = 0 }, Y = { Scale = 0, Offset = 0 } },
		Size = { X = { Scale = 0, Offset = 0 }, Y = { Scale = 0, Offset = 0 } },
		Rotation = 0,
		Color = nil,
		FillRatio = nil,
		destroyed = false,
		_children = {},
		_order = {},
	}

	function gui:IsA(targetClass: string): boolean
		return self.ClassName == targetClass
			or (
				targetClass == "GuiObject"
				and (self.ClassName == "Frame" or self.ClassName == "ImageButton" or self.ClassName == "ScrollingFrame")
			)
	end

	function gui:WaitForChild(childName: string)
		local child = self._children[childName]
		if child == nil then
			error(`missing child {childName}`)
		end
		return child
	end

	function gui:GetChildren()
		return self._order
	end

	function gui:Clone()
		local clone = fakeGui(self.Name, self.ClassName)
		for childName, child in self._children do
			local childClone = child:Clone()
			clone._children[childName] = childClone
			table.insert(clone._order, childClone)
		end
		clone.Position = self.Position
		clone.Size = self.Size
		clone.AnchorPoint = self.AnchorPoint
		clone.Rotation = self.Rotation
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

local function addChild(parent: any, child: any): any
	parent._children[child.Name] = child
	table.insert(parent._order, child)
	return child
end

local function buttonTemplate(): any
	local button = fakeGui("ButtonTemplate", "ImageButton")
	addChild(button, fakeGui("Label", "TextLabel"))
	button.MouseEnter = signal()
	button.MouseLeave = signal()
	button.MouseButton1Down = signal()
	button.MouseButton1Up = signal()
	button.MouseButton1Click = signal()
	button.Activated = signal()
	return button
end

local function questCardTemplate(): any
	local card = fakeGui("QuestCard", "Frame")
	addChild(card, fakeGui("Title", "TextLabel"))
	addChild(card, fakeGui("Count", "TextLabel"))
	addChild(card, fakeGui("Rewards", "TextLabel"))
	local progress = addChild(card, fakeGui("Progress", "Frame"))
	addChild(progress, fakeGui("UIGradient", "UIGradient"))
	for index = 1, 4 do
		local divider = addChild(progress, fakeGui(`Frame{index}`, "Frame"))
		divider.Rotation = 15
		divider.Position = { X = { Scale = index / 5, Offset = 0 }, Y = { Scale = 0.5, Offset = 0 } }
	end
	return card
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
		T.expect(button.Visible):toEqual(true)
		T.expect(button.Name):toEqual("ShopButton")
		T.expect(button.LayoutOrder):toEqual(10)
		T.expect(label.Visible):toEqual(true)
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

T.describe("QuestCardElement", function()
	T.it("mounts quest data, progress dividers, and claim button", function()
		local parent = fakeGui("Holder", "ScrollingFrame")
		local claimed = nil :: string?
		local mountedButtons = 0
		local lastButton = nil :: any

		local handle = QuestCardElement.mount(parent, {
			data = {
				slot = 1,
				questId = "elims_5",
				title = "Get 5 eliminations",
				progress = 2,
				goal = 5,
				steps = 5,
				claimed = false,
				completed = false,
				reward = { kind = "Cash", amount = 150 },
			},
			claim = function(questId)
				claimed = questId
			end,
		}, {
			template = questCardTemplate(),
			config = {
				Progress = {
					FillColor = { r = 0, g = 1, b = 0 },
					EmptyColor = { r = 0, g = 0, b = 0 },
				},
				Button = {
					EnabledColor = { r = 0.38, g = 0.72, b = 0.2 },
					DisabledColor = { r = 0.48, g = 0.48, b = 0.48 },
					ClaimedColor = { r = 0.35, g = 0.35, b = 0.35 },
					Position = { x = 0.814, y = 0.835 },
					Size = { x = 0.28, y = 0.3 },
				},
			},
			buttonElement = {
				mount = function(parentInstance, props)
					mountedButtons += 1
					local button = buttonTemplate()
					button.Name = props.name
					button.Parent = parentInstance
					button._children.Label.Text = props.text
					lastButton = button
					local buttonHandle = {
						instance = button,
						enabled = true,
						destroyed = false,
					}
					function buttonHandle:setSelected(_selected: boolean) end
					function buttonHandle:setEnabled(enabled: boolean)
						self.enabled = enabled
						button.enabled = enabled
					end
					function buttonHandle:add(cleanup)
						return cleanup
					end
					function buttonHandle:destroy()
						self.destroyed = true
					end
					function buttonHandle:isDestroyed()
						return self.destroyed
					end
					return buttonHandle
				end,
			},
		})

		local card = handle.instance :: any
		local progress = card:WaitForChild("Progress")
		local gradient = progress:WaitForChild("UIGradient")

		T.expect(card:WaitForChild("Title").Text):toEqual("1. Get 5 eliminations")
		T.expect(card:WaitForChild("Count").Text):toEqual("2/5")
		T.expect(card:WaitForChild("Rewards").Text):toEqual("150 coins")
		T.expect(gradient.Rotation):toEqual(15)
		T.expect(gradient.FillRatio):toBeNear(0.4)
		T.expect(gradient.GradientStop):toBeNear(0.421132)
		T.expect(#progress:GetChildren()):toEqual(5)
		T.expect(mountedButtons):toEqual(1)
		T.expect(lastButton._children.Label.Text):toEqual("Claim")
		T.expect(lastButton.enabled):toEqual(false)
		T.expect(lastButton.AnchorPoint.X):toEqual(1)
		T.expect(lastButton.AnchorPoint.Y):toEqual(1)
		T.expect(lastButton.Position.X.Scale):toBeNear(0.814)
		T.expect(lastButton.Position.Y.Scale):toBeNear(0.835)
		T.expect(lastButton.Size.X.Scale):toBeNear(0.28)
		T.expect(lastButton.Size.Y.Scale):toBeNear(0.3)
		T.expect(progress:WaitForChild("Frame1").AnchorPoint.Y):toBeNear(0.5)
		T.expect(progress:WaitForChild("Frame1").Position.Y.Scale):toBeNear(0.5)
		T.expect(claimed):toBeNil()

		handle:setData({
			slot = 1,
			questId = "throws_10",
			title = "Throw 10 dodgeballs",
			progress = 1,
			goal = 10,
			steps = 5,
			claimed = false,
			completed = false,
			reward = { kind = "Cash", amount = 125 },
		})

		T.expect(card:WaitForChild("Count").Text):toEqual("1/10")
		T.expect(gradient.FillRatio):toBeNear(0.2)
		T.expect(gradient.GradientStop):toBeNear(0.263397)

		handle:setData({
			slot = 1,
			questId = "elims_5",
			title = "Get 5 eliminations",
			progress = 5,
			goal = 5,
			steps = 5,
			claimed = false,
			completed = true,
			reward = { kind = "Cash", amount = 150 },
		})

		T.expect(mountedButtons):toEqual(3)
		T.expect(lastButton._children.Label.Text):toEqual("Claim")
		T.expect(lastButton.enabled):toEqual(true)
		handle:destroy()
		T.expect(card.destroyed):toEqual(true)
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
