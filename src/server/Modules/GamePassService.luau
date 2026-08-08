--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local GamePasses = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GamePasses"))
local CosmeticsService = require(script.Parent.CosmeticsService)
local PlayerData = require(script.Parent.PlayerData)

-- Reconciles permanent platform pass ownership into idempotent cosmetic
-- grants. Roblox owns pass state; profile Cosmetics.Owned owns granted items.

type StartOptions = {
	marketplace: any?,
	players: any?,
	playerData: any?,
	cosmeticsService: any?,
	gamePasses: any?,
	cosmetics: any?,
	runAsync: ((callback: () -> ()) -> ())?,
	wait: ((seconds: number) -> ())?,
}

local GamePassService = {}

local PROFILE_ATTEMPTS = 120
local PURCHASE_ATTEMPTS = 4
local RETRY_SECONDS = 0.25

local started = false
local activeMarketplace: any = MarketplaceService
local activePlayers: any = Players
local activePlayerData: any = PlayerData
local activeCosmeticsService: any = CosmeticsService
local activeGamePasses: any = GamePasses
local activeCosmetics: any = Cosmetics
local activeRunAsync: (callback: () -> ()) -> () = task.spawn
local activeWait: (seconds: number) -> () = task.wait
local connections: { any } = {}

local function sortedPassIds(): { number }
	local ids = {}
	for passId in activeGamePasses.ById do
		table.insert(ids, passId)
	end
	table.sort(ids)
	return ids
end

local function validateCatalog()
	for key, definition in activeGamePasses.Catalog do
		if definition.Enabled then
			local allowedCategories = {}
			for _, category in definition.Categories do
				allowedCategories[category] = true
			end
			for _, itemId in definition.EntitlementItemIds do
				local item = activeCosmetics.Items[itemId]
				assert(item ~= nil, `[GamePassService] game pass "{key}" references unknown cosmetic "{itemId}"`)
				assert(
					allowedCategories[item.Category] == true,
					`[GamePassService] cosmetic "{itemId}" is outside game pass "{key}" categories`
				)
			end
		end
	end
end

local function waitForProfile(player: Player): boolean
	for _ = 1, PROFILE_ATTEMPTS do
		if activePlayerData.get(player) ~= nil then
			return true
		end
		if player.Parent == nil then
			return false
		end
		activeWait(RETRY_SECONDS)
	end
	warn(`[GamePassService] profile unavailable for {player.Name}; pass grants will retry next join`)
	return false
end

local function ownsPass(player: Player, passId: number): boolean?
	local ok, owned = pcall(function()
		return activeMarketplace:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if not ok then
		warn(`[GamePassService] ownership lookup failed for {player.Name}, pass {passId}: {owned}`)
		return nil
	end
	return owned == true
end

local function grantConfiguredPass(player: Player, passId: number): boolean
	local definition = activeGamePasses.ById[passId]
	if definition == nil or activePlayerData.get(player) == nil then
		return false
	end
	for _, itemId in definition.EntitlementItemIds do
		activeCosmeticsService.grant(player, itemId)
	end
	return true
end

local function reconcilePass(player: Player, passId: number): boolean?
	local owned = ownsPass(player, passId)
	if owned ~= true then
		return owned
	end
	return if grantConfiguredPass(player, passId) then true else nil
end

local function reconcilePlayer(player: Player)
	if not waitForProfile(player) then
		return
	end
	for _, passId in sortedPassIds() do
		reconcilePass(player, passId)
	end
end

local function onPurchaseFinished(player: Player, passId: number, wasPurchased: boolean)
	if not wasPurchased or activeGamePasses.ById[passId] == nil then
		return
	end
	activeRunAsync(function()
		if not waitForProfile(player) then
			return
		end
		for attempt = 1, PURCHASE_ATTEMPTS do
			if reconcilePass(player, passId) == true then
				return
			end
			if attempt < PURCHASE_ATTEMPTS then
				activeWait(RETRY_SECONDS)
			end
		end
		warn(`[GamePassService] purchased pass {passId} was not confirmed for {player.Name}; retrying next join`)
	end)
end

local function schedulePlayer(player: Player)
	activeRunAsync(function()
		reconcilePlayer(player)
	end)
end

function GamePassService.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activeMarketplace = if options and options.marketplace then options.marketplace else MarketplaceService
	activePlayers = if options and options.players then options.players else Players
	activePlayerData = if options and options.playerData then options.playerData else PlayerData
	activeCosmeticsService = if options and options.cosmeticsService then options.cosmeticsService else CosmeticsService
	activeGamePasses = if options and options.gamePasses then options.gamePasses else GamePasses
	activeCosmetics = if options and options.cosmetics then options.cosmetics else Cosmetics
	activeRunAsync = if options and options.runAsync then options.runAsync else task.spawn
	activeWait = if options and options.wait then options.wait else task.wait

	validateCatalog()
	table.insert(connections, activePlayers.PlayerAdded:Connect(schedulePlayer))
	table.insert(connections, activeMarketplace.PromptGamePassPurchaseFinished:Connect(onPurchaseFinished))
	for _, player in activePlayers:GetPlayers() do
		schedulePlayer(player)
	end
end

function GamePassService._resetForTest()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	started = false
	activeMarketplace = MarketplaceService
	activePlayers = Players
	activePlayerData = PlayerData
	activeCosmeticsService = CosmeticsService
	activeGamePasses = GamePasses
	activeCosmetics = Cosmetics
	activeRunAsync = task.spawn
	activeWait = task.wait
end

return GamePassService
