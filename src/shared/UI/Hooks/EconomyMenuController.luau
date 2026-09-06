-- Name: EconomyMenuController.luau
-- Author: Jack C.
-- Description: The shared hook driving the shop and inventory menus: builds the view models from config and live profile data, and owns purchase, crate-open, and reveal interactions.
-- Created: 2026-08-24

--!strict

local formatNumber = require(script.Parent.Parent.Models.NumberText)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ClientRequest = require(Shared.Game.Data.ClientRequest)
local Economy = Shared:WaitForChild("Game"):WaitForChild("Economy")
local CrateBatch = require(Economy:WaitForChild("CrateBatch"))
local CrateOdds = require(Economy:WaitForChild("CrateOdds"))
local EconomyStore = require(Economy:WaitForChild("EconomyStore"))
local FeaturedRotation = require(Economy:WaitForChild("FeaturedRotation"))
local InventoryModel = require(Economy:WaitForChild("InventoryModel"))
local ShopViewModel = require(Economy:WaitForChild("ShopViewModel"))
local UI = Shared:WaitForChild("UI")
local NotificationContext = require(UI:WaitForChild("Contexts"):WaitForChild("NotificationContext"))
local useExternalStore = require(UI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local UIAnalytics = require(UI:WaitForChild("Services"):WaitForChild("UIAnalytics"))
local Config = ReplicatedStorage:WaitForChild("Config")
local Bundles = require(Config:WaitForChild("Economy"):WaitForChild("Bundles"))
local Cosmetics = require(Config:WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Crates = require(Config:WaitForChild("Economy"):WaitForChild("Crates"))
local GamePasses = require(Config:WaitForChild("Economy"):WaitForChild("GamePasses"))
local Products = require(Config:WaitForChild("Economy"):WaitForChild("Products"))
local Seasons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Seasons"))
local Shop = require(Config:WaitForChild("Economy"):WaitForChild("Shop"))

local EconomyMenuController = {}

local EQUIP_ERRORS = {
	rate_limited = "Please wait before changing another item.",
	no_profile = "Your inventory is still loading.",
	not_owned = "That item is not owned.",
	wrong_slot = "That item cannot be equipped in this slot.",
	invalid_slot = "That inventory slot is invalid.",
	network_error = "The inventory service is unavailable.",
}

local SHOP_ERRORS = {
	busy = "That purchase is already being processed.",
	season_ended = "This season has ended. Please refresh the shop.",
	network_error = "The shop service is unavailable. Please try again.",
	marketplace_error = "Roblox purchases are unavailable right now.",
	no_profile = "Your profile is still loading.",
	insufficient_bonks = "You do not have enough Bonks.",
	already_owned = "You already own that item.",
	not_offered = "That offer has expired.",
	not_purchasable = "That item cannot be purchased.",
	paid_random_restricted = "Crates are unavailable for this account.",
	policy_lookup_failed = "Crates are temporarily unavailable.",
	policy_unavailable = "Crates are temporarily unavailable.",
	invalid_crate = "That crate is unavailable.",
	crate_roll_failed = "The crate could not be opened. You were not charged.",
	invalid_quantity = "That open quantity is unavailable.",
	rate_limited = "You are opening crates too quickly. Try again in a moment.",
	purchase_failed = "The purchase could not be completed.",
}

export type Options = {
	ShopClient: any,
	EconomyData: any?,
	ShopRefreshEnabled: boolean?,
}

export type Controller = {
	economyData: any?,
	inventoryTab: string,
	setInventoryTab: (string) -> (),
	shopModel: ShopViewModel.Model,
	selectedShopCard: ShopViewModel.Card?,
	selectedShopCardId: string?,
	crateReveal: any?,
	crateReplay: any?,
	activateShopCard: (ShopViewModel.Card) -> (),
	equip: (InventoryModel.Entry) -> (),
	refreshShop: () -> (),
	closeSelectedShopCard: () -> (),
	closeReveal: () -> (),
	openAgain: () -> (),
	purchaseSelectedBonks: (number?) -> (),
	purchaseSelectedRobux: () -> (),
	CloseTopLayer: () -> boolean,
	CloseAll: () -> (),
}

function EconomyMenuController.use(options: Options): Controller
	local shopClient = options.ShopClient
	assert(shopClient ~= nil, "[EconomyMenuController] ShopClient is required")
	local notifications = NotificationContext.useNotification()
	local inventoryTab, setInventoryTab = React.useState("OUTFITS")
	local selectedShopCardId, setSelectedShopCardId = React.useState(nil :: string?)
	local busySlots = React.useRef({} :: { [string]: boolean })
	local mounted = React.useRef(false)
	local lifecycleGeneration = React.useRef(0)
	local storeData = useExternalStore(EconomyStore.snapshot, EconomyStore.onChanged)
	local economyData = options.EconomyData or storeData
	local shopSnapshot = useExternalStore(shopClient.snapshot, shopClient.subscribe)
	local shopModel = React.useMemo(function()
		return ShopViewModel.build({
			status = shopSnapshot.status,
			shopState = shopSnapshot.shopState,
			economyData = economyData,
			metadata = shopSnapshot.metadata,
			ownedPasses = shopSnapshot.ownedPasses,
			pending = shopSnapshot.pending,
			now = os.time(),
			cosmetics = Cosmetics,
			crates = Crates,
			bundles = Bundles,
			gamePasses = GamePasses,
			products = Products.Catalog,
			seasons = Seasons.Definitions,
			shopConfig = Shop,
			featuredRotation = FeaturedRotation,
			crateOdds = CrateOdds,
			crateBatch = CrateBatch,
		})
	end, { economyData, shopSnapshot })
	local selectedShopCard = if selectedShopCardId then shopModel.byId[selectedShopCardId] else nil
	local crateReveal = React.useMemo(function()
		if shopSnapshot.reveal == nil then
			return nil
		end
		return ShopViewModel.reveal(shopSnapshot.reveal, Cosmetics)
	end, { shopSnapshot.reveal })
	-- What an "open again" from the reveal would repeat: the same crate at the
	-- same quantity, priced and gated live so a player who can no longer afford
	-- it sees a disabled button instead of a failed purchase.
	local crateReplay = React.useMemo(function()
		if crateReveal == nil or crateReveal.crateId == nil then
			return nil
		end
		local crate = Crates[crateReveal.crateId]
		if crate == nil or crate.CatalogStatus ~= "Active" or crate.BonksPrice == nil then
			return nil
		end
		local unit = FeaturedRotation.priceFor(Shop.Featured, crateReveal.crateId, crate.BonksPrice, os.time())
		local total = CrateBatch.totalPrice(unit, crateReveal.count)
		local balance = if economyData then economyData.Bonks else 0
		return {
			crateId = crateReveal.crateId,
			count = crateReveal.count,
			total = total,
			affordable = balance >= total,
			label = if crateReveal.count > 1
				then `AGAIN {crateReveal.count}x  {formatNumber(total)}`
				else `AGAIN  {formatNumber(total)}`,
		}
	end, { crateReveal, economyData })

	React.useEffect(function()
		mounted.current = true
		lifecycleGeneration.current += 1
		local generation = lifecycleGeneration.current
		return function()
			if lifecycleGeneration.current == generation then
				lifecycleGeneration.current += 1
			end
			mounted.current = false
		end
	end, {})

	React.useEffect(function()
		if options.ShopRefreshEnabled ~= false and economyData ~= nil and shopSnapshot.status == "Idle" then
			task.spawn(shopClient.refresh)
		end
	end, { options.ShopRefreshEnabled, economyData, shopSnapshot.status, shopClient })

	React.useEffect(function()
		local grant = shopSnapshot.grant
		if grant == nil then
			return
		end
		local passKey = if grant.passId then GamePasses.KeyById[grant.passId] else nil
		local pass = if passKey then GamePasses.Catalog[passKey] else nil
		local description = if pass and pass.PurchaseMessage
			then pass.PurchaseMessage
			else if grant.kind == "Bonks"
				then `YOU RECEIVED {grant.amount} BONKS.`
				else "YOUR PURCHASE HAS BEEN ADDED TO YOUR ACCOUNT."
		notifications.notify({
			title = "PURCHASE COMPLETE",
			description = description,
			buttonText = "AWESOME!",
		})
		shopClient.clearGrant()
	end, { shopSnapshot.grant, shopClient, notifications.notify })

	local shopError = React.useCallback(function(reason: string?)
		UIAnalytics.report("PurchaseFailed", { reason = reason or "purchase_failed" })
		notifications.notify({
			title = "SHOP",
			description = SHOP_ERRORS[reason or "purchase_failed"] or "THE PURCHASE COULD NOT BE COMPLETED.",
			buttonText = "OK",
		})
	end, { notifications.notify })

	local runShopAction = React.useCallback(function(action, onSuccess)
		if not mounted.current then
			return
		end
		local generation = lifecycleGeneration.current
		task.spawn(function()
			local ran, ok, reason = pcall(action)
			if not ran then
				ok, reason = false, "network_error"
			end
			if not mounted.current or lifecycleGeneration.current ~= generation then
				return
			end
			if not ok then
				shopError(reason)
			elseif onSuccess then
				onSuccess()
			end
		end)
	end, { shopError })

	local activateShopCard = React.useCallback(function(card: ShopViewModel.Card)
		if card.status ~= "Active" or card.owned or card.pending then
			return
		end
		UIAnalytics.report("OfferSelected", { offerKey = card.id, offerKind = card.kind })
		if card.kind == "Crate" or card.kind == "GamePass" or (card.kind == "Cosmetic" and card.productId ~= nil) then
			setSelectedShopCardId(card.id)
		elseif card.kind == "Cosmetic" and card.itemId then
			local itemId = card.itemId
			notifications.confirm({
				title = "BUY ITEM?",
				description = `BUY {string.upper(card.displayName)} FOR {card.bonksPrice} BONKS?`,
				confirmText = "BUY",
				cancelText = "CANCEL",
			}, function(confirmed)
				if confirmed then
					runShopAction(function()
						return shopClient.purchaseCosmetic(card.id, itemId)
					end, function()
						notifications.notify({
							title = "PURCHASE COMPLETE",
							description = `{string.upper(card.displayName)} IS NOW IN YOUR INVENTORY.`,
							buttonText = "AWESOME!",
						})
					end)
				end
			end)
		elseif card.passId then
			UIAnalytics.report("PromptOpened", { offerKey = card.id, offerKind = card.kind })
			runShopAction(function()
				return shopClient.promptGamePass(card.id, card.passId)
			end, nil)
		elseif card.productId then
			UIAnalytics.report("PromptOpened", { offerKey = card.id, offerKind = card.kind })
			runShopAction(function()
				return shopClient.promptProduct(card.id, card.productId)
			end, nil)
		end
	end, { notifications.confirm, notifications.notify, runShopAction, shopClient })

	local equip = React.useCallback(function(entry: InventoryModel.Entry)
		if not mounted.current or economyData == nil or busySlots.current[entry.category] then
			return
		end
		if entry.isDefault and InventoryModel.isEquipped(entry, economyData.Cosmetics.Equipped) then
			return
		end
		busySlots.current[entry.category] = true
		local nextItemId = InventoryModel.nextEquip(entry, economyData.Cosmetics.Equipped)
		local generation = lifecycleGeneration.current
		task.spawn(function()
			local callOk, accepted, reason = ClientRequest(Network.call, "EquipCosmetic", entry.category, nextItemId)
			busySlots.current[entry.category] = nil
			if not mounted.current or lifecycleGeneration.current ~= generation then
				return
			end
			if not callOk or not accepted then
				local errorCode = if callOk then reason else "network_error"
				notifications.notify({
					title = "INVENTORY",
					description = EQUIP_ERRORS[errorCode]
						or `Unable to equip that item: {tostring(errorCode or "unknown error")}`,
					buttonText = "OK",
				})
			end
		end)
	end, { economyData, notifications.notify })

	local refreshShop = React.useCallback(function()
		if mounted.current then
			task.spawn(shopClient.refresh)
		end
	end, { shopClient })

	local closeSelectedShopCard = React.useCallback(function()
		setSelectedShopCardId(nil)
	end, {})

	local closeReveal = React.useCallback(function()
		shopClient.clearReveal()
	end, { shopClient })

	local openAgain = React.useCallback(function()
		local replay = crateReplay
		if replay == nil or not replay.affordable then
			return
		end
		shopClient.clearReveal()
		runShopAction(function()
			return shopClient.openCrate(`Crate:{replay.crateId}`, replay.crateId, replay.count)
		end, nil)
	end, { crateReplay, runShopAction, shopClient })

	local purchaseSelectedBonks = React.useCallback(function(count: number?)
		local card = selectedShopCard
		if card == nil then
			return
		end
		setSelectedShopCardId(nil)
		runShopAction(function()
			if card.kind == "Crate" and card.crateId then
				return shopClient.openCrate(card.id, card.crateId, count)
			end
			return shopClient.purchaseCosmetic(card.id, card.itemId)
		end, function()
			if card.kind == "Cosmetic" then
				notifications.notify({
					title = "PURCHASE COMPLETE",
					description = `{string.upper(card.displayName)} IS NOW IN YOUR INVENTORY.`,
					buttonText = "AWESOME!",
				})
			end
		end)
	end, { selectedShopCard, runShopAction, shopClient, notifications.notify })

	local purchaseSelectedRobux = React.useCallback(function()
		local card = selectedShopCard
		if card == nil or (card.productId == nil and card.passId == nil) then
			return
		end
		setSelectedShopCardId(nil)
		UIAnalytics.report("PromptOpened", { offerKey = card.id, offerKind = card.kind })
		runShopAction(function()
			if card.passId then
				return shopClient.promptGamePass(card.id, card.passId)
			end
			return shopClient.promptProduct(card.id, card.productId)
		end, nil)
	end, { selectedShopCard, runShopAction, shopClient })

	local closeTopLayer = React.useCallback(function(): boolean
		if notifications.request ~= nil then
			notifications.close(false)
			return true
		elseif crateReveal ~= nil then
			shopClient.clearReveal()
			return true
		elseif selectedShopCardId ~= nil then
			setSelectedShopCardId(nil)
			return true
		end
		return false
	end, { crateReveal, selectedShopCardId, shopClient, notifications.request, notifications.close })

	local closeAll = React.useCallback(function()
		shopClient.clearReveal()
		setSelectedShopCardId(nil)
		if notifications.request ~= nil then
			notifications.close(false)
		end
	end, { shopClient, notifications.request, notifications.close })

	return {
		economyData = economyData,
		inventoryTab = inventoryTab,
		setInventoryTab = setInventoryTab,
		shopModel = shopModel,
		selectedShopCard = selectedShopCard,
		selectedShopCardId = selectedShopCardId,
		crateReveal = crateReveal,
		crateReplay = crateReplay,
		openAgain = openAgain,
		activateShopCard = activateShopCard,
		equip = equip,
		refreshShop = refreshShop,
		closeSelectedShopCard = closeSelectedShopCard,
		closeReveal = closeReveal,
		purchaseSelectedBonks = purchaseSelectedBonks,
		purchaseSelectedRobux = purchaseSelectedRobux,
		CloseTopLayer = closeTopLayer,
		CloseAll = closeAll,
	}
end

return EconomyMenuController
