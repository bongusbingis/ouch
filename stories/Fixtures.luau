--[[
    Shared story data, so no story invents its own. Everything a screen needs that would normally
    come from the server or a client store is built here once, realistic and stable:

      Players     eight named players (local player first) with team ids and scores.
      Cosmetics   real catalog entries (InventoryModel.entries over the shipped Cosmetics config),
                  one per rarity -- Common, Rare, Legendary, Exclusive -- and the full owned list.
      Quests      the daily quest board in its Mixed / AllClaimable / AllClaimed / Empty states.
      Season      an active season projection (tier 3 of 30), free and premium tracks, plus the
                  SeasonRewardsModel entries the reward browser reads.
      Daily       the seven-day reward strip at any (current day, claimed-through) point.
      Ballot      three modes (FFA / TDM / INFECTION) and maps CANDY BOWL / BAMBOO ISLE (+ a long
                  third name to exercise truncation), as GameModeSelect takes them.
      Match       MatchHUD snapshots (team, FFA, respawning, starting) through MatchHUDModel.build.
      Race        Splashdown courses from Config.Gameplay.Splashdown and HUD snapshots.
      Results     the post-match scenarios from Shared.Game.PostMatch.DebugPostMatchData.
      Economy     the shop view model built from the shipped catalog (was Stories/EconomyFixtures),
                  plus an inert ShopClient whose purchase calls all return "preview_only".
      Party       a party snapshot and an inert PartyClient / store projection.

    Nothing here talks to the server; every callback is a no-op or prints. Regional prices are
    simulated.
]]

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")
local Economy = Game:WaitForChild("Economy")
local UI = Shared:WaitForChild("UI")

local Cosmetics = require(Config:WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local EconomyConfig = Config:WaitForChild("Economy")
local Crates = require(EconomyConfig:WaitForChild("Crates"))
local Shop = require(EconomyConfig:WaitForChild("Shop"))
local Products = require(EconomyConfig:WaitForChild("Products"))
local GamePasses = require(EconomyConfig:WaitForChild("GamePasses"))
local Splashdown = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local InventoryModel = require(Economy:WaitForChild("InventoryModel"))
local T = require(UI:WaitForChild("Tokens"))
local MatchHUDModel = require(UI:WaitForChild("Models"):WaitForChild("MatchHUDModel"))
local SeasonRewardsModel = require(UI:WaitForChild("Models"):WaitForChild("SeasonRewardsModel"))

local Fixtures = {}

local function noop(...: any) end

--> One print helper for every story callback, so the Output names the story and the action.
function Fixtures.log(story: string, action: string): (...any) -> ()
	return function(...)
		print(`[{story}.story] {action}`, ...)
	end
end

Fixtures.noop = noop

-- Players ------------------------------------------------------------------------------------------

Fixtures.LocalUserId = 1

Fixtures.Players = table.freeze({
	{ userId = 1, displayName = "YOU", name = "you", teamId = "Blue", score = 9, isLocal = true, alive = true },
	{ userId = 2, displayName = "Mochi", name = "MochiMaker", teamId = "Red", score = 12, alive = true },
	{ userId = 3, displayName = "Sprinkles", name = "SprinkleStorm", teamId = "Blue", score = 7, alive = true },
	{ userId = 4, displayName = "Gumdrop", name = "GumdropGuardian", teamId = "Red", score = 6, alive = false },
	{ userId = 5, displayName = "Taffy", name = "TaffyTwister", teamId = "Blue", score = 6, alive = true },
	{
		userId = 6,
		displayName = "Marshmallow Captain",
		name = "MarshmallowCaptain",
		teamId = "Red",
		score = 4,
		alive = true,
	},
	{ userId = 7, displayName = "Jellybean", name = "JellyJumper", teamId = "Blue", score = 2, alive = true },
	{ userId = 8, displayName = "Licorice", name = "LicoriceLoop", teamId = "Red", score = 1, alive = true },
})

function Fixtures.players(count: number?): { any }
	local list = {}
	for index = 1, math.min(count or #Fixtures.Players, #Fixtures.Players) do
		table.insert(list, table.clone(Fixtures.Players[index]))
	end
	return list
end

-- Appearance used by previews (costume, colour, emotes) -----------------------------------------------

Fixtures.Appearance = table.freeze({
	ColorId = "CharacterColorBlue",
	CostumeId = "RainHopper",
	EmoteId = "ShowtimeTwirl",
})

Fixtures.EmoteSlots = table.freeze({ "EmoteWave", "ShowtimeTwirl", "ShowtimeFlex", "ShowtimeBounce" })
Fixtures.EmoteCapacity = 6

-- Cosmetics ----------------------------------------------------------------------------------------

Fixtures.Rarities = table.freeze({ "Common", "Rare", "Legendary", "Exclusive" })

local function ownAll(): { [string]: boolean }
	local owned = {}
	for itemId in Cosmetics.Items do
		owned[itemId] = true
	end
	return owned
end

--> Every real catalog entry, owned, in InventoryModel's own order.
function Fixtures.allEntries(category: string?): { any }
	return InventoryModel.entries(Cosmetics, ownAll(), category)
end

--> One real, non-default entry per rarity (preferring the given category), for tiles and ribbons.
function Fixtures.entriesByRarity(category: string?): { [string]: any }
	local picked = {}
	for _, entry in Fixtures.allEntries(category) do
		if not entry.isDefault and picked[entry.rarity] == nil then
			picked[entry.rarity] = entry
		end
	end
	if category then
		for rarity, entry in Fixtures.entriesByRarity(nil) do
			picked[rarity] = picked[rarity] or entry
		end
	end
	return picked
end

--> The same as an ordered list, Common -> Exclusive.
function Fixtures.rarityRow(category: string?): { any }
	local byRarity = Fixtures.entriesByRarity(category)
	local row = {}
	for _, rarity in Fixtures.Rarities do
		if byRarity[rarity] then
			table.insert(row, byRarity[rarity])
		end
	end
	return row
end

--> A Backpack-style save: the Showtime pass emotes plus one of every rarity owned.
function Fixtures.inventoryData(): any
	local owned = {}
	for _, itemId in GamePasses.Catalog.Showtime.EntitlementItemIds do
		owned[itemId] = true
	end
	for _, entry in Fixtures.rarityRow() do
		if entry.itemId then
			owned[entry.itemId] = true
		end
	end
	return { Bonks = 2450, Cosmetics = { Owned = owned, Equipped = {} } }
end

-- Lobby navigation and queues ------------------------------------------------------------------------

Fixtures.LobbyTabs = table.freeze({
	{ Id = "SplashScreen", Label = "PLAY", LayoutOrder = 1 },
	{ Id = "Shop", Label = "SHOP", LayoutOrder = 2 },
	{ Id = "Inventory", Label = "BACKPACK", LayoutOrder = 3 },
	{ Id = "Settings", Label = "SETTINGS", LayoutOrder = 4 },
})

Fixtures.QueueOptions = table.freeze({
	{ id = "Arena", title = "ARENA PVP", description = "A fast dodgeball showdown." },
	{ id = "Splashdown", title = "SPLASHDOWN", description = "Race through the obstacle course." },
})

-- Quests -------------------------------------------------------------------------------------------

local QUESTS = {
	{ questId = "catch", title = "Catch 3 dodgeballs", progress = 1, goal = 3, reward = 150 },
	{ questId = "elims", title = "Get 3 dodgeball eliminations", progress = 3, goal = 3, reward = 175 },
	{ questId = "hammer", title = "Hit 5 players with the hammer", progress = 2, goal = 5, reward = 150 },
	{ questId = "wins", title = "Win 2 matches", progress = 2, goal = 2, reward = 250 },
}

--> state: "Mixed" (in progress / claimable / claimed), "AllClaimable", "AllClaimed", "Empty".
function Fixtures.quests(state: string?): any
	local quests = {}
	if state ~= "Empty" then
		for index, quest in QUESTS do
			local done = quest.progress >= quest.goal
			local claimed = if state == "AllClaimed" then true elseif state == "AllClaimable" then false else index == 4
			table.insert(quests, {
				questId = quest.questId,
				title = quest.title,
				progress = if state == "AllClaimable" or state == "AllClaimed" then quest.goal else quest.progress,
				goal = quest.goal,
				claimed = claimed and (done or state == "AllClaimed"),
				reward = { kind = "Bonks", amount = quest.reward },
			})
		end
	end
	return { dailyKey = "story", resetAt = os.time() + 6 * 3600, quests = quests }
end

-- Daily rewards ------------------------------------------------------------------------------------

Fixtures.DailyAmounts = table.freeze({ 100, 125, 150, 200, 250, 300, 500 })

function Fixtures.daily(currentDay: number, claimedThrough: number, canClaim: boolean?): any
	local days = {}
	local claimable = if canClaim == nil then claimedThrough < currentDay else canClaim
	for day, amount in Fixtures.DailyAmounts do
		table.insert(days, {
			day = day,
			reward = { kind = "Bonks", amount = amount },
			claimed = day <= claimedThrough,
			available = claimable and day == currentDay,
			current = day == currentDay,
		})
	end
	return {
		canClaim = claimable,
		currentDay = currentDay,
		nextDay = if claimable then currentDay else math.min(currentDay + 1, #days),
		totalClaimed = claimedThrough,
		days = days,
	}
end

-- Season -------------------------------------------------------------------------------------------

--> An active season at `tier` of 30; tiers below are claimed on the free track, the current one is
--> claimable, the rest locked. hasPremium unlocks the premium track.
function Fixtures.season(options: { tier: number?, hasPremium: boolean?, active: boolean? }?): any
	local opts = options or {}
	local tier = opts.tier or 3
	local tiers = {}
	for index = 1, 8 do
		table.insert(tiers, {
			tier = index,
			unlocked = index <= tier,
			freeReward = { kind = "Bonks", amount = 100 + index * 50 },
			freeClaimed = index < tier,
			premiumReward = { kind = "Bonks", amount = 250 + index * 75 },
			premiumClaimed = opts.hasPremium == true and index < tier - 1,
		})
	end
	return {
		seasonId = "S1",
		active = opts.active ~= false,
		displayName = "SEASON 1: FIRST SPLAT",
		tier = tier,
		tierCount = 30,
		xpIntoTier = 260,
		xpForNextTier = 608,
		hasPremium = opts.hasPremium == true,
		tiers = tiers,
	}
end

function Fixtures.seasonEntries(options: { tier: number?, hasPremium: boolean? }?): { any }
	return SeasonRewardsModel.entries(Fixtures.season(options))
end

Fixtures.SeasonCard = table.freeze({
	id = "Season:S1",
	definition = { SeasonId = "S1" },
	status = "Active",
	robuxPrice = 399,
	productId = 1,
	pending = false,
})

-- Arena ballot -------------------------------------------------------------------------------------

Fixtures.Modes = table.freeze({
	{
		Id = "FFA",
		Title = "FREE-FOR-ALL",
		Description = "First to 15 eliminations wins. Everyone is a target.",
		SortOrder = 1,
	},
	{
		Id = "TDM",
		Title = "TEAM DEATHMATCH",
		Description = "First team to 40 eliminations wins. Parties stay together.",
		SortOrder = 2,
	},
	{
		Id = "Infection",
		Title = "INFECTION",
		Description = "Survive until time runs out. Eliminated survivors join the infected.",
		SortOrder = 3,
	},
})

Fixtures.Maps = table.freeze({
	{ Id = "Bowl", Title = "CANDY BOWL", ShortName = "BOWL", Accent = T.Colors.Pink },
	{ Id = "SecondMap", Title = "BAMBOO ISLE", ShortName = "ISLE", Accent = T.Colors.Lime },
	{ Id = "Long", Title = "SUPER LONG CANDY ARCHIPELAGO", ShortName = "LONG", Accent = T.Colors.Cyan },
})

--> GameModeSelect's Modes list with votes; `selected` marks the local vote.
function Fixtures.ballotModes(selected: string?, votes: { number }?): { any }
	local list = {}
	for index, mode in Fixtures.Modes do
		table.insert(list, {
			Id = mode.Id,
			Title = mode.Title,
			Description = mode.Description,
			ThumbnailId = "",
			SortOrder = mode.SortOrder,
			VoteCount = if votes then votes[index] or 0 else index,
			Selected = selected == mode.Id,
		})
	end
	return list
end

--> GameModeSelect's Maps list. count 0 -> nil (the mode-only ballot); 2 -> CANDY BOWL + BAMBOO
--> ISLE; 3 adds the long-named third map. longSecond swaps the long title onto map two.
function Fixtures.ballotMaps(count: number, selected: string?, longSecond: boolean?): { any }?
	if count <= 0 then
		return nil
	end
	local list = {}
	for index = 1, math.min(count, #Fixtures.Maps) do
		local map = Fixtures.Maps[index]
		local title = if longSecond and index == 2 then Fixtures.Maps[3].Title else map.Title
		table.insert(list, {
			Id = map.Id,
			Title = title,
			ShortName = map.ShortName,
			ThumbnailId = "",
			Accent = map.Accent,
			SortOrder = index,
			VoteCount = index,
			Selected = selected == map.Id,
		})
	end
	return list
end

function Fixtures.serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- Match HUD ----------------------------------------------------------------------------------------

--> kind: "TDM", "FFA", "Respawning", "Starting", "Infection", "Spectating", "Scoreboard".
function Fixtures.matchHUD(kind: string?): any
	local now = Fixtures.serverNow()
	local team = kind == nil or kind == "TDM" or kind == "Respawning" or kind == "Scoreboard"
	local players = Fixtures.players()
	if not team then
		for _, player in players do
			player.teamId = nil
		end
	end
	if kind == "Respawning" then
		players[1].alive = false
	end
	return MatchHUDModel.build({
		phase = if kind == "Starting" then "Starting" else "Active",
		title = if kind == "Infection" then "INFECTION" elseif team then "TEAM DEATHMATCH" else "FREE-FOR-ALL",
		timeRemaining = if kind == "Infection" then 64 else 125,
		scoreTarget = if kind == "Infection" then 0 elseif team then 40 else 15,
		scoreLabel = if kind == "Infection" then "SURVIVORS" else nil,
		teams = if team
			then { { id = "Red", score = 18 }, { id = "Blue", score = 22 } }
			elseif kind == "Infection" then { { id = "Survivors", score = 5 }, { id = "Infected", score = 3 } }
			else nil,
		teamId = if team then "Blue" elseif kind == "Infection" then "Survivors" else nil,
		score = 9,
		eligible = kind ~= "Spectating",
		alive = kind ~= "Respawning",
		respawnAt = now + 3,
		players = players,
		scoreboardOpen = kind == "Scoreboard",
	}, now)
end

-- Splashdown ---------------------------------------------------------------------------------------

--> The live course rotation, in order, as { Id, DisplayName }.
function Fixtures.courses(): { { Id: string, DisplayName: string } }
	local list = {}
	for _, id in Splashdown.CourseOrder do
		local course = Splashdown.Courses[id]
		table.insert(list, { Id = id, DisplayName = if course then course.DisplayName else string.upper(id) })
	end
	return list
end

-- Post-match ---------------------------------------------------------------------------------------

function Fixtures.postMatchScenarios(): { any }
	local DebugPostMatchData = require(Game:WaitForChild("PostMatch"):WaitForChild("DebugPostMatchData"))
	return DebugPostMatchData.scenarios()
end

-- Economy (shop view model) -----------------------------------------------------------------------

--> state: nil/"Ready", "Loading", "Refreshing", "Error", "Empty", "Purchased", "Unaffordable",
--> "Guaranteed", "Pending", "Restricted", "Unavailable". Returns view model, raw snapshot, save.
function Fixtures.economy(state: string?): (any, any, any)
	local ShopViewModel = require(Economy:WaitForChild("ShopViewModel"))
	local FeaturedRotation = require(Economy:WaitForChild("FeaturedRotation"))
	local DirectPurchase = require(Economy:WaitForChild("DirectPurchase"))
	local now = os.time()
	local offers = {}
	for _, entry in
		{
			{ itemId = "DodgeBall1", role = "RobuxCommon" },
			{ itemId = "DodgeBall10", role = "RobuxPremium" },
			{ itemId = "DodgeBall19", role = "Bonks" },
		}
	do
		local item = Cosmetics.Items[entry.itemId]
		table.insert(offers, {
			itemId = entry.itemId,
			role = entry.role,
			rarity = item.Rarity,
			displayName = item.DisplayName,
			bonksPrice = if entry.role == "Bonks"
				then DirectPurchase.priceFor(entry.itemId, Cosmetics.Items, Cosmetics.Rarities)
				else nil,
			purchased = state == "Purchased" and entry.role == "RobuxCommon",
		})
	end
	local data = {
		Bonks = if state == "Unaffordable" then 0 else 5000,
		Cosmetics = { Owned = { [Crates.EffectsCrate.ItemPool[1]] = true }, Equipped = {} },
		Crates = { Pity = { EffectsCrate = if state == "Guaranteed" then { Rare = 4, Legendary = 24 } else {} } },
	}
	local snapshot = {
		status = if state == "Error" or state == "Loading" or state == "Refreshing" then state else "Ready",
		shopState = {
			serverNow = now,
			paidRandomAllowed = state ~= "Restricted",
			paidRandomReason = if state == "Restricted" then "paid_random_restricted" else nil,
			offers = if state == "Empty" then {} else offers,
			offersExpireAt = now + 86400,
			featured = { kind = "Crate", id = "EffectsCrate" },
			featuredExpireAt = now + 604800,
			bundleExpireAt = now + 604800,
		},
		metadata = {},
		ownedPasses = {},
		pending = if state == "Pending" then { ["Crate:EffectsCrate"] = true } else {},
	}
	for _, entry in
		{
			{ definition = Products.Catalog.OfferUnlockCommon, price = 99 },
			{ definition = Products.Catalog.OfferUnlockRare, price = 199 },
			{ definition = Products.Catalog.OfferUnlockLegendary, price = 599 },
		}
	do
		snapshot.metadata[`Product:{entry.definition.Id}`] = { priceInRobux = entry.price, isForSale = true }
	end
	if state == "Unavailable" then
		for _, catalog in { Products.Catalog, GamePasses.Catalog } do
			for _, definition in catalog do
				if definition.Id then
					for _, kind in { "Product", "GamePass" } do
						snapshot.metadata[`{kind}:{definition.Id}`] = { failed = true }
					end
				end
			end
		end
	end
	local options: { [string]: any } = table.clone(snapshot)
	options.economyData = data
	options.now = now
	options.cosmetics = Cosmetics
	options.crates = Crates
	options.bundles = require(EconomyConfig:WaitForChild("Bundles"))
	options.gamePasses = GamePasses
	options.products = Products.Catalog
	options.seasons = require(Config:WaitForChild("Progression"):WaitForChild("Seasons")).Definitions
	options.shopConfig = Shop
	options.featuredRotation = FeaturedRotation
	options.crateOdds = require(Economy:WaitForChild("CrateOdds"))
	options.crateBatch = require(Economy:WaitForChild("CrateBatch"))
	return ShopViewModel.build(options), snapshot, data
end

--> A crate reveal built from the real EffectsCrate odds: every fourth pull is a dupe refunded in
--> Bonks. count limits the pulls (1 = single open, nil = every outcome).
function Fixtures.crateReveal(count: number?): any
	local model = Fixtures.economy("Ready")
	local results = {}
	local totalRefund = 0
	for index, outcome in model.byId["Crate:EffectsCrate"].odds do
		if count and index > count then
			break
		end
		local result = table.clone(outcome)
		result.isDupe = index % 4 == 0
		result.bonksRefund = if result.isDupe then outcome.bonksRefund else 0
		totalRefund += result.bonksRefund
		table.insert(results, result)
	end
	return { results = results, totalRefund = totalRefund }
end

--> An inert ShopClient over a snapshot: reads work, every purchase returns false, "preview_only".
function Fixtures.shopClient(snapshot: any): any
	local function unavailable()
		return false, "preview_only"
	end
	return {
		snapshot = function()
			return snapshot
		end,
		subscribe = function()
			return noop
		end,
		refresh = function()
			return true
		end,
		clearGrant = noop,
		clearReveal = noop,
		openCrate = unavailable,
		purchaseCosmetic = unavailable,
		promptProduct = unavailable,
		promptGamePass = unavailable,
	}
end

-- Party --------------------------------------------------------------------------------------------

function Fixtures.partySnapshot(memberCount: number?, leaderUserId: number?): any
	local members = {}
	for index = 1, memberCount or 0 do
		local player = Fixtures.Players[index]
		table.insert(members, {
			userId = player.userId,
			name = player.name,
			displayName = player.displayName,
		})
	end
	return {
		partyId = "story",
		joinCode = "123456",
		revision = 1,
		leaderUserId = leaderUserId or Fixtures.LocalUserId,
		phase = "Lobby",
		members = members,
	}
end

--> An inert PartyClient (method-call style, as LobbyApp uses it).
function Fixtures.partyClient(snapshot: any): any
	local client = { ErrorMessages = {}, JoinCodeErrorMessages = {} }
	function client:getSnapshot()
		return snapshot
	end
	function client:isBusy()
		return false
	end
	function client:getTeleportStatus()
		return nil
	end
	function client:subscribe(callback)
		callback(snapshot, nil, "Subscribed")
		return noop
	end
	function client:subscribeErrors(_callback)
		return noop
	end
	function client:joinByCode(_code)
		return { ok = false, reason = "preview_only" }
	end
	client.toggleMatchmaking = noop
	client.setQueue = noop
	client.promptInvite = noop
	client.kick = noop
	client.retryInitialization = noop
	return client
end

--> A read-only store projection (DailyRewardStore / SeasonStore / QuestStore shape).
function Fixtures.projection(state: any): any
	return {
		snapshot = function()
			return state
		end,
		subscribe = function()
			return noop
		end,
		claim = function()
			return nil, "preview_only"
		end,
		claimAll = function()
			return nil, "preview_only"
		end,
	}
end

return Fixtures
