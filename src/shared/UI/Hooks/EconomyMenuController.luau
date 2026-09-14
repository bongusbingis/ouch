-- Description: The shared hook driving the shop and inventory menus: builds the view models from config and live profile data, and owns purchase, crate-open, and reveal interactions.

--!strict

local formatNumber = require(script.Parent.Parent.Models.NumberText)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CandyMotion = require(script.Parent.Parent.Motion)

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ClientRequest = require(Shared:WaitForChild("Game"):WaitForChild("Data"):WaitForChild("ClientRequest"))
local Economy = Shared:WaitForChild("Game"):WaitForChild("Economy")
local CrateBatch = require(Economy:WaitForChild("CrateBatch"))
local CrateOdds = require(Economy:WaitForChild("CrateOdds"))
local EconomyStore = require(Economy:WaitForChild("EconomyStore"))
local FeaturedRotation = require(Economy:WaitForChild("FeaturedRotation"))
local InventoryModel = require(Economy:WaitForChild("InventoryModel"))
local ShopViewModel = require(Economy:WaitForChild("ShopViewModel"))
local SeasonStore = require(Shared:WaitForChild("Game"):WaitForChild("Progression"):WaitForChild("SeasonStore"))
local CosmeticPreviewClient =
	require(Shared:WaitForChild("UI"):WaitForChild("Services"):WaitForChild("CosmeticPreviewClient"))
local UI = Shared:WaitForChild("UI")
local NotificationContext = require(UI:WaitForChild("Contexts"):WaitForChild("NotificationContext"))
local useExternalStore = require(UI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local UIAnalytics = require(UI:WaitForChild("Services"):WaitForChild("UIAnalytics"))
local Config = ReplicatedStorage:WaitForChild("Config")
local Bundles = require(Config:WaitForChild("Economy"):WaitForChild("Bundles"))
local Cosmetics = require(Config:WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Inventory = require(Config:WaitForChild("Cosmetics"):WaitForChild("Inventory"))
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
	network_error = "Backpack couldn’t load. Try again.",
}

local SHOP_ERRORS = {
	grant_failed = "Some rewards are still being delivered. Claim again to collect anything remaining.",
	profile_not_ready = "Your data is still loading.",
	no_active_season = "This season has ended. Please refresh the shop.",
	busy = "That purchase is already being processed.",
	season_ended = "This season has ended. Please refresh the shop.",
	network_error = "Shop couldn’t load. Try again.",
	marketplace_error = "Roblox purchases are unavailable right now.",
	no_profile = "Your data is still loading.",
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
	crate_price_changed = "That crate price changed. Please check the refreshed price before opening.",
	crate_recovery_unavailable = "Crate purchases are unavailable on this server. Please rejoin to refresh the shop.",
	crate_request_mismatch = "That crate request could not be verified. Please refresh the shop.",
	crate_request_stale = "That crate request has already finished. Please check your Backpack.",
	crate_request_gap = "The shop needs to refresh before another crate can be opened.",
	rate_limited = "You are opening crates too quickly. Try again in a moment.",
	purchase_failed = "The purchase could not be completed.",
	request_timed_out = "Still waiting on your purchase. Check your Backpack before trying again.",
}

export type Options = {
	ShopClient: any,
	EconomyData: any?,
	ShopRefreshEnabled: boolean?,
	OnViewInventory: (() -> ())?,
}

export type Controller = {
	economyData: any?,
	previewItem: any?,
	previewEffect: (any) -> (),
	closePreview: () -> (),
	inspectInventory: (InventoryModel.Entry) -> (),
	inspectReward: (any) -> (),
	inspectingReward: boolean,
	viewInventory: (string?) -> (),
	viewSeason: () -> (),
	canViewSeason: boolean,
	equipPreview: (any) -> (),
	busySlots: { [string]: boolean },
	seasonState: any?,
	claimSeason: () -> (),
	claimPending: boolean,
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
	detailsBackRef: { current: (() -> boolean)? },
	CloseTopLayer: () -> boolean,
	CloseAll: () -> (),
}

function EconomyMenuController.use(options: Options): Controller
	local shopClient = options.ShopClient
	assert(shopClient ~= nil, "[EconomyMenuController] ShopClient is required")
	local notifications = NotificationContext.useNotification()
	local inventoryTab, setInventoryTab = React.useState("OUTFITS")
	local selectedShopCardId, setSelectedShopCardId = React.useState(nil :: string?)
	local selectedInventoryEntry, setSelectedInventoryEntry = React.useState(nil :: InventoryModel.Entry?)
	local selectedRewardItemId, setSelectedRewardItemId = React.useState(nil :: string?)
	local previewItem, setPreviewItem = React.useState(nil)
	local busySlots = React.useRef({} :: { [string]: boolean })
	local busySnapshot, setBusySnapshot = React.useState({} :: { [string]: boolean })
	local claimPending, setClaimPending = React.useState(false)
	local claimBusy = React.useRef(false)
	local detailsBackRef = React.useRef(nil)
	local seasonState = useExternalStore(SeasonStore.snapshot, SeasonStore.subscribe)
	local mounted = React.useRef(false)
	local lifecycleGeneration = React.useRef(0)
	local storeData = useExternalStore(EconomyStore.snapshot, EconomyStore.subscribe)
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
	local selectedShopCard = if selectedRewardItemId
		then ShopViewModel.reward(
			selectedRewardItemId,
			Cosmetics,
			if economyData then economyData.Cosmetics.Owned else {}
		)
		elseif selectedInventoryEntry then ShopViewModel.inventory(selectedInventoryEntry)
		else if selectedShopCardId then shopModel.byId[selectedShopCardId] else nil
	local seasonCard = nil
	for _, section in shopModel.sections do
		for _, card in section.cards do
			if
				card.kind == "SeasonPass" and (seasonState == nil or card.definition.SeasonId == seasonState.seasonId)
			then
				seasonCard = card
				break
			end
		end
	end
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
			unitPrice = unit,
			total = total,
			affordable = balance >= total,
			label = if crateReveal.count > 1
				then `AGAIN {crateReveal.count}x  {formatNumber(total)}`
				else `AGAIN  {formatNumber(total)}`,
		}
	end, { crateReveal, economyData })
	local previewBlocked = notifications.request ~= nil
		or (crateReveal ~= nil and selectedRewardItemId == nil)
		or shopSnapshot.grant ~= nil
	local closePreview = React.useCallback(function()
		CosmeticPreviewClient.close()
		setPreviewItem(nil)
	end, {})

	React.useEffect(function()
		if previewBlocked and previewItem ~= nil then
			closePreview()
		end
	end, { previewBlocked, previewItem, closePreview })

	React.useEffect(function()
		setSelectedRewardItemId(nil)
		if shopSnapshot.reveal ~= nil then
			closePreview()
		end
	end, { shopSnapshot.reveal, closePreview })

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
		closePreview()
		local passKey = if grant.passId then GamePasses.KeyById[grant.passId] else nil
		local pass = if passKey then GamePasses.Catalog[passKey] else nil
		local description = if pass and pass.PurchaseMessage
			then pass.PurchaseMessage
			else if grant.kind == "Bonks"
				then `YOU RECEIVED {grant.amount} BONKS.`
				else "NEW GEAR! CHECK YOUR BACKPACK."
		notifications.notify({
			title = "PURCHASE COMPLETE",
			description = description,
			buttonText = "AWESOME!",
		})
		shopClient.clearGrant()
	end, { shopSnapshot.grant, shopClient, notifications.notify, closePreview })

	React.useEffect(function()
		if not shopSnapshot.purchaseNotice then
			return
		end
		notifications.notify({
			title = "PURCHASE PROCESSING",
			description = "Roblox is still processing your purchase. You can keep playing. Your items will arrive when it completes.",
			buttonText = "OK",
		})
		shopClient.clearPurchaseNotice()
	end, { shopSnapshot.purchaseNotice, shopClient, notifications.notify })

	local shopError = React.useCallback(function(reason: string?)
		closePreview()
		if reason == "crate_recovery_required" then
			local generation = lifecycleGeneration.current
			local function showRecovery()
				notifications.confirm({
					title = "CHECK YOUR CRATE",
					description = "Your crate result has not arrived yet. Check the existing purchase without buying another crate, or keep playing and check later.",
					confirmText = "CHECK MY CRATE",
					cancelText = "KEEP PLAYING",
				}, function(check)
					if not check or not mounted.current or generation ~= lifecycleGeneration.current then
						return
					end
					local ok, retryReason = shopClient.retryCrateOpen()
					if ok or not mounted.current or generation ~= lifecycleGeneration.current then
						return
					end
					if retryReason == "crate_recovery_required" then
						showRecovery()
					else
						notifications.notify({
							title = "SHOP",
							description = SHOP_ERRORS[retryReason] or "Your crate is still being checked.",
							buttonText = "OK",
						})
					end
				end)
			end
			showRecovery()
			return
		end
		UIAnalytics.report("PurchaseFailed", { reason = reason or "purchase_failed" })
		notifications.notify({
			title = "SHOP",
			description = SHOP_ERRORS[reason or "purchase_failed"] or "THE PURCHASE COULD NOT BE COMPLETED.",
			buttonText = "OK",
		})
	end, { notifications.notify, notifications.confirm, closePreview, shopClient })

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
		UIAnalytics.report("OfferSelected", { offerKey = card.id, offerKind = card.kind })
		setSelectedInventoryEntry(nil)
		setSelectedRewardItemId(nil)
		setSelectedShopCardId(card.id)
	end, {})

	local inspectInventory = React.useCallback(function(entry: InventoryModel.Entry)
		setSelectedRewardItemId(nil)
		setSelectedShopCardId(nil)
		setSelectedInventoryEntry(entry)
	end, {})

	local inspectReward = React.useCallback(function(preview)
		if preview == nil or Cosmetics.Items[preview.itemId] == nil then
			return
		end
		setSelectedRewardItemId(preview.itemId)
	end, {})

	local viewInventory = React.useCallback(function(category: string?)
		closePreview()
		setSelectedInventoryEntry(nil)
		setSelectedRewardItemId(nil)
		setSelectedShopCardId(nil)
		shopClient.clearReveal()
		for _, tab in Inventory.Tabs do
			for _, section in tab.Sections do
				if section.Category == category then
					setInventoryTab(tab.Id)
				end
			end
		end
		if options.OnViewInventory then
			options.OnViewInventory()
		end
	end, { closePreview, shopClient, options.OnViewInventory })

	local viewSeason = React.useCallback(function()
		if seasonCard == nil then
			return
		end
		closePreview()
		shopClient.clearReveal()
		setSelectedInventoryEntry(nil)
		setSelectedRewardItemId(nil)
		setSelectedShopCardId(seasonCard.id)
	end, { closePreview, shopClient, seasonCard })

	local previewEffect = React.useCallback(function(entry)
		if previewBlocked or not CosmeticPreviewClient.canPreview(entry.itemId, entry.category) then
			return
		end
		setPreviewItem({ itemId = entry.itemId, category = entry.category })
	end, { previewBlocked })

	local equip = React.useCallback(function(entry: InventoryModel.Entry)
		if not mounted.current or economyData == nil or busySlots.current[entry.category] then
			return
		end
		if entry.isDefault and InventoryModel.isEquipped(entry, economyData.Cosmetics.Equipped) then
			return
		end
		busySlots.current[entry.category] = true
		setBusySnapshot(table.clone(busySlots.current))
		local nextItemId = InventoryModel.nextEquip(entry, economyData.Cosmetics.Equipped)
		local generation = lifecycleGeneration.current
		task.spawn(function()
			local callOk, accepted, reason = ClientRequest(Network.call, "EquipCosmetic", entry.category, nextItemId)
			busySlots.current[entry.category] = nil
			if not mounted.current or lifecycleGeneration.current ~= generation then
				return
			end
			setBusySnapshot(table.clone(busySlots.current))
			if callOk and accepted then
				CandyMotion.celebrate(entry.category, nextItemId)
			end
			if not callOk or not accepted then
				local errorCode = if callOk then reason else "network_error"
				closePreview()
				notifications.notify({
					title = "INVENTORY",
					description = EQUIP_ERRORS[errorCode]
						or `Unable to equip that item: {tostring(errorCode or "unknown error")}`,
					buttonText = "OK",
				})
			end
		end)
	end, { economyData, notifications.notify, closePreview })

	local equipPreview = React.useCallback(function(preview)
		if economyData == nil then
			return
		end
		for _, entry in InventoryModel.entries(Cosmetics, economyData.Cosmetics.Owned, preview.category) do
			if entry.itemId == preview.itemId then
				equip(entry)
				return
			end
		end
	end, { economyData, equip })

	local claimSeason = React.useCallback(function()
		if claimBusy.current then
			return
		end
		claimBusy.current = true
		setClaimPending(true)
		local generation = lifecycleGeneration.current
		task.spawn(function()
			local result, reason = SeasonStore.claimAll()
			claimBusy.current = false
			if not mounted.current or lifecycleGeneration.current ~= generation then
				return
			end
			setClaimPending(false)
			if result == nil then
				shopError(reason)
			end
		end)
	end, { shopError })

	local refreshShop = React.useCallback(function()
		if mounted.current then
			task.spawn(shopClient.refresh)
		end
	end, { shopClient })

	local closeSelectedShopCard = React.useCallback(function()
		if selectedRewardItemId ~= nil then
			setSelectedRewardItemId(nil)
			return
		end
		setSelectedRewardItemId(nil)
		setSelectedInventoryEntry(nil)
		setSelectedShopCardId(nil)
	end, { selectedRewardItemId })

	local closeReveal = React.useCallback(function()
		setSelectedRewardItemId(nil)
		shopClient.clearReveal()
	end, { shopClient })

	local openAgain = React.useCallback(function()
		local replay = crateReplay
		if replay == nil or not replay.affordable then
			return
		end
		shopClient.clearReveal()
		runShopAction(function()
			return shopClient.openCrate(`Crate:{replay.crateId}`, replay.crateId, replay.count, replay.unitPrice)
		end, nil)
	end, { crateReplay, runShopAction, shopClient })

	local purchaseSelectedBonks = React.useCallback(function(count: number?)
		local card = selectedShopCard
		if card == nil or card.status ~= "Active" or card.pending or card.bonksPrice == nil then
			return
		end
		runShopAction(function()
			if card.kind == "Crate" and card.crateId then
				return shopClient.openCrate(card.id, card.crateId, count, card.bonksPrice)
			end
			return shopClient.purchaseCosmetic(card.id, card.itemId)
		end, nil)
	end, { selectedShopCard, runShopAction, shopClient, notifications.notify })

	local purchaseSelectedRobux = React.useCallback(function()
		local card = selectedShopCard
		if card == nil or card.status ~= "Active" or card.pending or (card.productId == nil and card.passId == nil) then
			return
		end
		UIAnalytics.report("PromptOpened", { offerKey = card.id, offerKind = card.kind })
		runShopAction(function()
			if card.passId then
				return shopClient.promptGamePass(card.id, card.passId)
			end
			return shopClient.promptProduct(card.id, card.productId)
		end, nil)
	end, { selectedShopCard, runShopAction, shopClient })

	local closeTopLayer = React.useCallback(function(): boolean
		if previewItem ~= nil then
			closePreview()
			return true
		elseif notifications.request ~= nil then
			notifications.close(false)
			return true
		elseif selectedRewardItemId ~= nil then
			setSelectedRewardItemId(nil)
			return true
		elseif crateReveal ~= nil then
			shopClient.clearReveal()
			return true
		elseif selectedShopCardId ~= nil or selectedInventoryEntry ~= nil then
			if detailsBackRef.current and detailsBackRef.current() then
				return true
			end
			setSelectedShopCardId(nil)
			setSelectedInventoryEntry(nil)
			return true
		end
		return false
	end, {
		previewItem,
		closePreview,
		crateReveal,
		selectedShopCardId,
		selectedInventoryEntry,
		selectedRewardItemId,
		shopClient,
		notifications.request,
		notifications.close,
	})

	local closeAll = React.useCallback(function()
		closePreview()
		setSelectedInventoryEntry(nil)
		setSelectedRewardItemId(nil)
		shopClient.clearReveal()
		setSelectedShopCardId(nil)
		if notifications.request ~= nil then
			notifications.close(false)
		end
	end, { closePreview, shopClient, notifications.request, notifications.close })

	return {
		economyData = economyData,
		previewItem = if previewBlocked then nil else previewItem,
		previewEffect = previewEffect,
		closePreview = closePreview,
		inspectInventory = inspectInventory,
		inspectReward = inspectReward,
		inspectingReward = selectedRewardItemId ~= nil,
		viewInventory = viewInventory,
		viewSeason = viewSeason,
		canViewSeason = seasonCard ~= nil,
		equipPreview = equipPreview,
		busySlots = busySnapshot,
		seasonState = seasonState,
		claimSeason = claimSeason,
		claimPending = claimPending,
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
		detailsBackRef = detailsBackRef,
		CloseTopLayer = closeTopLayer,
		CloseAll = closeAll,
	}
end

return EconomyMenuController
