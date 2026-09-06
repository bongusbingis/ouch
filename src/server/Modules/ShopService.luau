-- Name: ShopService.luau
-- Author: Jack C.
-- Description: Sole owner of the stored shop state: draws each player's rotating offers deterministically for the current period, persists them so a purchase cannot reshuffle the rest, and answers whether an item is currently purchasable.
-- Created: 2026-08-22

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Shop"))
local Bundles = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Bundles"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Economy = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy")
local ShopRotation = require(Economy:WaitForChild("ShopRotation"))
local FeaturedRotation = require(Economy:WaitForChild("FeaturedRotation"))
local DirectPurchase = require(Economy:WaitForChild("DirectPurchase"))
local PlayerData = require(script.Parent.PlayerData)
local PaidRandomPolicyService = require(script.Parent.PaidRandomPolicyService)

local ShopService = {}

local SWEEP_SECONDS = 60

local started = false
local sweeping = false

local activePlayers: any = Players
local activePlayerData: any = PlayerData
local activeNetwork: any = Network
local activeTime: () -> number = os.time
local activePaidRandomPolicy: any = PaidRandomPolicyService

local function rotationPool(): { string }
	return ShopRotation.pool(Cosmetics.Items, Shop.Rotation.Categories)
end

function ShopService.ensure(player: Player): any?
	local data = activePlayerData.get(player)
	if data == nil then
		return nil
	end
	local bucket = FeaturedRotation.periodIndex(Shop.Rotation.RotationSeconds, activeTime())
	if data.Shop ~= nil and data.Shop.Bucket == bucket and #data.Shop.Offers > 0 then
		return data
	end
	data.Shop = {
		Bucket = bucket,
		Offers = ShopRotation.draw(
			player.UserId,
			bucket,
			rotationPool(),
			data.Cosmetics.Owned,
			Shop.Rotation.OfferCount
		),
	}
	return data
end

local function offersFrom(data: any?): { string }
	if data == nil or data.Shop == nil then
		return {}
	end
	local offers = {}
	for _, itemId in data.Shop.Offers do
		table.insert(offers, itemId)
	end
	return offers
end

function ShopService.offersFor(player: Player): { string }
	return offersFrom(ShopService.ensure(player))
end

function ShopService.isPurchasable(player: Player, itemId: string): boolean
	local item = Cosmetics.Items[itemId]
	if item == nil then
		return false
	end
	if not table.find(Shop.Rotation.Categories, item.Category) then
		return true
	end
	return table.find(ShopService.offersFor(player), itemId) ~= nil
end

function ShopService.stateFor(player: Player): any
	local allowed, policyReason = activePaidRandomPolicy.canReceivePaidRandom(player)
	local now = activeTime()
	local data = ShopService.ensure(player)
	local owned = if data then data.Cosmetics.Owned else {}
	local storedOffers = offersFrom(data)

	local offers = {}
	for _, itemId in storedOffers do
		local item = Cosmetics.Items[itemId]
		if item ~= nil then
			table.insert(offers, {
				itemId = itemId,
				rarity = item.Rarity,
				displayName = item.DisplayName,
				bonksPrice = DirectPurchase.priceFor(itemId, Cosmetics.Items, Cosmetics.Rarities),
				owned = owned[itemId] == true,
			})
		end
	end

	local bundleEntry = FeaturedRotation.select({
		RotationSeconds = Shop.Bundle.RotationSeconds,
		DiscountPercent = 0,
		Rotation = Shop.Bundle.Rotation,
	}, now)
	local bundleId = if bundleEntry then bundleEntry.id else nil
	local bundle = if bundleId then Bundles.Catalog[bundleId] else nil

	local featured = FeaturedRotation.select(Shop.Featured, now)

	return {
		serverNow = now,
		paidRandomAllowed = allowed,
		paidRandomReason = policyReason,
		offers = offers,
		offersExpireAt = FeaturedRotation.nextRotationAt(Shop.Rotation.RotationSeconds, now),
		featured = if featured then { kind = featured.kind, id = featured.id } else nil,
		featuredExpireAt = FeaturedRotation.nextRotationAt(Shop.Featured.RotationSeconds, now),
		bundle = if bundle and bundleId
			then {
				bundleId = bundleId,
				displayName = bundle.DisplayName,
				description = bundle.Description,
				status = bundle.CatalogStatus,
				itemIds = bundle.ItemIds,
			}
			else nil,
		bundleExpireAt = FeaturedRotation.nextRotationAt(Shop.Bundle.RotationSeconds, now),
	}
end

function ShopService.fireState(player: Player)
	activeNetwork.fire("ShopStateChanged", player, ShopService.stateFor(player))
end

local function sweep()
	for _, player in activePlayers:GetPlayers() do
		local before = activePlayerData.get(player)
		local storedBucket = if before and before.Shop then before.Shop.Bucket else nil
		local data = ShopService.ensure(player)
		if data ~= nil and storedBucket ~= nil and data.Shop.Bucket ~= storedBucket then
			ShopService.fireState(player)
		end
	end
end

export type StartOptions = {
	players: any?,
	playerData: any?,
	paidRandomPolicy: any?,
	network: any?,
	time: (() -> number)?,
	runAsync: ((() -> ()) -> ())?,
	sweepSeconds: number?,
}

function ShopService.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activePlayers = if options and options.players then options.players else Players
	activePlayerData = if options and options.playerData then options.playerData else PlayerData
	activeNetwork = if options and options.network then options.network else Network
	activeTime = if options and options.time then options.time else os.time
	activePaidRandomPolicy = if options and options.paidRandomPolicy
		then options.paidRandomPolicy
		else PaidRandomPolicyService
	local runAsync = if options and options.runAsync then options.runAsync else task.spawn
	local sweepSeconds = if options and options.sweepSeconds then options.sweepSeconds else SWEEP_SECONDS

	activeNetwork.handleProtected("GetShopState", { rateLimit = 4 }, function(player)
		return ShopService.stateFor(player)
	end)

	if sweepSeconds > 0 then
		sweeping = true
		runAsync(function()
			while sweeping do
				task.wait(sweepSeconds)
				if sweeping then
					sweep()
				end
			end
		end)
	end
end

function ShopService._resetForTest()
	started = false
	sweeping = false
	activePlayers = Players
	activePlayerData = PlayerData
	activeNetwork = Network
	activeTime = os.time
	activePaidRandomPolicy = PaidRandomPolicyService
end

return ShopService
