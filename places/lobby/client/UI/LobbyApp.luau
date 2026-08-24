--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local Components = UI:WaitForChild("Components")
local Network = require(Shared:WaitForChild("Network"))
local EconomyStore = require(Shared:WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("EconomyStore"))
local InventoryModel = require(Shared:WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("InventoryModel"))
local Economy = Shared:WaitForChild("Game"):WaitForChild("Economy")
local CrateOdds = require(Economy:WaitForChild("CrateOdds"))
local FeaturedRotation = require(Economy:WaitForChild("FeaturedRotation"))
local ShopViewModel = require(Economy:WaitForChild("ShopViewModel"))
local Config = ReplicatedStorage:WaitForChild("Config")
local Loading = require(Config:WaitForChild("Loading"))
local Bundles = require(Config:WaitForChild("Bundles"))
local Cosmetics = require(Config:WaitForChild("Cosmetics"))
local Crates = require(Config:WaitForChild("Crates"))
local GamePasses = require(Config:WaitForChild("GamePasses"))
local Products = require(Config:WaitForChild("Products"))
local Shop = require(Config:WaitForChild("Shop"))
local LobbyViewModel = require(UI:WaitForChild("Models"):WaitForChild("LobbyViewModel"))
local Motion = require(UI:WaitForChild("Motion"))
local useExternalStore = require(UI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local useReducedMotion = require(UI:WaitForChild("Hooks"):WaitForChild("useReducedMotion"))
local NotificationContext = require(UI:WaitForChild("Contexts"):WaitForChild("NotificationContext"))
local InventoryPage = require(Components:WaitForChild("InventoryPage"))
local JoinCodeModal = require(Components:WaitForChild("JoinCodeModal"))
local LoadingScreen = require(Components:WaitForChild("LoadingScreen"))
local NotificationModal = require(Components:WaitForChild("NotificationModal"))
local ShopDetailsModal = require(Components:WaitForChild("ShopDetailsModal"))
local CrateRevealModal = require(Components:WaitForChild("CrateRevealModal"))
local PageTransition = require(Components:WaitForChild("PageTransition"))
local PartyCode = require(Components:WaitForChild("PartyCode"))
local ShopPage = require(Components:WaitForChild("ShopPage"))
local AnalyticsReporter =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Lobby"):WaitForChild("AnalyticsReporter"))
local SplashPage = require(Components:WaitForChild("SplashPage"))
local TopBar = require(Components:WaitForChild("TopBar"))
local GameVersion = require(Components:WaitForChild("GameVersion"))

local PartyCharacterRenderer =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Lobby"):WaitForChild("PartyCharacterRenderer"))

local c = React.createElement

local PAGE_POSITIONS = {
	SplashScreen = {
		onscreen = UDim2.fromScale(0, 0),
		offscreen = UDim2.fromScale(0, 1),
	},
	Inventory = {
		onscreen = UDim2.fromScale(0.0211629, 0.14282),
		offscreen = UDim2.fromScale(-1.5, 0.14282),
	},
	Shop = {
		onscreen = UDim2.fromScale(-0.005, 0.127),
		offscreen = UDim2.fromScale(-1.5, 0.127),
	},
}

local PAGE_BACKGROUND_COLORS = {
	SplashScreen = Color3.fromRGB(102, 232, 255),
	Inventory = Color3.fromRGB(232, 225, 7),
	Shop = Color3.fromRGB(142, 31, 232),
}

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
	network_error = "The shop service is unavailable. Please try again.",
	marketplace_error = "Roblox purchases are unavailable right now.",
	no_profile = "Your profile is still loading.",
	insufficient_bonks = "You do not have enough Bonks.",
	already_owned = "You already own that item.",
	not_offered = "That offer has expired.",
	not_purchasable = "That item cannot be purchased.",
	paid_random_restricted = "Crates are unavailable for this account.",
	policy_lookup_failed = "Crates are temporarily unavailable.",
	invalid_crate = "That crate is unavailable.",
	crate_roll_failed = "The crate could not be opened. You were not charged.",
	purchase_failed = "The purchase could not be completed.",
}

local function useParty(client, notifications)
	local _, forceUpdate = React.useReducer(function(revision: number, _action: any)
		return revision + 1
	end, 0)
	React.useEffect(function()
		return client:subscribe(function(snapshot, previous, reason)
			forceUpdate(nil)
			if reason == "MemberKicked" and previous and snapshot and previous.partyId ~= snapshot.partyId then
				notifications.notify({
					title = "REMOVED FROM PARTY",
					description = "YOU WERE REMOVED FROM THE PARTY.",
					buttonText = "CONFIRM",
				})
			end
		end)
	end, { client, notifications.notify })
	return client:getSnapshot(), client:isBusy()
end

local function useLoadingTip(visible: boolean): string?
	local tip, setTip = React.useState(nil)
	React.useEffect(function()
		if not visible then
			setTip(nil)
			return
		end
		local thread = task.spawn(function()
			task.wait(Loading.TipDelaySeconds)
			local index = 1
			while true do
				setTip(Loading.Tips[index])
				index = index % #Loading.Tips + 1
				task.wait(Loading.TipIntervalSeconds)
			end
		end)
		return function()
			task.cancel(thread)
		end
	end, { visible })
	return tip
end

local function useWorldTransition(currentPage: string, enabled: boolean)
	local reducedMotion = useReducedMotion()
	local styles, api = ReactSpring.useSpring(function()
		return { Alpha = 1 }
	end)
	local startCFrame = React.useRef(CFrame.identity)
	local targetCFrame = React.useRef(CFrame.identity)
	local background = React.useRef(nil)
	local startColor = React.useRef(PAGE_BACKGROUND_COLORS.SplashScreen)
	local targetColor = React.useRef(PAGE_BACKGROUND_COLORS.SplashScreen)
	local initialized = React.useRef(false)
	local transitionRevision = React.useRef(0)

	React.useEffect(function()
		if not enabled then
			return
		end
		transitionRevision.current += 1
		local revision = transitionRevision.current
		local camera = Workspace.CurrentCamera
		assert(camera ~= nil, "[LobbyApp] Workspace.CurrentCamera is required")
		local party = Workspace:WaitForChild("Views"):WaitForChild("Party")
		local target = party:WaitForChild(`{currentPage}Camera`)
		assert(target:IsA("BasePart"), `[LobbyApp] Views.Party.{currentPage}Camera must be a BasePart`)
		local partyBackground = party:WaitForChild("Background")
		assert(partyBackground:IsA("BasePart"), "[LobbyApp] Views.Party.Background must be a BasePart")
		local pageColor = PAGE_BACKGROUND_COLORS[currentPage]
		assert(pageColor ~= nil, `[LobbyApp] No background color configured for {currentPage}`)
		background.current = partyBackground
		camera.CameraType = Enum.CameraType.Scriptable
		if not initialized.current or reducedMotion then
			initialized.current = true
			startCFrame.current = target.CFrame
			targetCFrame.current = target.CFrame
			startColor.current = pageColor
			targetColor.current = pageColor
			camera.CFrame = target.CFrame
			partyBackground.Color = pageColor
			api.start({ Alpha = 1, immediate = true })
			return function()
				if transitionRevision.current == revision then
					transitionRevision.current += 1
				end
			end
		end
		startCFrame.current = camera.CFrame
		targetCFrame.current = target.CFrame
		startColor.current = partyBackground.Color
		targetColor.current = pageColor
		api.start({ Alpha = 0, immediate = true }):andThen(function()
			if transitionRevision.current == revision then
				api.start({ Alpha = 1, config = Motion.Camera, immediate = false })
			end
		end)
		return function()
			if transitionRevision.current == revision then
				transitionRevision.current += 1
			end
		end
	end, { currentPage, reducedMotion, enabled })

	React.useEffect(function()
		if not enabled then
			return
		end
		local connection = RunService.RenderStepped:Connect(function()
			local alpha = styles.Alpha:getValue()
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = startCFrame.current:Lerp(targetCFrame.current, alpha)
			end
			local partyBackground = background.current
			if partyBackground then
				partyBackground.Color = startColor.current:Lerp(targetColor.current, alpha)
			end
		end)
		return function()
			connection:Disconnect()
			api.stop()
		end
	end, { enabled })
end

local function LobbyContent(props)
	local partyClient = props.PartyClient
	local rootRef = React.useRef(nil)
	local presented = React.useRef(false)
	local notifications = NotificationContext.useNotification()
	local currentPage, setCurrentPage = React.useState("SplashScreen")
	React.useEffect(function()
		if not presented.current and rootRef.current ~= nil and props.OnPresented then
			presented.current = true
			props.OnPresented()
		end
	end, { props.OnPresented })

	-- One report per page the player actually lands on. The server maps a Shop
	-- open onto the purchase funnel's first step and everything else onto a
	-- MenuOpened custom event.
	React.useEffect(function()
		AnalyticsReporter.menuOpened(currentPage)
	end, { currentPage })
	local inventoryTab, setInventoryTab = React.useState("OUTFITS")
	local selectedShopCardId, setSelectedShopCardId = React.useState(nil)
	local joinOpen, setJoinOpen = React.useState(false)
	local codeVisible, setCodeVisible = React.useState(false)
	local busySlots = React.useRef({})
	local devTapState = React.useRef({ lastTapAt = 0, tapCount = 0 })
	local storeData = useExternalStore(EconomyStore.snapshot, EconomyStore.onChanged)
	local economyData = props.EconomyData or storeData
	local shopClient = props.ShopClient
	assert(shopClient ~= nil, "[LobbyApp] ShopClient is required")
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
			shopConfig = Shop,
			featuredRotation = FeaturedRotation,
			crateOdds = CrateOdds,
		})
	end, { economyData, shopSnapshot })
	local selectedShopCard = if selectedShopCardId then shopModel.byId[selectedShopCardId] else nil
	local crateReveal = React.useMemo(function()
		if shopSnapshot.reveal == nil then
			return nil
		end
		return ShopViewModel.reveal(shopSnapshot.reveal, Cosmetics)
	end, { shopSnapshot.reveal })
	local snapshot, requestBusy = useParty(partyClient, notifications)
	local teleportStatus = partyClient:getTeleportStatus()
	local presentation = LobbyViewModel.partyPresentation(snapshot, Players.LocalPlayer.UserId, requestBusy)
	local teleportPhase = if snapshot then snapshot.phase else nil
	local loadingVisible = (teleportPhase == "Assigned" or teleportPhase == "Teleporting")
		and not (teleportStatus and teleportStatus.state == "Failed")
	local loadingTitle = if teleportPhase == "Assigned" then "MATCH FOUND" else "TRAVELING TO ARENA"
	local loadingDetail = if teleportPhase == "Assigned" then "PREPARING YOUR SERVER" else nil
	if teleportStatus and teleportStatus.state == "Retrying" then
		loadingTitle = "RECONNECTING"
		loadingDetail = `ATTEMPT {teleportStatus.attempt} OF {teleportStatus.maxAttempts}`
	elseif teleportPhase == "Teleporting" then
		loadingDetail = "THE MATCH IS READY"
	end
	local loadingTip = useLoadingTip(loadingVisible)
	local equipped = if economyData then economyData.Cosmetics.Equipped else {}
	local skinPreviewState = React.useRef({})
	skinPreviewState.current = {
		active = currentPage == "Inventory" and inventoryTab == "SKINS",
		ballItemId = equipped.BallAssets,
		hammerItemId = equipped.HammerAssets,
	}
	local characterRenderer = React.useRef(nil)
	useWorldTransition(currentPage, props.CameraEnabled ~= false)

	React.useEffect(function()
		if economyData ~= nil and shopSnapshot.status == "Idle" then
			task.spawn(shopClient.refresh)
		end
	end, { economyData, shopSnapshot.status, shopClient })

	React.useEffect(function()
		local grant = shopSnapshot.grant
		if grant == nil then
			return
		end
		local description = if grant.kind == "Bonks"
			then `YOU RECEIVED {grant.amount} BONKS.`
			else "YOUR PURCHASE HAS BEEN ADDED TO YOUR ACCOUNT."
		notifications.notify({
			title = "PURCHASE COMPLETE",
			description = description,
			buttonText = "AWESOME!",
		})
		shopClient.clearGrant()
	end, { shopSnapshot.grant, shopClient, notifications.notify })

	React.useEffect(function()
		if props.WorldPresentationEnabled == false then
			return
		end
		return partyClient:subscribeErrors(function(errorCode)
			if errorCode == "party_initialization_failed" then
				notifications.confirm({
					title = "PARTY COULD NOT LOAD",
					description = "CHECK YOUR CONNECTION AND TRY AGAIN.",
					confirmText = "RETRY",
					cancelText = "CANCEL",
				}, function(retry)
					if retry then
						partyClient:retryInitialization()
					end
				end)
				return
			end
			notifications.notify({
				title = "PARTY NOTICE",
				description = partyClient.ErrorMessages[errorCode] or "PARTY REQUEST FAILED",
				buttonText = "CONFIRM",
			})
		end)
	end, { partyClient, notifications.notify, notifications.confirm })

	React.useEffect(function()
		if props.WorldPresentationEnabled == false then
			return
		end
		local renderer = PartyCharacterRenderer.new(Players.LocalPlayer.UserId, function(targetUserId, username)
			notifications.confirm({
				title = "KICK PLAYER?",
				description = `ARE YOU SURE YOU WANT TO REMOVE {string.upper(username)} FROM YOUR PARTY?`,
				confirmText = "KICK",
				cancelText = "CANCEL",
			}, function(confirmed)
				if confirmed then
					task.spawn(partyClient.kick, partyClient, targetUserId)
				end
			end)
		end)
		characterRenderer.current = renderer
		local preview = skinPreviewState.current
		renderer:SetSkinsPreview(preview.active, preview.ballItemId, preview.hammerItemId)
		local disconnect = partyClient:subscribe(function(nextSnapshot)
			if nextSnapshot then
				renderer:Render(nextSnapshot)
			end
		end)
		return function()
			characterRenderer.current = nil
			disconnect()
			renderer:destroy()
		end
	end, { partyClient, notifications.confirm, props.WorldPresentationEnabled })

	React.useEffect(function()
		local renderer = characterRenderer.current
		if renderer then
			renderer:SetSkinsPreview(
				currentPage == "Inventory" and inventoryTab == "SKINS",
				equipped.BallAssets,
				equipped.HammerAssets
			)
		end
	end, { currentPage, inventoryTab, equipped.BallAssets, equipped.HammerAssets })

	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			local isBack = input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton2
			then
				local now = os.clock()
				local tapState = devTapState.current
				if now - tapState.lastTapAt > 1.25 then
					tapState.tapCount = 0
				end
				tapState.lastTapAt = now
				tapState.tapCount += 1
				if tapState.tapCount >= 10 then
					tapState.tapCount = 0
					print("spawning dev server for solo play")
					task.spawn(partyClient.devSoloPlay, partyClient)
				end
			end
			if not isBack then
				return
			end
			if crateReveal then
				shopClient.clearReveal()
			elseif selectedShopCardId then
				setSelectedShopCardId(nil)
			elseif notifications.request then
				notifications.close(false)
			elseif joinOpen then
				setJoinOpen(false)
			elseif not processed and currentPage ~= "SplashScreen" then
				setCurrentPage("SplashScreen")
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {
		notifications.request,
		notifications.close,
		joinOpen,
		currentPage,
		crateReveal,
		selectedShopCardId,
		shopClient,
	})

	local function shopError(reason: string?)
		AnalyticsReporter.report("PurchaseFailed", { reason = reason or "purchase_failed" })
		notifications.notify({
			title = "SHOP",
			description = SHOP_ERRORS[reason or "purchase_failed"] or "THE PURCHASE COULD NOT BE COMPLETED.",
			buttonText = "OK",
		})
	end

	local function runShopAction(action, onSuccess)
		task.spawn(function()
			local ok, reason = action()
			if not ok then
				shopError(reason)
			elseif onSuccess then
				onSuccess()
			end
		end)
	end

	local function activateShopCard(card)
		if card.status ~= "Active" or card.owned or card.pending then
			return
		end
		AnalyticsReporter.report("OfferSelected", { offerKey = card.id, offerKind = card.kind })
		if card.kind == "Crate" or (card.kind == "Cosmetic" and card.productId ~= nil) then
			setSelectedShopCardId(card.id)
		elseif card.kind == "Cosmetic" and card.itemId then
			notifications.confirm({
				title = "BUY ITEM?",
				description = `BUY {string.upper(card.displayName)} FOR {card.bonksPrice} BONKS?`,
				confirmText = "BUY",
				cancelText = "CANCEL",
			}, function(confirmed)
				if confirmed then
					runShopAction(function()
						return shopClient.purchaseCosmetic(card.id, card.itemId)
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
			AnalyticsReporter.report("PromptOpened", { offerKey = card.id, offerKind = card.kind })
			runShopAction(function()
				return shopClient.promptGamePass(card.id, card.passId)
			end)
		elseif card.productId then
			AnalyticsReporter.report("PromptOpened", { offerKey = card.id, offerKind = card.kind })
			runShopAction(function()
				return shopClient.promptProduct(card.id, card.productId)
			end)
		end
	end

	local function equip(entry)
		if economyData == nil or busySlots.current[entry.category] then
			return
		end
		if entry.isDefault and InventoryModel.isEquipped(entry, economyData.Cosmetics.Equipped) then
			return
		end
		busySlots.current[entry.category] = true
		local nextItemId = InventoryModel.nextEquip(entry, economyData.Cosmetics.Equipped)
		task.spawn(function()
			local callOk, accepted, reason = pcall(Network.call, "EquipCosmetic", entry.category, nextItemId)
			busySlots.current[entry.category] = nil
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
	end

	local views = {}
	for pageName, positions in PAGE_POSITIONS do
		views[pageName] = c(PageTransition, {
			Active = currentPage == pageName,
			Onscreen = positions.onscreen,
			Offscreen = positions.offscreen,
			Render = function(position)
				if pageName == "SplashScreen" then
					return c(SplashPage, {
						Position = position,
						PartyState = presentation.partyState,
						ShowMatchmakingActivity = presentation.showMatchmakingActivity,
						PlayText = presentation.playText,
						PlayEnabled = presentation.playEnabled,
						OnPlay = function()
							task.spawn(partyClient.toggleMatchmaking, partyClient)
						end,
						OnInvite = function()
							task.spawn(partyClient.promptInvite, partyClient)
						end,
						OnJoinCode = function()
							setJoinOpen(true)
						end,
					})
				elseif pageName == "Inventory" then
					return c(InventoryPage, {
						Data = economyData,
						Position = position,
						SelectedTab = inventoryTab,
						OnTabChanged = setInventoryTab,
						OnEquip = equip,
					})
				end
				return c(ShopPage, {
					Model = shopModel,
					Position = position,
					OnCardActivated = activateShopCard,
					OnRefresh = function()
						task.spawn(shopClient.refresh)
					end,
				})
			end,
		})
	end

	return c("Frame", {
		[React.Ref] = rootRef,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		BaseClip = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Views = c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}, views),
			HUD = c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}, {
				TopBar = c(TopBar, { CurrentPage = currentPage, OnNavigate = setCurrentPage }),
				PartyCode = c(PageTransition, {
					Active = currentPage == "SplashScreen",
					Onscreen = UDim2.fromScale(0.5, 0.115),
					Offscreen = UDim2.fromScale(0.5, -1),
					Render = function(position)
						return c(PartyCode, {
							Position = position,
							CodeText = LobbyViewModel.formatPartyCode(
								if snapshot then snapshot.joinCode else nil,
								codeVisible
							),
							CodeVisible = codeVisible,
							OnToggle = function()
								setCodeVisible(function(value)
									return not value
								end)
							end,
						})
					end,
				}),
			}),
			Modals = c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 100,
			}, {
				JoinCode = c(JoinCodeModal, {
					Open = joinOpen,
					FocusEnabled = notifications.request == nil,
					OnClose = function()
						setJoinOpen(false)
					end,
					OnSubmit = function(code)
						local response, errorCode = partyClient:joinByCode(code)
						if response and response.ok then
							return true
						end
						local message = partyClient.JoinCodeErrorMessages[errorCode]
						if message == nil then
							notifications.notify({
								title = "PARTY NOTICE",
								description = partyClient.ErrorMessages[errorCode] or "PARTY REQUEST FAILED",
								buttonText = "CONFIRM",
							})
						end
						return false, message
					end,
				}),
				Notification = c(NotificationModal, {
					Request = notifications.request,
					OnChoose = notifications.close,
				}),
				ShopDetails = c(ShopDetailsModal, {
					Card = selectedShopCard,
					OnClose = function()
						setSelectedShopCardId(nil)
					end,
					OnPurchaseBonks = function()
						local card = selectedShopCard
						if card == nil then
							return
						end
						setSelectedShopCardId(nil)
						runShopAction(function()
							if card.kind == "Crate" and card.crateId then
								return shopClient.openCrate(card.id, card.crateId)
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
					end,
					OnPurchaseRobux = function()
						local card = selectedShopCard
						if card == nil or card.productId == nil then
							return
						end
						setSelectedShopCardId(nil)
						AnalyticsReporter.report("PromptOpened", { offerKey = card.id, offerKind = card.kind })
						runShopAction(function()
							return shopClient.promptProduct(card.id, card.productId)
						end)
					end,
				}),
				CrateReveal = c(CrateRevealModal, {
					Reveal = crateReveal,
					OnClose = shopClient.clearReveal,
				}),
			}),
			GameVersion = c(GameVersion),
		}),
		Loading = c(LoadingScreen, {
			Visible = loadingVisible,
			Title = loadingTitle,
			Detail = loadingDetail,
			Tip = loadingTip,
		}),
	})
end

return function(props)
	return c(NotificationContext.Provider, nil, {
		LobbyApp = c(LobbyContent, props),
	})
end
