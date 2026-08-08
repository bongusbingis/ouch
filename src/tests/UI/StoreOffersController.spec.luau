--!nonstrict

local StarterPlayer = game:GetService("StarterPlayer")

local UI =
	StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("UI")
local StoreOffersController = require(UI:WaitForChild("StoreOffersController"))

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

local function fakeElement()
	local mounted = {}
	local element = {}
	function element.mount(parent, props)
		local handle = { parent = parent, props = props, instance = {}, destroyed = false }
		function handle:destroy()
			self.destroyed = true
		end
		function handle:setEnabled(enabled)
			self.enabled = enabled
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
	describe("StoreOffersController", function()
		beforeEach(function()
			StoreOffersController._resetForTest()
		end)

		afterEach(function()
			StoreOffersController._resetForTest()
		end)

		it("renders live regional prices and routes each offer to its platform prompt", function()
			local menu = fakeMenu()
			local cardElement, mountedCards = fakeElement()
			local buttonElement = fakeElement()
			local player = { UserId = 810001 }
			local passFinished = signal()
			local productFinished = signal()
			local prompts = {}
			local marketplace = {
				PromptGamePassPurchaseFinished = passFinished,
				PromptProductPurchaseFinished = productFinished,
				GetProductInfoAsync = function(_self, productId)
					return {
						Name = if productId == 101 then "Spark Pass" else "500 Cash",
						IconImageAssetId = productId + 1000,
						PriceInRobux = if productId == 101 then 149 else 79,
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
			local catalog = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared")
					:WaitForChild("Game")
					:WaitForChild("Economy")
					:WaitForChild("StoreCatalog")
			)
			StoreOffersController.start({
				marketplace = marketplace,
				player = player,
				menuManager = menu,
				cardElement = cardElement,
				buttonElement = buttonElement,
				gamePasses = {
					Catalog = {
						SparkPass = {
							Id = 101,
							Enabled = true,
							DisplayName = "Spark Pass",
							Description = "Permanent spark cosmetics.",
							DisplayOrder = 10,
						},
					},
				},
				products = {
					Catalog = {
						CashPack = {
							Id = 202,
							Enabled = true,
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
				cosmetics = {},
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
				offersHolder = { Visible = false },
				offerTitle = { Visible = false },
				cashActionMount = { Visible = false },
				crateHolder = {},
				shelfTitle = {},
				runAsync = function(callback)
					callback()
				end,
			})

			menu:setOpen("Shop")
			local cards = activeCards(mountedCards)
			expect(#cards).to.equal(2)
			expect(cards[1].props.data.actionText).to.equal("R$ 149")
			expect(cards[2].props.data.actionText).to.equal("R$ 79")
			cards[1].props.activated(cards[1].props.data.id)
			cards[2].props.activated(cards[2].props.data.id)
			expect(#prompts).to.equal(2)
			expect(prompts[1].kind).to.equal("GamePass")
			expect(prompts[1].id).to.equal(101)
			expect(prompts[2].kind).to.equal("Product")
			expect(prompts[2].id).to.equal(202)
		end)
	end)
end
