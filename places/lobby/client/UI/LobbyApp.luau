-- Description: Root React component for the lobby: the splash and party pages, join-code modal, shop and inventory menus, loading screen, and world transitions.

--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local useSafeArea = require(UI.Hooks.useSafeArea)
local ResponsiveLayout = require(UI.Models.ResponsiveLayout)
local StageFraming = require(UI.Models.StageFraming)
local MatchmakingConfig = require(Shared:WaitForChild("Matchmaking"):WaitForChild("Config"))
local Components = UI:WaitForChild("Components")
local PresentationCamera = require(UI.Services.PresentationCamera)
local CosmeticPreviewClient = require(UI.Services.CosmeticPreviewClient)
local Selection = require(UI.Services.Selection)
local Config = ReplicatedStorage:WaitForChild("Config")
local Loading = require(Config:WaitForChild("Interface"):WaitForChild("Loading"))
local LobbyViewModel = require(UI:WaitForChild("Models"):WaitForChild("LobbyViewModel"))
local Motion = require(UI:WaitForChild("Motion"))
local EconomyMenuController = require(UI:WaitForChild("Hooks"):WaitForChild("EconomyMenuController"))
local useReducedMotion = require(UI:WaitForChild("Hooks"):WaitForChild("useReducedMotion"))
local NotificationContext = require(UI:WaitForChild("Contexts"):WaitForChild("NotificationContext"))
local useExternalStore = require(UI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local DailyRewardModal = require(Components:WaitForChild("DailyRewardModal"))
local EconomyMenuModals = require(Components:WaitForChild("EconomyMenuModals"))
local InventoryPage = require(Components:WaitForChild("InventoryPage"))
local JoinCodeModal = require(Components:WaitForChild("JoinCodeModal"))
local LoadingScreen = require(Components:WaitForChild("LoadingScreen"))
local NotificationModal = require(Components:WaitForChild("NotificationModal"))
local PageTransition = require(Components:WaitForChild("PageTransition"))
local PartyCode = require(Components:WaitForChild("PartyCode"))
local PartyMembersModal = require(script.Parent.PartyMembersModal)
local OnboardingOverlay = require(Components:WaitForChild("Onboarding"):WaitForChild("OnboardingOverlay"))
local SettingsPage = require(Components:WaitForChild("SettingsPage"))
local ShopPage = require(Components:WaitForChild("ShopPage"))
local UIAnalytics = require(UI:WaitForChild("Services"):WaitForChild("UIAnalytics"))
local SplashPage = require(Components:WaitForChild("SplashPage"))
local TopBar = require(Components:WaitForChild("TopBar"))
local LobbyHeaderLayout = require(UI.Models.LobbyHeaderLayout)
local GameVersion = require(Components:WaitForChild("GameVersion"))
local DeviceClass = require(Shared:WaitForChild("Game"):WaitForChild("Input"):WaitForChild("DeviceClass"))

local PartyCharacterRenderer =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Lobby"):WaitForChild("PartyCharacterRenderer"))

local c = React.createElement

local PAGE_POSITIONS = {
	SplashScreen = {
		onscreen = UDim2.fromScale(0, 0),
		offscreen = UDim2.fromScale(0, 1),
	},
	Inventory = {
		onscreen = UIConfig.Layout.InventoryPagePosition,
		offscreen = UIConfig.Layout.PageOffscreen,
	},
	Shop = {
		onscreen = UIConfig.Layout.PagePosition,
		offscreen = UIConfig.Layout.PageOffscreen,
	},
	Settings = {
		onscreen = UIConfig.Layout.PagePosition,
		offscreen = UIConfig.Layout.PageOffscreen,
	},
}

local PAGE_BACKGROUND_COLORS = {
	SplashScreen = Color3.fromRGB(255, 211, 64),
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

local function partyBounds(
	party: Instance,
	inventory: boolean,
	inventoryWeapons: boolean,
	partyCount: number,
	reference: CFrame
): (Vector3, Vector3, { Vector3 }, Vector3)
	local config = UIConfig.Layout.WorldFraming
	local spawns = party:WaitForChild("Players")
	local halfSize = Vector3.new(
		config.CharacterWidthStuds,
		config.CharacterHeightStuds + config.NameHeadroomStuds,
		config.CharacterDepthStuds
	) / 2
	local minimum, maximum = Vector3.one * math.huge, Vector3.one * -math.huge
	local points = {}
	local inventoryTarget: Vector3? = nil
	for index = 1, if inventory then 1 else partyCount do
		local spawn = spawns:WaitForChild(`Player{index}`)
		assert(spawn:IsA("BasePart"), `[LobbyApp] Views.Party.Players.Player{index} must be a BasePart`)
		local center = spawn.Position + Vector3.new(0, config.NameHeadroomStuds / 2, 0)
		local frame = CFrame.new(center)
		local low, high = -halfSize, halfSize
		if inventory then
			inventoryTarget = spawn.Position
			local envelope = if inventoryWeapons then config.InventorySkins else config.InventoryBody
			low, high = envelope.Minimum, envelope.Maximum
			local direction =
				Vector3.new(reference.Position.X - spawn.Position.X, 0, reference.Position.Z - spawn.Position.Z)
			frame = if direction.Magnitude > 0.001
				then CFrame.lookAt(spawn.Position, spawn.Position + direction, Vector3.yAxis)
				else spawn.CFrame
		end
		for _, point in StageFraming.boxPoints(frame, low, high) do
			minimum, maximum = minimum:Min(point), maximum:Max(point)
			table.insert(points, point)
		end
	end
	local viewTarget = inventoryTarget or (minimum + maximum) / 2 - Vector3.new(0, config.NameHeadroomStuds / 2, 0)
	return minimum, maximum, points, viewTarget
end

local function useWorldTransition(
	currentPage: string,
	inventoryWeapons: boolean,
	partyCount: number,
	enabled: boolean,
	worldWindows: any,
	rootRef: any
)
	local reducedMotion = useReducedMotion()
	local styles, api = ReactSpring.useSpring(function()
		return { Alpha = 1 }
	end)
	local startCFrame = React.useRef(CFrame.identity)
	local targetCFrame = React.useRef(CFrame.identity)
	local startFieldOfView = React.useRef(nil)
	local framing = React.useRef(nil)
	local windows = React.useRef(worldWindows)
	windows.current = worldWindows
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
		local framedPage = currentPage == "SplashScreen" or currentPage == "Inventory"
		if framedPage then
			local minimum, maximum, points, viewTarget =
				partyBounds(party, currentPage == "Inventory", inventoryWeapons, partyCount, target.CFrame)
			framing.current =
				{ page = currentPage, minimum = minimum, maximum = maximum, points = points, viewTarget = viewTarget }
		else
			framing.current = nil
		end
		startFieldOfView.current = camera.FieldOfView
		if not initialized.current or reducedMotion then
			initialized.current = true
			startCFrame.current = target.CFrame
			targetCFrame.current = target.CFrame
			startColor.current = pageColor
			targetColor.current = pageColor
			partyBackground.Color = pageColor
			api.start({ Alpha = 1, immediate = true })
			return function()
				if transitionRevision.current == revision then
					transitionRevision.current += 1
				end
			end
		end
		startCFrame.current = if PresentationCamera.getOwner() == "Lobby" then camera.CFrame else targetCFrame.current
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
	end, { currentPage, inventoryWeapons, partyCount, reducedMotion, enabled })

	React.useEffect(function()
		if not enabled then
			return
		end
		local baseCamera: Camera? = nil
		local baseFieldOfView: number? = nil
		local lease = PresentationCamera.acquire("Lobby", PresentationCamera.Priority.Lobby, function(camera)
			if baseCamera ~= camera then
				baseCamera = camera
				baseFieldOfView = camera.FieldOfView
			end
			local alpha = styles.Alpha:getValue()
			local target = targetCFrame.current
			local bounds = framing.current
			local window = if bounds then windows.current[bounds.page] else nil
			local host = if window then window.ref.current else nil
			local root = rootRef.current
			local fieldOfView = baseFieldOfView or camera.FieldOfView
			local config = UIConfig.Layout.WorldFraming
			if
				host
				and root
				and camera.ViewportSize.X > 1
				and camera.ViewportSize.Y > 1
				and host.AbsoluteSize.X > config.PixelPadding * 2 + 1
				and host.AbsoluteSize.Y > config.PixelPadding * 2 + 1
			then
				local padding = Vector2.new(config.PixelPadding, config.PixelPadding)
				local position = root.AbsolutePosition
					+ window.position
					- GuiService:GetInsetArea(Enum.ScreenInsets.None).Min
				target = StageFraming.pointsCamera(
					target,
					bounds.points,
					position + padding,
					host.AbsoluteSize - padding * 2,
					camera.ViewportSize,
					config.FieldOfView,
					bounds.viewTarget
				)
				fieldOfView = config.FieldOfView
				camera.Focus = CFrame.new((bounds.minimum + bounds.maximum) / 2)
			end
			local startFov = startFieldOfView.current or fieldOfView
			camera.FieldOfView = startFov + (fieldOfView - startFov) * alpha
			camera.CFrame = startCFrame.current:Lerp(target, alpha)
			local partyBackground = background.current
			if partyBackground then
				partyBackground.Color = startColor.current:Lerp(targetColor.current, alpha)
			end
		end)
		return function()
			api.stop()
			PresentationCamera.release(lease)
		end
	end, { enabled })
end

local function LobbyContent(props)
	local effectPreview = useExternalStore(CosmeticPreviewClient.getSnapshot, CosmeticPreviewClient.subscribe)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	local shortPages = not portrait and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx
	local headerLayout = LobbyHeaderLayout.resolve(safeArea.size)
	local partyClient = props.PartyClient
	local onboardingClient = props.OnboardingClient
	local rootRef = React.useRef(nil)
	local splashWorldRef = React.useRef(nil)
	local inventoryWorldRef = React.useRef(nil)
	local inventoryComposition = ResponsiveLayout.inventoryComposition(safeArea.size, UIConfig.Layout)
	local splashWorld = ResponsiveLayout.splashWorldWindow(safeArea.size, UIConfig.Layout)
	local worldWindows = if portrait
		then {}
		else {
			SplashScreen = { ref = splashWorldRef, position = safeArea.position + splashWorld.position },
			Inventory = { ref = inventoryWorldRef, position = safeArea.position + inventoryComposition.world.position },
		}
	local presented = React.useRef(false)
	local playButtonRef = React.useRef(nil)
	local previousSelection = React.useRef(nil)
	local focusRevision = React.useRef(0)
	local isGamepad, setIsGamepad = React.useState(false)
	React.useEffect(function()
		return DeviceClass.observe(function(class)
			setIsGamepad(class == "Gamepad")
		end)
	end, {})
	local notifications = NotificationContext.useNotification()
	local currentPage, setCurrentPage = React.useState("SplashScreen")
	local activeWorldWindow = React.useRef(nil)
	activeWorldWindow.current = worldWindows[currentPage]

	local onboarding, setOnboarding = React.useState(function()
		return if onboardingClient then onboardingClient.getSnapshot() else nil
	end)
	React.useEffect(function()
		if onboardingClient == nil then
			return
		end
		local disconnect = onboardingClient.subscribe(setOnboarding)
		setOnboarding(onboardingClient.getSnapshot())
		return disconnect
	end, { onboardingClient })

	-- Studio-only combat test session (nil in production). While it runs it owns
	-- the combat camera on the baseplate, so the lobby's scripted world view and
	-- party UI stand down exactly as they do for onboarding.
	local combatTestClient = props.CombatTestClient
	local combatTest, setCombatTest = React.useState(function()
		return if combatTestClient then combatTestClient.getSnapshot() else nil
	end)
	React.useEffect(function()
		if combatTestClient == nil then
			return
		end
		local disconnect = combatTestClient.subscribe(setCombatTest)
		setCombatTest(combatTestClient.getSnapshot())
		return disconnect
	end, { combatTestClient })
	local testActive = combatTest ~= nil and combatTest.active == true

	-- Training owns the screen until eligibility resolves, so the normal lobby
	-- never flashes in front of a new player and then gets yanked away.
	local onboardingActive = onboarding ~= nil and onboarding.active == true
	local onboardingResolved = onboarding == nil or onboarding.resolved == true
	local lobbyVisible = onboardingResolved and not onboardingActive and not testActive

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
	local partyMembersOpen, setPartyMembersOpen = React.useState(false)
	local codeVisible, setCodeVisible = React.useState(false)
	local devTapState = React.useRef({ lastTapAt = 0, tapCount = 0 })
	local viewInventory = React.useCallback(function()
		setCurrentPage("Inventory")
	end, {})
	local economyMenu = EconomyMenuController.use({
		ShopClient = props.ShopClient,
		EconomyData = props.EconomyData,
		ShopRefreshEnabled = props.ShopRefreshEnabled,
		OnViewInventory = viewInventory,
	})
	local economyData = economyMenu.economyData
	local inventoryTab = economyMenu.inventoryTab
	local snapshot, requestBusy = useParty(partyClient, notifications)
	local partyCount = 1
	local framedUserIds = { [Players.LocalPlayer.UserId] = true }
	for _, member in if snapshot then snapshot.members else {} do
		if partyCount >= MatchmakingConfig.PartyMaxPlayers then
			break
		end
		if not framedUserIds[member.userId] then
			framedUserIds[member.userId] = true
			partyCount += 1
		end
	end
	local teleportStatus = partyClient:getTeleportStatus()
	local presentation = LobbyViewModel.partyPresentation(snapshot, Players.LocalPlayer.UserId, requestBusy)
	React.useEffect(function()
		focusRevision.current += 1
		local revision = focusRevision.current
		local root = rootRef.current
		if lobbyVisible and isGamepad then
			if previousSelection.current == nil then
				previousSelection.current = GuiService.SelectedObject
			end
			if currentPage == "SplashScreen" and presentation.playEnabled then
				task.defer(function()
					if
						focusRevision.current ~= revision
						or DeviceClass.current() ~= "Gamepad"
						or Selection.isSelectable(GuiService.SelectedObject)
					then
						return
					end
					local button = playButtonRef.current
					if Selection.isSelectable(button) then
						GuiService.SelectedObject = button
					end
				end)
			end
		else
			local previous = previousSelection.current
			previousSelection.current = nil
			if DeviceClass.current() == "Gamepad" and Selection.isSelectable(previous) then
				GuiService.SelectedObject = previous
			elseif
				root ~= nil
				and GuiService.SelectedObject ~= nil
				and GuiService.SelectedObject:IsDescendantOf(root)
			then
				GuiService.SelectedObject = nil
			end
		end
		return function()
			focusRevision.current += 1
		end
	end, { lobbyVisible, isGamepad, presentation.playEnabled })
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
	React.useEffect(function()
		if loadingVisible or not lobbyVisible then
			CosmeticPreviewClient.close(nil, "unavailable")
		end
	end, { loadingVisible, lobbyVisible })
	local equipped = if economyData then economyData.Cosmetics.Equipped else {}
	local skinPreviewState = React.useRef({})
	skinPreviewState.current = {
		active = currentPage == "Inventory" and inventoryTab == "SKINS",
		ballItemId = equipped.BallAssets,
		hammerItemId = equipped.HammerAssets,
	}
	local characterRenderer = React.useRef(nil)
	local _, updateUsernames = React.useReducer(function(revision)
		return revision + 1
	end, 0)
	-- Training drives its own combat camera, so the lobby's establishing-shot
	-- transition must stay out of the way until onboarding hands back over.
	useWorldTransition(
		currentPage,
		skinPreviewState.current.active,
		if currentPage == "SplashScreen" then partyCount else 1,
		props.CameraEnabled ~= false and not onboardingActive and not testActive,
		worldWindows,
		rootRef
	)

	local dailyRewardState = useExternalStore(props.DailyRewardStore.snapshot, props.DailyRewardStore.subscribe)
	local seasonState = useExternalStore(props.SeasonStore.snapshot, props.SeasonStore.subscribe)
	local questState = useExternalStore(props.QuestStore.snapshot, props.QuestStore.subscribe)

	local showDailyRewardModal, setShowDailyRewardModal = React.useState(false)
	local pendingClaims, setPendingClaims = React.useState({})
	local claimRequests = React.useRef({})
	local dailyClaimError, setDailyClaimError = React.useState(nil)
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})
	local function claimReward(key, action)
		if type(key) ~= "string" or key == "" then
			return
		end
		if claimRequests.current[key] then
			return
		end
		claimRequests.current[key] = true
		setPendingClaims(table.clone(claimRequests.current))
		if key == "Daily" then
			setDailyClaimError(nil)
		end
		task.spawn(function()
			local callOk, result = pcall(action)
			claimRequests.current[key] = nil
			if not mounted.current then
				return
			end
			setPendingClaims(table.clone(claimRequests.current))
			if not callOk or not result then
				if key == "Daily" then
					setDailyClaimError("COULDN'T CLAIM. TRY AGAIN.")
				else
					notifications.notify({
						title = "REWARD NOT CLAIMED",
						description = "COULDN'T CLAIM THAT REWARD. TRY AGAIN.",
					})
				end
			end
		end)
	end
	local dailyRewardAutoPopped = React.useRef(false)
	React.useEffect(function()
		if
			lobbyVisible
			and snapshot ~= nil
			and snapshot.phase == "Lobby"
			and not snapshot.returnQueuePending
			and dailyRewardState ~= nil
			and dailyRewardState.canClaim
			and not dailyRewardAutoPopped.current
		then
			local pending = task.delay(0.5, function()
				dailyRewardAutoPopped.current = true
				setShowDailyRewardModal(true)
			end)
			return function()
				if coroutine.status(pending) ~= "dead" then
					task.cancel(pending)
				end
			end
		end
	end, { lobbyVisible, dailyRewardState, snapshot })

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

	local removePartyMember = React.useCallback(function(targetUserId, username)
		local current = partyClient:getSnapshot()
		if
			current == nil
			or current.leaderUserId ~= Players.LocalPlayer.UserId
			or partyClient:isBusy()
			or (current.phase ~= "Lobby" and current.phase ~= "Queued")
		then
			return
		end
		setPartyMembersOpen(false)
		notifications.confirm({
			title = "REMOVE PLAYER?",
			description = `Remove {username} from your party?`,
			confirmText = "REMOVE",
			cancelText = "CANCEL",
		}, function(confirmed)
			if confirmed then
				task.spawn(partyClient.kick, partyClient, targetUserId)
			end
		end)
	end, { partyClient, notifications.confirm })

	React.useEffect(function()
		if props.WorldPresentationEnabled == false or onboardingActive then
			return
		end
		local renderer = PartyCharacterRenderer.new(Players.LocalPlayer.UserId, removePartyMember, function()
			local window = activeWorldWindow.current
			local root = rootRef.current
			local host = if window then window.ref.current else nil
			if not host or not root or host.AbsoluteSize.X <= 1 or host.AbsoluteSize.Y <= 1 then
				return nil
			end
			local position = root.AbsolutePosition
				+ window.position
				- GuiService:GetInsetArea(Enum.ScreenInsets.None).Min
			return Rect.new(position, position + host.AbsoluteSize)
		end)
		characterRenderer.current = renderer
		local disconnectNames = renderer:SubscribeUsernames(function()
			updateUsernames(nil)
		end)
		renderer:SetCompactParty(shortPages and currentPage == "SplashScreen")
		local preview = skinPreviewState.current
		renderer:SetSkinsPreview(preview.active, preview.ballItemId, preview.hammerItemId)
		local disconnect = partyClient:subscribe(function(nextSnapshot)
			if nextSnapshot then
				renderer:Render(nextSnapshot)
			end
		end)
		return function()
			characterRenderer.current = nil
			disconnectNames()
			disconnect()
			renderer:destroy()
		end
	end, { partyClient, removePartyMember, props.WorldPresentationEnabled, onboardingActive })

	React.useEffect(function()
		local renderer = characterRenderer.current
		if renderer then
			renderer:SetCompactParty(shortPages and currentPage == "SplashScreen")
		end
		if currentPage ~= "SplashScreen" or not lobbyVisible or loadingVisible then
			setPartyMembersOpen(false)
		end
	end, { shortPages, currentPage, lobbyVisible, loadingVisible })

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
			if effectPreview.active then
				economyMenu.closePreview()
				return
			elseif notifications.request ~= nil then
				notifications.close(false)
				return
			elseif showDailyRewardModal then
				setShowDailyRewardModal(false)
				return
			elseif partyMembersOpen then
				setPartyMembersOpen(false)
				return
			elseif economyMenu.CloseTopLayer() then
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
		effectPreview.active,
		economyMenu.closePreview,
		economyMenu.CloseTopLayer,
		notifications.request,
		notifications.close,
		showDailyRewardModal,
		partyMembersOpen,
		joinOpen,
		currentPage,
		onboardingActive,
	})

	local partyMembers = {}
	if snapshot then
		local function appendMember(member)
			local player = Players:GetPlayerByUserId(member.userId)
			local renderer = characterRenderer.current
			table.insert(partyMembers, {
				userId = member.userId,
				username = (renderer and renderer:GetUsername(member.userId)) or (player and player.Name),
			})
		end
		for _, member in snapshot.members do
			if member.userId == Players.LocalPlayer.UserId then
				appendMember(member)
			end
		end
		for _, member in snapshot.members do
			if member.userId ~= Players.LocalPlayer.UserId then
				appendMember(member)
			end
		end
	end
	local views = {}
	for pageName, positions in PAGE_POSITIONS do
		views[pageName] = c(PageTransition, {
			Active = currentPage == pageName,
			Onscreen = if pageName == "Inventory" and not portrait
				then UDim2.fromOffset(
					safeArea.position.X + inventoryComposition.panel.position.X + inventoryComposition.panel.size.X / 2,
					safeArea.position.Y + inventoryComposition.panel.position.Y + inventoryComposition.panel.size.Y / 2
				)
				elseif shortPages and pageName ~= "SplashScreen" then UIConfig.Layout.ShortPagePosition
				elseif portrait and pageName == "Inventory" then UIConfig.Layout.PagePosition
				else positions.onscreen,
			Offscreen = if shortPages and pageName ~= "SplashScreen"
				then UIConfig.Layout.ShortPageOffscreen
				else positions.offscreen,
			Render = function(position)
				if pageName == "SplashScreen" then
					return c(SplashPage, {
						Position = position,
						PlayButtonRef = playButtonRef,
						WorldWindowRef = splashWorldRef,
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
						DailyReward = dailyRewardState,
						OnViewDailyReward = function()
							setShowDailyRewardModal(true)
						end,
						SeasonState = seasonState,
						OnViewSeasonRewards = if economyMenu.canViewSeason then economyMenu.viewSeason else nil,
						QuestState = questState,
						PendingClaims = pendingClaims,
						OnClaimSeason = function()
							claimReward("Season", props.SeasonStore.claimAll)
						end,
						OnClaimQuest = function(questId)
							claimReward(questId, function()
								return props.QuestStore.claim(questId)
							end)
						end,
					})
				elseif pageName == "Inventory" then
					return c(InventoryPage, {
						Data = economyData,
						Position = position,
						SelectedTab = inventoryTab,
						WorldWindowRef = if portrait then nil else inventoryWorldRef,
						OnTabChanged = economyMenu.setInventoryTab,
						OnEquip = economyMenu.equip,
						OnInspect = economyMenu.inspectInventory,
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
			Visible = lobbyVisible and not effectPreview.active,
		}, {
			Views = c("Frame", {
				ClipsDescendants = true,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}, views),
			HUD = c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}, {
				TopBar = c(TopBar, {
					CurrentPage = currentPage,
					OnNavigate = setCurrentPage,
					LobbyHeader = true,
					HeaderVisible = lobbyVisible and not effectPreview.active,
				}),
				PartyCode = c(PageTransition, {
					Active = currentPage == "SplashScreen",
					Onscreen = UDim2.fromOffset(
						safeArea.position.X + headerLayout.party.position.X + headerLayout.party.size.X,
						safeArea.position.Y + headerLayout.party.position.Y
					),
					Offscreen = UDim2.new(1, -8, -1, 0),
					Render = function(position)
						return c(PartyCode, {
							Compact = true,
							Size = UDim2.fromOffset(headerLayout.party.size.X, headerLayout.party.size.Y),
							Label = headerLayout.partyLabel,
							Position = position,
							CodeText = LobbyViewModel.formatPartyCode(
								if snapshot then snapshot.joinCode else nil,
								codeVisible
							),
							CodeVisible = codeVisible,
							OnOpen = function()
								setPartyMembersOpen(true)
							end,
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
				PartyMembers = c(PartyMembersModal, {
					Open = partyMembersOpen and currentPage == "SplashScreen",
					FocusEnabled = notifications.request == nil,
					Members = partyMembers,
					LocalUserId = Players.LocalPlayer.UserId,
					LeaderUserId = if snapshot then snapshot.leaderUserId else nil,
					CodeText = LobbyViewModel.formatPartyCode(if snapshot then snapshot.joinCode else nil, codeVisible),
					CodeVisible = codeVisible,
					CodeAvailable = snapshot ~= nil and snapshot.joinCode ~= nil,
					CanRemove = snapshot ~= nil
						and snapshot.leaderUserId == Players.LocalPlayer.UserId
						and not requestBusy
						and (snapshot.phase == "Lobby" or snapshot.phase == "Queued"),
					OnToggleCode = function()
						setCodeVisible(function(value)
							return not value
						end)
					end,
					OnRemove = removePartyMember,
					OnClose = function()
						setPartyMembersOpen(false)
					end,
				}),
				JoinCode = c(JoinCodeModal, {
					Open = joinOpen,
					FocusEnabled = notifications.request == nil and not showDailyRewardModal,
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
					FocusEnabled = not effectPreview.active,
				}),
				Economy = c(EconomyMenuModals, {
					FocusEnabled = notifications.request == nil,
					Controller = economyMenu,
				}),
				DailyReward = c(DailyRewardModal, {
					Visible = showDailyRewardModal,
					State = dailyRewardState,
					Pending = pendingClaims.Daily,
					ErrorText = dailyClaimError,
					FocusEnabled = notifications.request == nil,
					OnClaim = function()
						claimReward("Daily", props.DailyRewardStore.claim)
					end,
					OnClose = function()
						setShowDailyRewardModal(false)
					end,
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
