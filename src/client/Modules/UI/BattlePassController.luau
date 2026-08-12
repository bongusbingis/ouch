--!strict

local ButtonElement = require(script.Parent.Elements.ButtonElement)
local EconomyItemElement = require(script.Parent.Elements.EconomyItemElement)

-- Renders the season track and routes claims. The server is the only authority
-- on what is claimable; this only ever displays the payload it is handed and
-- asks. Rewards are claimed manually rather than auto-granted so the player
-- sees what they earned.

type StartOptions = {
	network: any?,
	menuManager: any?,
	buttonElement: any?,
	tierElement: any?,
	marketplace: any?,
	player: any?,
	viewNodes: any?,
	runAsync: ((callback: () -> ()) -> ())?,
}

local BattlePassController = {}

local started = false
local activeNetwork: any = nil
local activeMenuManager: any = nil
local activeButtonElement: any = ButtonElement
local activeTierElement: any = EconomyItemElement
local activeMarketplace: any = nil
local activePlayer: any = nil
local nodes: any = nil
local currentState: any = nil
local viewOpen = false
local busy = false
local menuDisconnect: (() -> ())? = nil
local cardHandles: { any } = {}
local connections: { any } = {}

local function runAsyncDefault(callback: () -> ())
	if task then
		task.spawn(callback)
	else
		callback()
	end
end

local activeRunAsync: (callback: () -> ()) -> () = runAsyncDefault

local function destroyHandles(handles: { any })
	for _, handle in handles do
		handle:destroy()
	end
	table.clear(handles)
end

local function fillMount(handle: any)
	if handle.instance == nil or UDim2 == nil then
		return
	end
	handle.instance.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.instance.Position = UDim2.fromScale(0.5, 0.5)
	handle.instance.Size = UDim2.fromScale(1, 1)
end

local function resolveView(): any
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local view =
		playerGui:WaitForChild("MainGui"):WaitForChild("BaseClip"):WaitForChild("Views"):WaitForChild("BattlePass")
	assert(view:IsA("CanvasGroup"), "[BattlePassController] Views.BattlePass must be a CanvasGroup")
	local header = view:WaitForChild("PassHeader")
	local holder = view:WaitForChild("TierHolder")
	assert(header:IsA("Frame"), "[BattlePassController] PassHeader must be a Frame")
	assert(holder:IsA("ScrollingFrame"), "[BattlePassController] TierHolder must be a ScrollingFrame")
	local track = header:WaitForChild("ProgressTrack")
	return {
		view = view,
		header = header,
		holder = holder,
		title = header:WaitForChild("SeasonTitle"),
		status = header:WaitForChild("Status"),
		tierLabel = header:WaitForChild("TierLabel"),
		progressFill = track:WaitForChild("ProgressFill"),
		claimAllMount = header:WaitForChild("ClaimAllMount"),
		premiumMount = header:WaitForChild("PremiumMount"),
		closeButton = header:WaitForChild("Close"),
	}
end

local function formatRemaining(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local days = total // 86400
	local hours = (total % 86400) // 3600
	if days > 0 then
		return `{days}d {hours}h`
	end
	return `{hours}h {(total % 3600) // 60}m`
end

local function rewardText(reward: any): string
	if reward == nil then
		return "-"
	end
	if reward.kind == "Cash" then
		return `{reward.amount} CASH`
	end
	if reward.kind == "Cosmetic" then
		return tostring(reward.itemId)
	end
	return string.upper(tostring(reward.kind))
end

local render: () -> ()

local function claimTier(tier: number, track: string)
	if busy then
		return
	end
	busy = true
	render()
	activeRunAsync(function()
		local ok, state, reason = pcall(activeNetwork.call, "ClaimSeasonTier", tier, track)
		busy = false
		if ok and state ~= nil then
			currentState = state
		elseif nodes and nodes.status then
			nodes.status.Text = `Claim failed: {tostring(reason or "unknown")}`
		end
		render()
	end)
end

local function claimAll()
	if busy then
		return
	end
	busy = true
	render()
	activeRunAsync(function()
		local ok, state = pcall(activeNetwork.call, "ClaimAllSeasonTiers")
		busy = false
		if ok and state ~= nil then
			currentState = state
		end
		render()
	end)
end

local function promptPremium()
	local productId = currentState and currentState.premiumProductId
	if productId == nil or activeMarketplace == nil or activePlayer == nil then
		return
	end
	activeRunAsync(function()
		pcall(function()
			activeMarketplace:PromptProductPurchase(activePlayer, productId)
		end)
	end)
end

local function claimableCount(): number
	if currentState == nil or not currentState.active then
		return 0
	end
	local count = 0
	for _, entry in currentState.tiers do
		if entry.unlocked then
			if entry.freeReward ~= nil and not entry.freeClaimed then
				count += 1
			end
			if currentState.hasPremium and entry.premiumReward ~= nil and not entry.premiumClaimed then
				count += 1
			end
		end
	end
	return count
end

render = function()
	if nodes == nil then
		return
	end
	destroyHandles(cardHandles)
	if not viewOpen then
		return
	end

	local state = currentState
	if state == nil then
		nodes.status.Text = "Loading season..."
		return
	end
	if not state.active then
		-- Covers both the gap between seasons and the window before the first
		-- one opens, so it must not claim a season has ended.
		nodes.title.Text = "NO ACTIVE SEASON"
		nodes.status.Text = "The next season starts soon."
		nodes.tierLabel.Text = "TIER -"
		if UDim2 then
			nodes.progressFill.Size = UDim2.fromScale(0, 1)
		end
		return
	end

	nodes.title.Text = string.upper(state.displayName)
	nodes.tierLabel.Text = `TIER {state.tier} / {state.tierCount}`
	local remaining = state.endsAt - os.time()
	nodes.status.Text = if state.hasPremium
		then `Premium unlocked  |  Ends in {formatRemaining(remaining)}`
		else `Free track  |  Ends in {formatRemaining(remaining)}`
	if UDim2 then
		local ratio = if state.xpForNextTier > 0 then state.xpIntoTier / state.xpForNextTier else 1
		nodes.progressFill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	end

	local pending = claimableCount()
	local claimHandle = activeButtonElement.mount(nodes.claimAllMount, {
		text = if busy then "..." else if pending > 0 then `CLAIM {pending}` else "CLAIM",
		name = "ClaimAll",
		activated = claimAll,
	})
	fillMount(claimHandle)
	claimHandle:setEnabled(pending > 0 and not busy)
	table.insert(cardHandles, claimHandle)

	local premiumHandle = activeButtonElement.mount(nodes.premiumMount, {
		text = if state.hasPremium then "OWNED" else if state.premiumProductId == nil then "SOON" else "GET PREMIUM",
		name = "GetPremium",
		activated = promptPremium,
	})
	fillMount(premiumHandle)
	premiumHandle:setEnabled(not state.hasPremium and state.premiumProductId ~= nil)
	table.insert(cardHandles, premiumHandle)

	for _, entry in state.tiers do
		local locked = not entry.unlocked
		local freeDone = entry.freeReward == nil or entry.freeClaimed
		local premiumDone = entry.premiumReward == nil or entry.premiumClaimed
		local canClaimFree = entry.unlocked and not freeDone
		local canClaimPremium = entry.unlocked and state.hasPremium and not premiumDone

		local actionText = "LOCKED"
		if canClaimFree then
			actionText = "CLAIM FREE"
		elseif canClaimPremium then
			actionText = "CLAIM PREMIUM"
		elseif entry.unlocked then
			actionText = if freeDone and premiumDone then "CLAIMED" else "PREMIUM ONLY"
		end

		local handle = activeTierElement.mount(nodes.holder, {
			data = {
				id = tostring(entry.tier),
				title = `TIER {entry.tier}`,
				details = `FREE: {rewardText(entry.freeReward)}   |   PREMIUM: {rewardText(entry.premiumReward)}`,
				state = if locked then "Default" else if freeDone and premiumDone then "Owned" else "Available",
				actionText = actionText,
				actionEnabled = (canClaimFree or canClaimPremium) and not busy,
				layoutOrder = entry.tier,
			},
			activated = function()
				if canClaimFree then
					claimTier(entry.tier, "Free")
				elseif canClaimPremium then
					claimTier(entry.tier, "Premium")
				end
			end,
		})
		table.insert(cardHandles, handle)
	end
end

function BattlePassController.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activeNetwork = if options and options.network
		then options.network
		else require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Network"))
	activeMenuManager = if options and options.menuManager
		then options.menuManager
		else require(script.Parent.MenuManager)
	activeButtonElement = if options and options.buttonElement then options.buttonElement else ButtonElement
	activeTierElement = if options and options.tierElement then options.tierElement else EconomyItemElement
	activeRunAsync = if options and options.runAsync then options.runAsync else runAsyncDefault
	nodes = if options and options.viewNodes then options.viewNodes else resolveView()
	activeMarketplace = if options and options.marketplace
		then options.marketplace
		else game:GetService("MarketplaceService")
	activePlayer = if options and options.player then options.player else game:GetService("Players").LocalPlayer

	activeNetwork.on("SeasonPassStateChanged", function(state)
		currentState = state
		render()
	end)

	if nodes.closeButton and nodes.closeButton.Activated then
		table.insert(
			connections,
			nodes.closeButton.Activated:Connect(function()
				activeMenuManager.close("Api")
			end)
		)
	end

	menuDisconnect = activeMenuManager.onChanged(function(newMenu: string?)
		viewOpen = newMenu == "BattlePass"
		if viewOpen and currentState == nil then
			activeRunAsync(function()
				local ok, state = pcall(activeNetwork.call, "GetSeasonPassState")
				if ok then
					currentState = state
				end
				render()
			end)
		end
		render()
	end)
	viewOpen = activeMenuManager.isOpen("BattlePass")
	render()
end

function BattlePassController._resetForTest()
	if menuDisconnect then
		menuDisconnect()
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	destroyHandles(cardHandles)
	started = false
	activeNetwork = nil
	activeMenuManager = nil
	activeButtonElement = ButtonElement
	activeTierElement = EconomyItemElement
	activeMarketplace = nil
	activePlayer = nil
	activeRunAsync = runAsyncDefault
	nodes = nil
	currentState = nil
	viewOpen = false
	busy = false
	menuDisconnect = nil
end

return BattlePassController
