-- Name: LobbyApp.luau
-- Author: Jack C.
-- Description: Root React component for the lobby: the splash and party pages, join-code modal, shop and inventory menus, loading screen, and world transitions.
-- Created: 2026-08-17

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
local Config = ReplicatedStorage:WaitForChild("Config")
local Loading = require(Config:WaitForChild("Loading"))
local LobbyViewModel = require(UI:WaitForChild("Models"):WaitForChild("LobbyViewModel"))
local Motion = require(UI:WaitForChild("Motion"))
local EconomyMenuController = require(UI:WaitForChild("Hooks"):WaitForChild("EconomyMenuController"))
local useReducedMotion = require(UI:WaitForChild("Hooks"):WaitForChild("useReducedMotion"))
local NotificationContext = require(UI:WaitForChild("Contexts"):WaitForChild("NotificationContext"))
local EconomyMenuModals = require(Components:WaitForChild("EconomyMenuModals"))
local InventoryPage = require(Components:WaitForChild("InventoryPage"))
local JoinCodeModal = require(Components:WaitForChild("JoinCodeModal"))
local LoadingScreen = require(Components:WaitForChild("LoadingScreen"))
local NotificationModal = require(Components:WaitForChild("NotificationModal"))
local PageTransition = require(Components:WaitForChild("PageTransition"))
local PartyCode = require(Components:WaitForChild("PartyCode"))
local OnboardingOverlay = require(Components:WaitForChild("Onboarding"):WaitForChild("OnboardingOverlay"))
local SettingsPage = require(Components:WaitForChild("SettingsPage"))
local ShopPage = require(Components:WaitForChild("ShopPage"))
local UIAnalytics = require(UI:WaitForChild("Services"):WaitForChild("UIAnalytics"))
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
		onscreen = UDim2.fromScale(0.5, 0.56),
		offscreen = UDim2.fromScale(-1, 0.56),
	},
	Settings = {
		onscreen = UDim2.fromScale(0.0211629, 0.14282),
		offscreen = UDim2.fromScale(-1.5, 0.14282),
	},
}

local PAGE_BACKGROUND_COLORS = {
	SplashScreen = Color3.fromRGB(102, 232, 255),
	Inventory = Color3.fromRGB(232, 225, 7),
	Shop = Color3.fromRGB(142, 31, 232),
}

-- Settings has no establishing shot of its own authored in Studio yet, so it
-- borrows Inventory's camera and background color rather than requiring a new
-- Views.Party.SettingsCamera part before the page is navigable.
local WORLD_CAMERA_PAGE = { Settings = "Inventory" }

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
		local cameraPage = WORLD_CAMERA_PAGE[currentPage] or currentPage
		local target = party:WaitForChild(`{cameraPage}Camera`)
		assert(target:IsA("BasePart"), `[LobbyApp] Views.Party.{cameraPage}Camera must be a BasePart`)
		local partyBackground = party:WaitForChild("Background")
		assert(partyBackground:IsA("BasePart"), "[LobbyApp] Views.Party.Background must be a BasePart")
		local pageColor = PAGE_BACKGROUND_COLORS[cameraPage]
		assert(pageColor ~= nil, `[LobbyApp] No background color configured for {cameraPage}`)
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
			-- The loop pins CameraType to Scriptable every frame; without handing
			-- it back the camera stays frozen on the last lobby framing and the
			-- player can neither look around nor use the combat camera.
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CameraType = Enum.CameraType.Custom
			end
		end
	end, { enabled })
end

local function LobbyContent(props)
	local partyClient = props.PartyClient
	local onboardingClient = props.OnboardingClient
	local rootRef = React.useRef(nil)
	local presented = React.useRef(false)
	local notifications = NotificationContext.useNotification()
	local currentPage, setCurrentPage = React.useState("SplashScreen")

	local onboarding, setOnboarding = React.useState(function()
		return if onboardingClient then onboardingClient.getSnapshot() else nil
	end)
	React.useEffect(function()
		if onboardingClient == nil then
			return
		end
		return onboardingClient.subscribe(setOnboarding)
	end, { onboardingClient })

	-- Training owns the screen until eligibility resolves, so the normal lobby
	-- never flashes in front of a new player and then gets yanked away.
	local onboardingActive = onboarding ~= nil and onboarding.active == true
	local onboardingResolved = onboarding == nil or onboarding.resolved == true
	local lobbyVisible = onboardingResolved and not onboardingActive

	React.useEffect(function()
		if not presented.current and rootRef.current ~= nil and props.OnPresented and onboardingResolved then
			presented.current = true
			props.OnPresented()
		end
	end, { props.OnPresented, onboardingResolved })

	React.useEffect(function()
		UIAnalytics.menuOpened(currentPage)
	end, { currentPage })
	local joinOpen, setJoinOpen = React.useState(false)
	local codeVisible, setCodeVisible = React.useState(false)
	local devTapState = React.useRef({ lastTapAt = 0, tapCount = 0 })
	local economyMenu = EconomyMenuController.use({
		ShopClient = props.ShopClient,
		EconomyData = props.EconomyData,
		ShopRefreshEnabled = props.ShopRefreshEnabled,
	})
	local economyData = economyMenu.economyData
	local inventoryTab = economyMenu.inventoryTab
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
	-- Training drives its own combat camera, so the lobby's establishing-shot
	-- transition must stay out of the way until onboarding hands back over.
	useWorldTransition(currentPage, props.CameraEnabled ~= false and not onboardingActive)

	React.useEffect(function()
		if props.WorldPresentationEnabled == false or onboardingActive then
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
		if props.WorldPresentationEnabled == false or onboardingActive then
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
	end, { partyClient, notifications.confirm, props.WorldPresentationEnabled, onboardingActive })

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
			if onboardingActive then
				return
			end
			if economyMenu.CloseTopLayer() then
				return
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
		economyMenu.CloseTopLayer,
		joinOpen,
		currentPage,
		onboardingActive,
	})

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
						OnTabChanged = economyMenu.setInventoryTab,
						OnEquip = economyMenu.equip,
					})
				elseif pageName == "Settings" then
					return c(SettingsPage, { Position = position, Place = "Lobby" })
				elseif pageName == "Shop" then
					return c(ShopPage, {
						Model = economyMenu.shopModel,
						Position = position,
						OnCardActivated = economyMenu.activateShopCard,
						OnRefresh = economyMenu.refreshShop,
					})
				end
				return nil
			end,
		})
	end

	return c("Frame", {
		ref = rootRef,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Onboarding = if onboardingClient
			then c(OnboardingOverlay, {
				Snapshot = onboarding,
				OnSkip = onboardingClient.skip,
			})
			else nil,
		BaseClip = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = lobbyVisible,
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
				Economy = c(EconomyMenuModals, {
					Controller = economyMenu,
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
