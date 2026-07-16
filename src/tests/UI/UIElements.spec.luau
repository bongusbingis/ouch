--!nonstrict
-- Cloud port of the UIElements spec. ElementHandle, ButtonElement, and
-- QuestCardElement run against the real Studio-authored templates in
-- ReplicatedStorage.Assets.UI.Templates with real config, tweens, scales, and
-- gradients. Pointer interactions stay on scripted signal doubles — real
-- GuiButton events cannot be fired without a client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local UI = Client:WaitForChild("Modules"):WaitForChild("UI")
local ElementHandle = require(UI:WaitForChild("Elements"):WaitForChild("ElementHandle"))
local ButtonElement = require(UI:WaitForChild("Elements"):WaitForChild("ButtonElement"))
local QuestCardElement = require(UI:WaitForChild("Elements"):WaitForChild("QuestCardElement"))
local TextSizer = require(UI:WaitForChild("TextSizer"))
local QuestsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Quests"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"))
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

local function signal()
	local connections = {}
	local signalObject = {}

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

	return signalObject
end

local function fakeButtonElement(mounted)
	return {
		mount = function(parentInstance, props)
			local button = {
				Name = props.name,
				Parent = parentInstance,
				Text = props.text,
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(),
				Size = UDim2.new(),
				enabled = true,
			}
			local buttonHandle = {
				instance = button,
				props = props,
				destroyed = false,
			}
			function buttonHandle:setSelected(_selected: boolean) end
			function buttonHandle:setEnabled(enabled: boolean)
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
			table.insert(mounted, buttonHandle)
			return buttonHandle
		end,
	}
end

local function questData(overrides)
	local data = {
		slot = 1,
		questId = "elims_5",
		title = "Get 5 eliminations",
		progress = 2,
		goal = 5,
		steps = 5,
		claimed = false,
		completed = false,
		reward = { kind = "Cash", amount = 150 },
	}
	for key, value in overrides or {} do
		data[key] = value
	end
	return data
end

return function()
	local created = {}

	local function track(instance)
		table.insert(created, instance)
		return instance
	end

	afterEach(function()
		for _, instance in created do
			instance:Destroy()
		end
		table.clear(created)
	end)

	describe("UI element handles", function()
		it("destroys callbacks, connections, and instances once", function()
			local destroyed = 0
			local instance = Instance.new("Frame")
			local watched = track(Instance.new("TextLabel"))
			local connection = watched:GetPropertyChangedSignal("Text"):Connect(function() end)
			local handle = ElementHandle.new(instance)

			handle:add(function()
				destroyed += 1
			end)
			handle:add({
				Destroy = function()
					destroyed += 1
				end,
			})
			handle:add(connection)

			expect(connection.Connected).to.equal(true)

			handle:destroy()
			handle:destroy()

			expect(destroyed).to.equal(2)
			expect(connection.Connected).to.equal(false)
			expect(instance.Parent).never.to.be.ok()
			expect(handle:isDestroyed()).to.equal(true)
		end)

		it("runs cleanups added after destruction immediately", function()
			local handle = ElementHandle.new(nil)
			handle:destroy()

			local ran = false
			handle:add(function()
				ran = true
			end)
			expect(ran).to.equal(true)
		end)
	end)

	describe("ButtonElement", function()
		it("mounts the real template with real config, scale, and cleanup", function()
			local template = TestAssets.get(ReplicatedStorage, "Assets", "UI", "Templates", "ButtonTemplate")
			local parent = track(Instance.new("Frame"))

			local handle = ButtonElement.mount(parent, {
				text = "Shop",
				name = "ShopButton",
				color = { r = 0.1, g = 0.2, b = 0.3 },
				layoutOrder = 10,
				activated = function() end,
			})

			local button = handle.instance
			expect(button.Parent).to.equal(parent)
			expect(button:IsA("ImageButton")).to.equal(true)
			expect(button.Name).to.equal("ShopButton")
			expect(button.LayoutOrder).to.equal(10)
			expect(button.Visible).to.equal(true)
			expect(button.AutoButtonColor).to.equal(false)
			expect(button.ImageColor3).to.equal(Color3.new(0.1, 0.2, 0.3))

			local label = button:FindFirstChild("Label")
			expect(label).to.be.ok()
			expect(label.Text).to.equal("Shop")
			expect(label.TextScaled).to.equal(false)
			expect(label.TextSize >= UIConfig.Elements.Button.Text.MinSize).to.equal(true)
			expect(label.TextSize <= UIConfig.Elements.Button.Text.MaxSize).to.equal(true)

			local scale = button:FindFirstChild("InteractionScale")
			expect(scale).to.be.ok()
			expect(scale:IsA("UIScale")).to.equal(true)

			local selectedConfig = UIConfig.Elements.Button.SelectedColor
			handle:setSelected(true)
			expect(button.ImageColor3).to.equal(Color3.new(selectedConfig.r, selectedConfig.g, selectedConfig.b))

			handle:setEnabled(false)
			expect(button.Active).to.equal(false)

			handle:destroy()
			expect(button.Parent).never.to.be.ok()
			expect(handle:isDestroyed()).to.equal(true)
		end)

		it("routes interaction through scripted signals and cleans up events", function()
			local template = TestAssets.get(ReplicatedStorage, "Assets", "UI", "Templates", "ButtonTemplate")
			local parent = track(Instance.new("Frame"))
			local activated = 0
			local tweenCancels = 0
			local lastTweenGoal = nil
			local scaleDestroyed = false

			-- Scripted signal overlay: mount reads events off the clone, so wrap
			-- the real clone in a proxy exposing fake signals.
			local clone = template:Clone()
			track(clone)
			local fakeSignals = {
				MouseEnter = signal(),
				MouseLeave = signal(),
				MouseButton1Down = signal(),
				MouseButton1Up = signal(),
				MouseButton1Click = signal(),
			}
			local proxyTemplate = setmetatable({
				Clone = function()
					local proxy = setmetatable({}, {
						__index = function(_self, key)
							if fakeSignals[key] then
								return fakeSignals[key]
							end
							local value = clone[key]
							if typeof(value) == "function" then
								return function(_proxySelf, ...)
									return value(clone, ...)
								end
							end
							return value
						end,
						__newindex = function(_self, key, value)
							clone[key] = value
						end,
					})
					return proxy
				end,
				IsA = function(_self, className)
					return template:IsA(className)
				end,
			}, {})

			local handle = ButtonElement.mount(parent, {
				text = "Shop",
				name = "ShopButton",
				color = { r = 0.1, g = 0.2, b = 0.3 },
				activated = function()
					activated += 1
				end,
			}, {
				template = proxyTemplate,
				config = UIConfig.Elements.Button,
				tweens = UIConfig.Tweens.Button,
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
					bind = function(_label, _boundsGui, _options)
						return function() end
					end,
				},
			})

			fakeSignals.MouseButton1Click:Fire()
			expect(activated).to.equal(1)

			fakeSignals.MouseEnter:Fire()
			expect(lastTweenGoal.Scale).to.be.near(UIConfig.Elements.Button.HoverScale)

			handle:setSelected(true)
			expect(lastTweenGoal.Scale).to.be.near(UIConfig.Elements.Button.SelectedScale)

			handle:destroy()
			fakeSignals.MouseButton1Click:Fire()

			expect(activated).to.equal(1)
			expect(scaleDestroyed).to.equal(true)
			expect(tweenCancels > 0).to.equal(true)
		end)
	end)

	describe("QuestCardElement", function()
		it("mounts the real template with quest data and claim gating", function()
			local template = TestAssets.get(ReplicatedStorage, "Assets", "UI", "Templates", "QuestCard")
			local parent = track(Instance.new("Frame"))
			local mountedButtons = {}
			local claimed = nil

			local handle = QuestCardElement.mount(parent, {
				data = questData(),
				claim = function(questId)
					claimed = questId
				end,
			}, {
				template = template,
				buttonElement = fakeButtonElement(mountedButtons),
			})

			local card = handle.instance
			expect(card.Parent).to.equal(parent)
			expect(card.Name).to.equal("QuestCard_elims_5")
			expect(card:FindFirstChild("Title").Text).to.equal("1. Get 5 eliminations")
			expect(card:FindFirstChild("Count").Text).to.equal("2/5")
			expect(card:FindFirstChild("Rewards").Text).to.equal("150 coins")

			local progress = card:FindFirstChild("Progress")
			local gradient = progress:FindFirstChild("UIGradient")
			expect(gradient).to.be.ok()

			local keypoints = gradient.Color.Keypoints
			expect(#keypoints).to.equal(4)
			expect(keypoints[1].Value).to.equal(QuestsConfig.Progress.FillColor)
			expect(keypoints[4].Value).to.equal(QuestsConfig.Progress.EmptyColor)
			local partialOffset = gradient.Offset.X
			expect(partialOffset).to.be.near(-0.1)

			local visibleDividers = 0
			for _, child in progress:GetChildren() do
				if child:IsA("Frame") and child.Visible then
					visibleDividers += 1
				end
			end
			expect(visibleDividers).to.equal(4)

			expect(#mountedButtons).to.equal(1)
			expect(mountedButtons[1].props.text).to.equal("Claim")
			expect(mountedButtons[1].instance.enabled).to.equal(false)
			expect(mountedButtons[1].instance.AnchorPoint).to.equal(Vector2.new(1, 1))

			mountedButtons[1].props.activated()
			expect(claimed).never.to.be.ok()

			handle:setData(questData({ progress = 4 }))
			local grownOffset = gradient.Offset.X
			expect(grownOffset).to.be.near(0.3)
			expect(grownOffset > partialOffset).to.equal(true)

			handle:setData(questData({ progress = 5, completed = true }))
			local lastButton = mountedButtons[#mountedButtons]
			expect(lastButton.instance.enabled).to.equal(true)
			lastButton.props.activated()
			expect(claimed).to.equal("elims_5")

			handle:setData(questData({ progress = 5, completed = true, claimed = true }))
			expect(mountedButtons[#mountedButtons].props.text).to.equal("Claimed")

			handle:destroy()
			expect(card.Parent).never.to.be.ok()
		end)

		it("renders empty and full fills as solid color sequences", function()
			local template = TestAssets.get(ReplicatedStorage, "Assets", "UI", "Templates", "QuestCard")
			local parent = track(Instance.new("Frame"))

			local handle = QuestCardElement.mount(parent, {
				data = questData({ progress = 0 }),
				claim = function() end,
			}, {
				template = template,
				buttonElement = fakeButtonElement({}),
			})

			local gradient = handle.instance:FindFirstChild("Progress"):FindFirstChild("UIGradient")
			local emptyKeypoints = gradient.Color.Keypoints
			for _, keypoint in emptyKeypoints do
				expect(keypoint.Value).to.equal(QuestsConfig.Progress.EmptyColor)
			end

			handle:setData(questData({ progress = 5 }))
			for _, keypoint in gradient.Color.Keypoints do
				expect(keypoint.Value).to.equal(QuestsConfig.Progress.FillColor)
			end

			handle:destroy()
		end)

		it("mounts a fully real claim button through the real ButtonElement", function()
			local template = TestAssets.get(ReplicatedStorage, "Assets", "UI", "Templates", "QuestCard")
			local parent = track(Instance.new("Frame"))

			local handle = QuestCardElement.mount(parent, {
				data = questData(),
				claim = function() end,
			}, {
				template = template,
			})

			local claimButton = handle.instance:FindFirstChild("ClaimButton")
			expect(claimButton).to.be.ok()
			expect(claimButton:IsA("ImageButton")).to.equal(true)
			expect(claimButton:FindFirstChild("Label").Text).to.equal("Claim")
			expect(claimButton:FindFirstChild("InteractionScale")).to.be.ok()
			expect(claimButton.AnchorPoint).to.equal(Vector2.new(1, 1))
			expect(claimButton.Active).to.equal(false)

			handle:destroy()
		end)
	end)

	describe("TextSizer", function()
		it("returns the largest text size that fits the provided bounds", function()
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

			expect(size).to.equal(16)
		end)

		it("measures with the real TextService within the configured range", function()
			local small = TextSizer.textSizeForBounds("Play", Vector2.new(60, 24), {})
			local large = TextSizer.textSizeForBounds("Play", Vector2.new(600, 240), {})

			expect(small >= 1).to.equal(true)
			expect(large >= small).to.equal(true)
			expect(large <= UIConfig.Text.DefaultMaxSize).to.equal(true)
		end)
	end)
end
