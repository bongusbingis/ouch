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
local LobbyViewModel = require(UI:WaitForChild("Models"):WaitForChild("LobbyViewModel"))
local Motion = require(UI:WaitForChild("Motion"))
local useExternalStore = require(UI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local useReducedMotion = require(UI:WaitForChild("Hooks"):WaitForChild("useReducedMotion"))
local NotificationContext = require(UI:WaitForChild("Contexts"):WaitForChild("NotificationContext"))
local InventoryPage = require(Components:WaitForChild("InventoryPage"))
local JoinCodeModal = require(Components:WaitForChild("JoinCodeModal"))
local NotificationModal = require(Components:WaitForChild("NotificationModal"))
local PageTransition = require(Components:WaitForChild("PageTransition"))
local PartyCode = require(Components:WaitForChild("PartyCode"))
local ShopPage = require(Components:WaitForChild("ShopPage"))
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
	local notifications = NotificationContext.useNotification()
	local currentPage, setCurrentPage = React.useState("SplashScreen")
	local inventoryTab, setInventoryTab = React.useState("OUTFITS")
	local joinOpen, setJoinOpen = React.useState(false)
	local codeVisible, setCodeVisible = React.useState(false)
	local busySlots = React.useRef({})
	local storeData = useExternalStore(EconomyStore.snapshot, EconomyStore.onChanged)
	local economyData = props.EconomyData or storeData
	local snapshot, requestBusy = useParty(partyClient, notifications)
	local presentation = LobbyViewModel.partyPresentation(snapshot, Players.LocalPlayer.UserId, requestBusy)
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
		if props.WorldPresentationEnabled == false then
			return
		end
		return partyClient:subscribeErrors(function(errorCode)
			notifications.notify({
				title = "PARTY NOTICE",
				description = partyClient.ErrorMessages[errorCode] or "PARTY REQUEST FAILED",
				buttonText = "CONFIRM",
			})
		end)
	end, { partyClient, notifications.notify })

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
			if not isBack then
				return
			end
			if notifications.request then
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
	end, { notifications.request, notifications.close, joinOpen, currentPage })

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
				return c(ShopPage, { Position = position })
			end,
		})
	end

	return c("ScreenGui", {
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
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
			}),
			GameVersion = c(GameVersion, {
				Position = UDim2.fromScale(0.5, 0.95),
			}),
		}),
	})
end

return function(props)
	return c(NotificationContext.Provider, nil, {
		LobbyApp = c(LobbyContent, props),
	})
end
