--!strict

local QuestCardElement = require(script.Parent.Elements.QuestCardElement)
local ElementTypes = require(script.Parent.Elements.ElementTypes)

type QuestCardData = ElementTypes.QuestCardData
type QuestCardHandle = ElementTypes.QuestCardHandle

type QuestState = {
	dailyKey: string,
	resetAt: number,
	quests: { QuestCardData },
}

type StartOptions = {
	network: any?,
	cardElement: any?,
	menuManager: any?,
	holder: ScrollingFrame?,
	resetsIn: TextLabel?,
}

local QuestsController = {}

local started = false
local holder: ScrollingFrame? = nil
local resetsIn: TextLabel? = nil
local handles: { QuestCardHandle } = {}
local currentState: QuestState? = nil
local defaultNetwork: any? = nil
local defaultMenuManager: any? = nil
local activeNetwork: any = nil
local activeCardElement: any = QuestCardElement
local activeMenuManager: any = nil
local menuDisconnect: (() -> ())? = nil
local viewOpen = false
local fetching = false
local claimableCallbacks: { (boolean) -> () } = {}
local lastClaimable = false

local function resolveNetwork(): any
	if defaultNetwork == nil then
		local replicatedStorage = game:GetService("ReplicatedStorage")
		defaultNetwork = require(replicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
	end
	return defaultNetwork
end

local function resolveMenuManager(): any
	if defaultMenuManager == nil then
		defaultMenuManager = require(script.Parent.MenuManager)
	end
	return defaultMenuManager
end

local function resolveView(): (ScrollingFrame, TextLabel)
	local Players = game:GetService("Players")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local quests =
		playerGui:WaitForChild("MainGui"):WaitForChild("BaseClip"):WaitForChild("Views"):WaitForChild("Quests")
	local holderInstance = quests:WaitForChild("Holder")
	local resetsInInstance = quests:WaitForChild("ResetsIn")
	assert(holderInstance:IsA("ScrollingFrame"), "[QuestsController] Views.Quests.Holder must be a ScrollingFrame")
	assert(resetsInInstance:IsA("TextLabel"), "[QuestsController] Views.Quests.ResetsIn must be a TextLabel")
	return holderInstance, resetsInInstance
end

local function destroyCards()
	for index = 1, #handles do
		local handle = handles[index]
		handle:destroy()
	end
	table.clear(handles)
end

local function formatSeconds(seconds: number): string
	local clamped = math.max(0, math.floor(seconds))
	local hours = math.floor(clamped / 3600)
	local minutes = math.floor((clamped % 3600) / 60)
	local secs = clamped % 60
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function updateResetLabel()
	local label = resetsIn
	local state = currentState
	if label == nil or state == nil then
		return
	end
	label.Text = `Quests reset in: {formatSeconds(state.resetAt - os.time())}`
end

local function hasClaimableQuest(): boolean
	local state = currentState
	if state == nil then
		return false
	end
	for _, quest in state.quests do
		if quest.completed and not quest.claimed then
			return true
		end
	end
	return false
end

local function notifyClaimable()
	local claimable = hasClaimableQuest()
	if claimable == lastClaimable then
		return
	end
	lastClaimable = claimable
	for _, callback in claimableCallbacks do
		local ok, err = pcall(callback, claimable)
		if not ok then
			warn(`[QuestsController] claimable callback failed: {err}`)
		end
	end
end

local setState: (QuestState?) -> ()

local function mountCards()
	destroyCards()

	local state = currentState
	if not viewOpen or state == nil or holder == nil then
		return
	end

	table.sort(state.quests, function(left, right)
		return left.slot < right.slot
	end)

	for index = 1, #state.quests do
		local quest = state.quests[index]
		table.insert(
			handles,
			activeCardElement.mount(holder, {
				data = quest,
				claim = function(questId: string)
					local ok, claimState = activeNetwork.call("ClaimQuest", questId)
					if ok and claimState then
						setState(claimState)
					end
				end,
			})
		)
	end
end

setState = function(state: QuestState?)
	currentState = state
	mountCards()
	updateResetLabel()
	notifyClaimable()
end

local function runAsync(callback: () -> ())
	if task ~= nil then
		task.spawn(callback)
	else
		callback()
	end
end

local function fetchState()
	if fetching then
		return
	end
	fetching = true
	local ok, state = pcall(function()
		return activeNetwork.call("GetQuestState")
	end)
	fetching = false
	if ok then
		setState(state)
	end
end

local function setOpen(isOpen: boolean)
	if viewOpen == isOpen then
		return
	end
	viewOpen = isOpen
	if viewOpen then
		if currentState == nil then
			runAsync(fetchState)
		else
			mountCards()
		end
	else
		destroyCards()
	end
end

function QuestsController.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activeNetwork = if options and options.network then options.network else resolveNetwork()
	activeCardElement = if options and options.cardElement then options.cardElement else QuestCardElement
	activeMenuManager = if options and options.menuManager then options.menuManager else resolveMenuManager()

	if options and options.holder and options.resetsIn then
		holder = options.holder
		resetsIn = options.resetsIn
	else
		holder, resetsIn = resolveView()
	end

	activeNetwork.on("QuestStateChanged", setState)
	menuDisconnect = activeMenuManager.onChanged(function(newMenu: string?)
		setOpen(newMenu == "Quests")
	end)
	viewOpen = activeMenuManager.isOpen("Quests")

	runAsync(fetchState)

	if task ~= nil then
		task.spawn(function()
			while started do
				updateResetLabel()
				task.wait(1)
			end
		end)
	end
end

function QuestsController.hasClaimableQuest(): boolean
	return hasClaimableQuest()
end

function QuestsController.onClaimableChanged(callback: (boolean) -> ()): () -> ()
	table.insert(claimableCallbacks, callback)
	callback(hasClaimableQuest())
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(claimableCallbacks, callback)
		if index then
			table.remove(claimableCallbacks, index)
		end
	end
end

function QuestsController._resetForTest()
	if menuDisconnect then
		menuDisconnect()
	end
	destroyCards()
	started = false
	holder = nil
	resetsIn = nil
	currentState = nil
	activeNetwork = nil
	activeCardElement = QuestCardElement
	activeMenuManager = nil
	menuDisconnect = nil
	viewOpen = false
	fetching = false
	claimableCallbacks = {}
	lastClaimable = false
end

return QuestsController
