--!nonstrict

local StarterPlayer = game:GetService("StarterPlayer")

local UI =
	StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("UI")
local ShopController = require(UI:WaitForChild("ShopController"))

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

local function fakeMenu()
	local callbacks = {}
	local menu = { open = nil }
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

local function fakeStore()
	local data = { Cash = 1000, Cosmetics = { Owned = {}, Equipped = {} } }
	return {
		start = function() end,
		snapshot = function()
			return data
		end,
		onChanged = function()
			return function() end
		end,
	}
end

local function fakeElement()
	local mounted = {}
	local element = {}
	function element.mount(parent, props)
		local handle = { parent = parent, props = props, instance = {}, destroyed = false }
		function handle:destroy()
			self.destroyed = true
		end
		table.insert(mounted, handle)
		return handle
	end
	return element, mounted
end

local function activeCards(mounted)
	local cards = {}
	for _, handle in mounted do
		if not handle.destroyed then
			table.insert(cards, handle)
		end
	end
	return cards
end

return function()
	describe("ShopController offers", function()
		beforeEach(function()
			ShopController._resetForTest()
		end)

		afterEach(function()
			ShopController._resetForTest()
		end)

		it("renders live regional prices and routes each active offer to its platform prompt", function()
			local menu = fakeMenu()
			local offerElement, mountedCards = fakeElement()
			local crateElement = fakeElement()
			local player = { UserId = 810001 }
			local passFinished = signal()
			local productFinished = signal()
			local prompts = {}
			local listeners = {}
			local marketplace = {
				PromptGamePassPurchaseFinished = passFinished,
				PromptProductPurchaseFinished = productFinished,
				GetProductInfoAsync = function(_self, productId)
					return {
						Name = if productId == 101 then "Spark Pass" else "500 Cash",
						IconImageAssetId = productId + 1000,
						PriceInRobux = if productId == 101 then 149 else 49,
						IsForSale = true,
					}
				end,
				UserOwnsGamePassAsync = function()
					return false
				end,
				PromptGamePassPurchase = function(_self, _player, productId)
					table.insert(prompts, { kind = "GamePass", id = productId })
				end,
				PromptProductPurchase = function(_self, _player, productId)
					table.insert(prompts, { kind = "Product", id = productId })
				end,
			}
			local network = {
				on = function(name, callback)
					listeners[name] = callback
				end,
				fireServer = function() end,
			}
			local catalog = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared")
					:WaitForChild("Game")
					:WaitForChild("Economy")
					:WaitForChild("StoreCatalog")
			)
			ShopController.start({
				store = fakeStore(),
				network = network,
				marketplace = marketplace,
				player = player,
				menuManager = menu,
				offerElement = offerElement,
				crateElement = crateElement,
				gamePasses = {
					Catalog = {
						SparkPass = {
							Id = 101,
							CatalogStatus = "Active",
							DisplayName = "Spark Pass",
							Description = "Permanent spark cosmetics.",
							DisplayOrder = 10,
						},
					},
				},
				products = {
					Catalog = {
						Cash500 = {
							Id = 202,
							CatalogStatus = "Active",
							DisplayName = "500 Cash",
							Description = "Cash top-up.",
							DisplayOrder = 20,
							Type = "Cash",
							CashAmount = 500,
						},
					},
				},
				storeCatalog = catalog,
				crates = {},
				cosmetics = { Items = {}, Rarities = {} },
				paidRandomPolicy = {
					start = function() end,
					snapshot = function()
						return true
					end,
					onChanged = function(callback)
						callback(true)
						return function() end
					end,
				},
				cratesHolder = {},
				cashOffersHolder = {},
				passesHolder = {},
				cashLabel = { Text = "" },
				statusLabel = { Text = "" },
				runAsync = function(callback)
					callback()
				end,
				wait = function() end,
			})

			menu:setOpen("Shop")
			local cards = activeCards(mountedCards)
			expect(#cards).to.equal(2)
			expect(cards[1].props.data.actionText).to.equal("R$ 149")
			expect(cards[2].props.data.actionText).to.equal("R$ 49")
			cards[1].props.activated(cards[1].props.data.id)
			cards[2].props.activated(cards[2].props.data.id)
			expect(#prompts).to.equal(2)
			expect(prompts[1].kind).to.equal("GamePass")
			expect(prompts[1].id).to.equal(101)
			expect(prompts[2].kind).to.equal("Product")
			expect(prompts[2].id).to.equal(202)
			expect(listeners.StorePurchaseGranted).to.be.ok()
		end)
	end)
end
