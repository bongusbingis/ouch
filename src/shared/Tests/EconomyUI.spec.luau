--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local EconomyStore = require(Client.Modules.UI.EconomyStore)
local EconomyPrototypeLayout = require(Client.Modules.UI.EconomyPrototypeLayout)
local EconomyItemElement = require(Client.Modules.UI.Elements.EconomyItemElement)
local ShopController = require(Client.Modules.UI.ShopController)
local InventoryController = require(Client.Modules.UI.InventoryController)

local function signal()
	local callbacks = {}
	local object = {} :: any
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

local function fakeGui(name: string, className: string): any
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
	function gui:FindFirstChild(childName: string)
		return self._children[childName]
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

local function addChild(parent: any, child: any): any
	parent._children[child.Name] = child
	table.insert(parent._order, child)
	return child
end

local function economyItemTemplate(): any
	local row = fakeGui("EconomyItem", "Frame")
	addChild(row, fakeGui("ItemName", "TextLabel"))
	addChild(row, fakeGui("Details", "TextLabel"))
	addChild(row, fakeGui("State", "TextLabel"))
	addChild(row, fakeGui("Action", "TextButton"))
	return row
end

local function fakeStore(data: any)
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
		open = nil :: string?,
	}
	function menu.isOpen(menuId)
		return menu.open == menuId
	end
	function menu.onChanged(callback)
		table.insert(callbacks, callback)
		return function() end
	end
	function menu:setOpen(menuId: string?)
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

T.describe("EconomyStore", function()
	T.it("projects GameProfile Cash and Cosmetics changes", function()
		EconomyStore._resetForTest()
		local newReplicaCallback = nil :: any
		local source = {
			OnNew = function(token, callback)
				T.expect(token):toEqual("GameProfile")
				newReplicaCallback = callback
				return { Disconnect = function() end }
			end,
		}
		local changeCallback = nil :: any
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
		T.expect(seen[#seen]):toEqual(10)

		profile.Data.Cash = 25
		changeCallback("Set", { "Cash" }, 25, 10)
		T.expect(seen[#seen]):toEqual(25)
		local count = #seen
		changeCallback("Set", { "Quests", "DailyKey" }, "next", "old")
		T.expect(#seen):toEqual(count)
		EconomyStore._resetForTest()
	end)
end)

T.describe("EconomyItemElement", function()
	T.it("renders an unstyled row and routes Activated", function()
		local selected = nil :: string?
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
		local row = handle.instance :: any
		T.expect(row:WaitForChild("ItemName").Text):toEqual("Red Ball")
		T.expect(row.AnchorPoint.X):toEqual(0)
		T.expect(row.Position.Y.Scale):toEqual(0)
		T.expect(row.Size.X.Scale):toEqual(1)
		T.expect(row.Size.Y.Offset):toEqual(88)
		T.expect(row.ZIndex):toEqual(11)
		local itemName = row:WaitForChild("ItemName")
		local action = row:WaitForChild("Action")
		T.expect(itemName.Position.X.Scale):toEqual(0)
		T.expect(itemName.Size.X.Scale):toEqual(0.7)
		T.expect(action.Position.X.Scale):toEqual(0.72)
		T.expect(action.Position.Y.Scale):toEqual(0.2)
		T.expect(action.Size.X.Scale):toEqual(0.28)
		T.expect(action.Size.Y.Scale):toEqual(0.6)
		T.expect(row:WaitForChild("Action").Text):toEqual("Equip")
		T.expect(row.LayoutOrder):toEqual(2)
		row:WaitForChild("Action").Activated:Fire()
		T.expect(selected):toEqual("BallRed")

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
		T.expect(selected):toBeNil()
		handle:destroy()
		T.expect(row.destroyed):toEqual(true)
	end)
end)

T.describe("EconomyPrototypeLayout", function()
	T.it("places view children relative to their immediate view ancestor", function()
		local shop = fakeGui("Shop", "Frame")
		addChild(shop, fakeGui("Title", "TextLabel"))
		addChild(shop, fakeGui("Cash", "TextLabel"))
		addChild(shop, fakeGui("Status", "TextLabel"))
		addChild(shop, fakeGui("Holder", "ScrollingFrame"))
		EconomyPrototypeLayout.applyShop(shop)

		T.expect(shop.AnchorPoint.X):toEqual(0.5)
		T.expect(shop.AnchorPoint.Y):toEqual(0.5)
		T.expect(shop.Position.X.Scale):toEqual(0.5)
		T.expect(shop.Position.Y.Scale):toEqual(0.5)
		T.expect(shop.Size.X.Scale):toEqual(0.86)
		T.expect(shop.Size.Y.Scale):toEqual(0.82)
		T.expect(shop.ZIndex):toEqual(10)
		T.expect(shop.ClipsDescendants):toEqual(true)
		local shopHolder = shop:WaitForChild("Holder")
		T.expect(shopHolder.AnchorPoint.X):toEqual(0)
		T.expect(shopHolder.Position.Y.Scale):toEqual(0.3)
		T.expect(shopHolder.Size.X.Scale):toEqual(1)
		T.expect(shopHolder.Size.Y.Scale):toEqual(0.7)

		local inventory = fakeGui("Inventory", "Frame")
		addChild(inventory, fakeGui("Title", "TextLabel"))
		addChild(inventory, fakeGui("Status", "TextLabel"))
		addChild(inventory, fakeGui("Holder", "ScrollingFrame"))
		EconomyPrototypeLayout.applyInventory(inventory)

		T.expect(inventory.AnchorPoint.X):toEqual(0.5)
		T.expect(inventory.Position.X.Scale):toEqual(0.5)
		T.expect(inventory.Size.X.Scale):toEqual(0.86)
		T.expect(inventory.Size.Y.Scale):toEqual(0.82)
		local inventoryHolder = inventory:WaitForChild("Holder")
		T.expect(inventoryHolder.AnchorPoint.Y):toEqual(0)
		T.expect(inventoryHolder.Position.Y.Scale):toEqual(0.2)
		T.expect(inventoryHolder.Size.X.Scale):toEqual(1)
		T.expect(inventoryHolder.Size.Y.Scale):toEqual(0.8)
	end)
end)

T.describe("ShopController", function()
	T.it("lists cash crates and reports real open results", function()
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
			holder = { Name = "Holder" } :: any,
			cashLabel = cashLabel :: any,
			statusLabel = statusLabel :: any,
			runAsync = immediate,
		})
		T.expect(cashLabel.Text):toEqual("Cash: 1000")
		T.expect(#mounted):toEqual(0)

		menu:setOpen("Shop")
		T.expect(#mounted):toEqual(1)
		T.expect(statusLabel.Text):toEqual("Select a crate to open.")
		T.expect(mounted[1].props.data.actionText):toEqual("Open - 500 Cash")
		mounted[1].props.activated("BallCrate")
		T.expect(calls[#calls].name):toEqual("OpenCrate")
		T.expect(calls[#calls].args[1]):toEqual("BallCrate")
		T.expect(statusLabel.Text):toEqual("Opened Red Ball.")
		T.expect(listeners.CrateOpened ~= nil):toBeTruthy()
		ShopController._resetForTest()
	end)

	T.it("features the crate with the broadest rarity selection", function()
		ShopController._resetForTest()
		local store = fakeStore({ Cash = 2000, Cosmetics = { Owned = {}, Equipped = {} } })
		local menu = fakeMenu()
		local crateElement, mounted = fakeItemElement()
		local holder = { Name = "Holder" }
		local featuredMount = { Name = "FeaturedMount" }
		ShopController.start({
			store = store,
			network = {
				on = function() end,
				call = function()
					return nil
				end,
			},
			menuManager = menu,
			crateElement = crateElement,
			crates = {
				BallCrate = { DisplayName = "Ball Crate", CashPrice = 500, ItemPool = { "BallRed" } },
				TrailCrate = {
					DisplayName = "Trail Crate",
					CashPrice = 1000,
					ItemPool = { "TrailMint", "TrailSolar" },
				},
			},
			cosmetics = {
				Rarities = { Common = { Weight = 70 }, Legendary = { Weight = 6 } },
				Items = {
					BallRed = { DisplayName = "Red Ball", Rarity = "Common" },
					TrailMint = { DisplayName = "Mint Mist", Rarity = "Common" },
					TrailSolar = { DisplayName = "Solar Flare", Rarity = "Legendary" },
				},
			},
			holder = holder :: any,
			featuredMount = featuredMount :: any,
			cashLabel = { Text = "" } :: any,
			statusLabel = { Text = "" } :: any,
			runAsync = immediate,
		})

		menu:setOpen("Shop")
		T.expect(#mounted):toEqual(2)
		local featured = if mounted[1].props.data.featured then mounted[1] else mounted[2]
		T.expect(featured.parent):toEqual(featuredMount)
		T.expect(featured.props.data.title):toEqual("Trail Crate")
		T.expect(featured.props.data.odds):toEqual("ODDS  COMMON 92.1%  •  LEGENDARY 7.9%")
		ShopController._resetForTest()
	end)
end)

T.describe("InventoryController", function()
	T.it("lists owned items and routes equip and unequip", function()
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
			holder = { Name = "Holder" } :: any,
			statusLabel = statusLabel :: any,
			runAsync = immediate,
		})
		menu:setOpen("Inventory")
		T.expect(#mounted):toEqual(3)
		T.expect(statusLabel.Text):toEqual("Select an item to equip.")
		T.expect(mounted[1].props.data.title):toEqual("Default Dodgeball")
		T.expect(mounted[1].props.data.actionText):toEqual("Use Default")
		T.expect(mounted[2].props.data.title):toEqual("Blue Ball")
		T.expect(mounted[2].props.data.actionText):toEqual("Equip")
		T.expect(mounted[3].props.data.actionText):toEqual("Unequip")

		mounted[2].props.activated("BallBlue")
		T.expect(calls[#calls].name):toEqual("EquipCosmetic")
		T.expect(calls[#calls].args[1]):toEqual("BallAssets")
		T.expect(calls[#calls].args[2]):toEqual("BallBlue")

		local redHandle = mounted[3]
		redHandle.props.activated("BallRed")
		T.expect(calls[#calls].args[1]):toEqual("BallAssets")
		T.expect(calls[#calls].args[2]):toBeNil()
		T.expect(statusLabel.Text):toEqual("Equipped Default Dodgeball.")
		InventoryController._resetForTest()
	end)

	T.it("shows the equipped default dodgeball when no cosmetics are owned", function()
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
			holder = { Name = "Holder" } :: any,
			statusLabel = { Text = "" } :: any,
			runAsync = immediate,
		})

		menu:setOpen("Inventory")
		T.expect(#mounted):toEqual(1)
		T.expect(mounted[1].props.data.title):toEqual("Default Dodgeball")
		T.expect(mounted[1].props.data.state):toEqual("Equipped")
		T.expect(mounted[1].props.data.actionEnabled):toEqual(false)
		mounted[1].props.activated("Default_BallAssets")
		T.expect(calls):toEqual(0)
		InventoryController._resetForTest()
	end)

	T.it("shows only the selected asset category", function()
		InventoryController._resetForTest()
		local store = fakeStore({
			Cash = 0,
			Cosmetics = {
				Owned = { BallRed = true, TrailMint = true },
				Equipped = {},
			},
		})
		local menu = fakeMenu()
		local itemElement, mounted = fakeItemElement()
		local tabs = {
			BallAssets = fakeGui("BallAssets", "TextButton"),
			HammerAssets = fakeGui("HammerAssets", "TextButton"),
			TrailAssets = fakeGui("TrailAssets", "TextButton"),
		}
		for _, button in tabs do
			addChild(button, fakeGui("ColorWash", "UIGradient"))
			addChild(button, fakeGui("Outline", "UIStroke"))
		end
		local tabLabels = {
			BallAssets = fakeGui("Label", "TextLabel"),
			HammerAssets = fakeGui("Label", "TextLabel"),
			TrailAssets = fakeGui("Label", "TextLabel"),
		}
		local categoryTitle = fakeGui("CategoryTitle", "TextLabel")
		local itemCount = fakeGui("ItemCount", "TextLabel")
		local emptyLabel = fakeGui("Empty", "TextLabel")

		InventoryController.start({
			store = store,
			network = {
				call = function()
					return true
				end,
			},
			menuManager = menu,
			itemElement = itemElement,
			cosmetics = {
				Slots = { BallAssets = true, HammerAssets = true, TrailAssets = true },
				Defaults = { BallAssets = { DisplayName = "Default Dodgeball" } },
				Items = {
					BallRed = { DisplayName = "Red Ball", Category = "BallAssets", Rarity = "Common" },
					TrailMint = { DisplayName = "Mint Mist", Category = "TrailAssets", Rarity = "Rare" },
				},
			},
			holder = { Name = "Holder" } :: any,
			statusLabel = { Text = "" } :: any,
			tabs = tabs :: any,
			tabLabels = tabLabels :: any,
			categoryTitle = categoryTitle,
			itemCount = itemCount,
			emptyLabel = emptyLabel,
			runAsync = immediate,
		})

		menu:setOpen("Inventory")
		T.expect(#mounted):toEqual(2)
		T.expect(mounted[1].props.data.title):toEqual("Default Dodgeball")
		T.expect(mounted[2].props.data.title):toEqual("Red Ball")
		T.expect(categoryTitle.Text):toEqual("DODGEBALLS")
		T.expect(itemCount.Text):toEqual("2 ITEMS")

		tabs.TrailAssets.Activated:Fire()
		T.expect(mounted[#mounted].props.data.title):toEqual("Mint Mist")
		T.expect(mounted[#mounted].props.data.rarity):toEqual("Rare")
		T.expect(categoryTitle.Text):toEqual("TRAIL EFFECTS")
		T.expect(itemCount.Text):toEqual("1 ITEM")

		tabs.HammerAssets.Activated:Fire()
		T.expect(emptyLabel.Visible):toEqual(true)
		T.expect(categoryTitle.Text):toEqual("HAMMERS")
		T.expect(itemCount.Text):toEqual("0 ITEMS")
		InventoryController._resetForTest()
	end)
end)

return true
