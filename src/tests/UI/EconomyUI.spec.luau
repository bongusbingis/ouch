--!nonstrict
-- Cloud port of the EconomyUI spec: EconomyStore projection, item element
-- rendering/routing, prototype layout, and Shop/Inventory controllers.
-- Replica source, network, and menu manager stay injected doubles; the layout
-- and a render pass run on real Instances (real UDim2/Vector2 typing that the
-- Lune fakes could not check). Button activation still uses a scripted signal
-- because real GuiButton events cannot be fired without a client.

local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local UI = Client:WaitForChild("Modules"):WaitForChild("UI")
local EconomyStore = require(UI:WaitForChild("EconomyStore"))
local EconomyPrototypeLayout = require(UI:WaitForChild("EconomyPrototypeLayout"))
local EconomyItemElement = require(UI:WaitForChild("Elements"):WaitForChild("EconomyItemElement"))
local ShopController = require(UI:WaitForChild("ShopController"))
local InventoryController = require(UI:WaitForChild("InventoryController"))

local function signal()
	local callbacks = {}
	local object = {}
	function object:Connect(callback)
		local connection = { connected = true }
		function connection:Disconnect()
			self.connected = false
		end
		table.insert(callbacks, { callback = callback, connection = connection })
		return connection
	end
	function object:Fire(...)
		for _, entry in callbacks do
			if entry.connection.connected then
				entry.callback(...)
			end
		end
	end
	return object
end

local function fakeGui(name: string, className: string)
	local gui = {
		Name = name,
		ClassName = className,
		Parent = nil,
		Visible = false,
		LayoutOrder = 0,
		Text = "",
		Active = true,
		Selectable = true,
		destroyed = false,
		_children = {},
		_order = {},
	}
	function gui:IsA(target: string): boolean
		return self.ClassName == target
			or (
				target == "GuiObject"
				and (
					self.ClassName == "Frame"
					or self.ClassName == "TextLabel"
					or self.ClassName == "TextButton"
					or self.ClassName == "ScrollingFrame"
				)
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
		clone.Visible = self.Visible
		clone.LayoutOrder = self.LayoutOrder
		if self.ClassName == "TextButton" then
			clone.Activated = signal()
		end
		for _, child in self._order do
			local childClone = child:Clone()
			clone._children[childClone.Name] = childClone
			table.insert(clone._order, childClone)
		end
		return clone
	end
	function gui:Destroy()
		self.destroyed = true
	end
	if className == "TextButton" then
		gui.Activated = signal()
	end
	return gui
end

local function addChild(parent, child)
	parent._children[child.Name] = child
	table.insert(parent._order, child)
	return child
end

local function economyItemTemplate()
	local row = fakeGui("EconomyItem", "Frame")
	addChild(row, fakeGui("ItemName", "TextLabel"))
	addChild(row, fakeGui("Details", "TextLabel"))
	addChild(row, fakeGui("State", "TextLabel"))
	addChild(row, fakeGui("Action", "TextButton"))
	return row
end

local function fakeStore(data)
	local callbacks = {}
	local store = {
		data = data,
		started = false,
	}
	function store.start()
		store.started = true
	end
	function store.snapshot()
		return store.data
	end
	function store.onChanged(callback)
		table.insert(callbacks, callback)
		callback(store.data)
		return function() end
	end
	function store:setData(nextData)
		self.data = nextData
		for _, callback in callbacks do
			callback(nextData)
		end
	end
	return store
end

local function fakeMenu()
	local callbacks = {}
	local menu = {
		open = nil,
	}
	function menu.isOpen(menuId)
		return menu.open == menuId
	end
	function menu.onChanged(callback)
		table.insert(callbacks, callback)
		return function() end
	end
	function menu:setOpen(menuId)
		self.open = menuId
		for _, callback in callbacks do
			callback(menuId)
		end
	end
	return menu
end

local function fakeItemElement()
	local mounted = {}
	local element = {}
	function element.mount(parent, props)
		local handle = {
			parent = parent,
			props = props,
			destroyed = false,
		}
		function handle:destroy()
			self.destroyed = true
		end
		table.insert(mounted, handle)
		return handle
	end
	return element, mounted
end

local function immediate(callback)
	callback()
end

-- Real-Instance fixture matching the runtime-generated EconomyItem prototype
-- (EconomyPrototypeUI builds this exact shape at runtime on the client).
local function realEconomyItemTemplate(): Frame
	local row = Instance.new("Frame")
	row.Name = "EconomyItem"
	for _, labelName in { "ItemName", "Details", "State" } do
		local label = Instance.new("TextLabel")
		label.Name = labelName
		label.Parent = row
	end
	local action = Instance.new("TextButton")
	action.Name = "Action"
	action.Parent = row
	return row
end

return function()
	describe("EconomyStore", function()
		it("projects GameProfile Cash and Cosmetics changes", function()
			EconomyStore._resetForTest()
			local newReplicaCallback = nil
			local source = {
				OnNew = function(token, callback)
					expect(token).to.equal("GameProfile")
					newReplicaCallback = callback
					return { Disconnect = function() end }
				end,
			}
			local changeCallback = nil
			local profile = {
				Data = {
					Cash = 10,
					Cosmetics = { Owned = {}, Equipped = {} },
				},
				OnChange = function(_self, callback)
					changeCallback = callback
					return { Disconnect = function() end }
				end,
			}
			local seen = {}
			EconomyStore.start(source)
			EconomyStore.onChanged(function(data)
				table.insert(seen, data.Cash)
			end)
			newReplicaCallback(profile)
			expect(seen[#seen]).to.equal(10)

			profile.Data.Cash = 25
			changeCallback("Set", { "Cash" }, 25, 10)
			expect(seen[#seen]).to.equal(25)
			local count = #seen
			changeCallback("Set", { "Quests", "DailyKey" }, "next", "old")
			expect(#seen).to.equal(count)
			EconomyStore._resetForTest()
		end)
	end)

	describe("EconomyItemElement", function()
		it("renders an unstyled row and routes Activated", function()
			local selected = nil
			local handle = EconomyItemElement.mount(fakeGui("Holder", "ScrollingFrame"), {
				data = {
					id = "BallRed",
					title = "Red Ball",
					details = "Category: BallAssets",
					state = "Owned",
					actionText = "Equip",
					actionEnabled = true,
					layoutOrder = 2,
				},
				activated = function(itemId)
					selected = itemId
				end,
			}, {
				template = economyItemTemplate(),
			})
			local row = handle.instance
			expect(row:WaitForChild("ItemName").Text).to.equal("Red Ball")
			expect(row.AnchorPoint.X).to.equal(0)
			expect(row.Position.Y.Scale).to.equal(0)
			expect(row.Size.X.Scale).to.equal(1)
			expect(row.Size.Y.Offset).to.equal(88)
			expect(row.ZIndex).to.equal(11)
			local itemName = row:WaitForChild("ItemName")
			local action = row:WaitForChild("Action")
			expect(itemName.Position.X.Scale).to.equal(0)
			expect(itemName.Size.X.Scale).to.be.near(0.7)
			expect(action.Position.X.Scale).to.be.near(0.72)
			expect(action.Position.Y.Scale).to.be.near(0.2)
			expect(action.Size.X.Scale).to.be.near(0.28)
			expect(action.Size.Y.Scale).to.be.near(0.6)
			expect(row:WaitForChild("Action").Text).to.equal("Equip")
			expect(row.LayoutOrder).to.equal(2)
			row:WaitForChild("Action").Activated:Fire()
			expect(selected).to.equal("BallRed")

			handle:setData({
				id = "BallRed",
				title = "Red Ball",
				details = "Category: BallAssets",
				state = "Equipped",
				actionText = "Unequip",
				actionEnabled = false,
				layoutOrder = 2,
			})
			selected = nil
			row:WaitForChild("Action").Activated:Fire()
			expect(selected).never.to.be.ok()
			handle:destroy()
			expect(row.destroyed).to.equal(true)
		end)

		it("renders onto a real Instance template with real geometry types", function()
			local holder = Instance.new("ScrollingFrame")
			local template = realEconomyItemTemplate()

			local handle = EconomyItemElement.mount(holder, {
				data = {
					id = "BallRed",
					title = "Red Ball",
					details = "Category: BallAssets",
					state = "Owned",
					actionText = "Equip",
					actionEnabled = true,
					layoutOrder = 2,
				},
				activated = function() end,
			}, {
				template = template,
			})

			local row = handle.instance
			expect(row.Parent).to.equal(holder)
			expect(row.Name).to.equal("EconomyItem_BallRed")
			expect(row.Size).to.equal(UDim2.new(1, 0, 0, 88))
			expect(row.AnchorPoint).to.equal(Vector2.new(0, 0))
			expect(row.ZIndex).to.equal(11)

			local action = row:FindFirstChild("Action")
			expect(action.Text).to.equal("Equip")
			expect(action.Active).to.equal(true)

			handle:setData({
				id = "BallRed",
				title = "Red Ball",
				details = "Category: BallAssets",
				state = "Equipped",
				actionText = "Unequip",
				actionEnabled = false,
				layoutOrder = 2,
			})
			expect(action.Text).to.equal("Unequip")
			expect(action.Active).to.equal(false)

			handle:destroy()
			expect(row.Parent).never.to.be.ok()

			template:Destroy()
			holder:Destroy()
		end)
	end)

	describe("EconomyPrototypeLayout", function()
		it("places real view children relative to their immediate view ancestor", function()
			local shop = Instance.new("Frame")
			shop.Name = "Shop"
			for _, labelName in { "Title", "Cash", "Status" } do
				local label = Instance.new("TextLabel")
				label.Name = labelName
				label.Parent = shop
			end
			local shopHolder = Instance.new("ScrollingFrame")
			shopHolder.Name = "Holder"
			shopHolder.Parent = shop

			EconomyPrototypeLayout.applyShop(shop)

			expect(shop.AnchorPoint).to.equal(Vector2.new(0.5, 0.5))
			expect(shop.Position).to.equal(UDim2.fromScale(0.5, 0.5))
			expect(shop.Size).to.equal(UDim2.fromScale(0.86, 0.82))
			expect(shop.ZIndex).to.equal(10)
			expect(shop.ClipsDescendants).to.equal(true)
			expect(shopHolder.AnchorPoint).to.equal(Vector2.new(0, 0))
			expect(shopHolder.Position).to.equal(UDim2.fromScale(0, 0.3))
			expect(shopHolder.Size).to.equal(UDim2.fromScale(1, 0.7))

			local inventory = Instance.new("Frame")
			inventory.Name = "Inventory"
			for _, labelName in { "Title", "Status" } do
				local label = Instance.new("TextLabel")
				label.Name = labelName
				label.Parent = inventory
			end
			local inventoryHolder = Instance.new("ScrollingFrame")
			inventoryHolder.Name = "Holder"
			inventoryHolder.Parent = inventory

			EconomyPrototypeLayout.applyInventory(inventory)

			expect(inventory.AnchorPoint).to.equal(Vector2.new(0.5, 0.5))
			expect(inventory.Position).to.equal(UDim2.fromScale(0.5, 0.5))
			expect(inventory.Size).to.equal(UDim2.fromScale(0.86, 0.82))
			expect(inventoryHolder.AnchorPoint).to.equal(Vector2.new(0, 0))
			expect(inventoryHolder.Position).to.equal(UDim2.fromScale(0, 0.2))
			expect(inventoryHolder.Size).to.equal(UDim2.fromScale(1, 0.8))

			shop:Destroy()
			inventory:Destroy()
		end)
	end)

	describe("ShopController", function()
		it("lists cash crates and reports real open results", function()
			ShopController._resetForTest()
			local store = fakeStore({
				Cash = 1000,
				Cosmetics = { Owned = {}, Equipped = {} },
			})
			local menu = fakeMenu()
			local itemElement, mounted = fakeItemElement()
			local calls = {}
			local listeners = {}
			local network = {
				on = function(name, callback)
					listeners[name] = callback
				end,
				call = function(name, ...)
					table.insert(calls, { name = name, args = { ... } })
					return {
						crateId = "BallCrate",
						itemId = "BallRed",
						rarity = "Common",
						isDupe = false,
						cashRefund = 0,
					}
				end,
			}
			local cashLabel = { Text = "" }
			local statusLabel = { Text = "" }
			ShopController.start({
				store = store,
				network = network,
				menuManager = menu,
				itemElement = itemElement,
				crates = {
					BallCrate = { DisplayName = "Ball Crate", CashPrice = 500, ItemPool = { "BallRed" } },
				},
				cosmetics = {
					Items = { BallRed = { DisplayName = "Red Ball" } },
				},
				holder = { Name = "Holder" },
				cashLabel = cashLabel,
				statusLabel = statusLabel,
				runAsync = immediate,
			})
			expect(cashLabel.Text).to.equal("Cash: 1000")
			expect(#mounted).to.equal(0)

			menu:setOpen("Shop")
			expect(#mounted).to.equal(1)
			expect(statusLabel.Text).to.equal("Select a crate to open.")
			expect(mounted[1].props.data.actionText).to.equal("Open - 500 Cash")
			mounted[1].props.activated("BallCrate")
			expect(calls[#calls].name).to.equal("OpenCrate")
			expect(calls[#calls].args[1]).to.equal("BallCrate")
			expect(statusLabel.Text).to.equal("Opened Red Ball.")
			expect(listeners.CrateOpened).to.be.ok()
			ShopController._resetForTest()
		end)
	end)

	describe("InventoryController", function()
		it("lists owned items and routes equip and unequip", function()
			InventoryController._resetForTest()
			local data = {
				Cash = 0,
				Cosmetics = {
					Owned = { BallRed = true, BallBlue = true },
					Equipped = { BallAssets = "BallRed" },
				},
			}
			local store = fakeStore(data)
			local menu = fakeMenu()
			local itemElement, mounted = fakeItemElement()
			local calls = {}
			local network = {
				call = function(name, ...)
					table.insert(calls, { name = name, args = { ... } })
					return true
				end,
			}
			local statusLabel = { Text = "" }
			local cosmetics = {
				Defaults = {
					BallAssets = { DisplayName = "Default Dodgeball" },
				},
				Items = {
					BallBlue = { DisplayName = "Blue Ball", Category = "BallAssets", Rarity = "Common" },
					BallRed = { DisplayName = "Red Ball", Category = "BallAssets", Rarity = "Common" },
				},
			}
			InventoryController.start({
				store = store,
				network = network,
				menuManager = menu,
				itemElement = itemElement,
				cosmetics = cosmetics,
				holder = { Name = "Holder" },
				statusLabel = statusLabel,
				runAsync = immediate,
			})
			menu:setOpen("Inventory")
			expect(#mounted).to.equal(3)
			expect(statusLabel.Text).to.equal("Select an item to equip.")
			expect(mounted[1].props.data.title).to.equal("Default Dodgeball")
			expect(mounted[1].props.data.actionText).to.equal("Use Default")
			expect(mounted[2].props.data.title).to.equal("Blue Ball")
			expect(mounted[2].props.data.actionText).to.equal("Equip")
			expect(mounted[3].props.data.actionText).to.equal("Unequip")

			mounted[2].props.activated("BallBlue")
			expect(calls[#calls].name).to.equal("EquipCosmetic")
			expect(calls[#calls].args[1]).to.equal("BallAssets")
			expect(calls[#calls].args[2]).to.equal("BallBlue")

			local redHandle = mounted[3]
			redHandle.props.activated("BallRed")
			expect(calls[#calls].args[1]).to.equal("BallAssets")
			expect(calls[#calls].args[2]).never.to.be.ok()
			expect(statusLabel.Text).to.equal("Equipped Default Dodgeball.")
			InventoryController._resetForTest()
		end)

		it("shows the equipped default dodgeball when no cosmetics are owned", function()
			InventoryController._resetForTest()
			local store = fakeStore({
				Cash = 0,
				Cosmetics = { Owned = {}, Equipped = {} },
			})
			local menu = fakeMenu()
			local itemElement, mounted = fakeItemElement()
			local calls = 0
			InventoryController.start({
				store = store,
				network = {
					call = function()
						calls += 1
						return true
					end,
				},
				menuManager = menu,
				itemElement = itemElement,
				cosmetics = {
					Defaults = {
						BallAssets = { DisplayName = "Default Dodgeball" },
					},
					Items = {},
				},
				holder = { Name = "Holder" },
				statusLabel = { Text = "" },
				runAsync = immediate,
			})

			menu:setOpen("Inventory")
			expect(#mounted).to.equal(1)
			expect(mounted[1].props.data.title).to.equal("Default Dodgeball")
			expect(mounted[1].props.data.state).to.equal("Equipped")
			expect(mounted[1].props.data.actionEnabled).to.equal(false)
			mounted[1].props.activated("Default_BallAssets")
			expect(calls).to.equal(0)
			InventoryController._resetForTest()
		end)
	end)
end
