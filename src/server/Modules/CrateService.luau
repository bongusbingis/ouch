--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local CrateRolls = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CrateRolls")
)
local CosmeticsService = require(script.Parent.CosmeticsService)
local PlayerData = require(script.Parent.PlayerData)

-- Crate opening: Cash path via the OpenCrate remote, Robux path via
-- MonetizationService receipts. Both share one roll-and-grant routine; every
-- open fires CrateOpened to the buyer.
--
-- TODO(ui): the crate-reveal animation subscribes to the CrateOpened remote
-- ({ crateId, itemId, rarity, isDupe, cashRefund }).

local CrateService = {}

local rng = Random.new()

type OpenResult = {
	crateId: string,
	itemId: string,
	rarity: string,
	isDupe: boolean,
	cashRefund: number,
}

local function rollAndGrant(player: Player, crateId: string): OpenResult?
	local crate = Crates[crateId]
	local data = PlayerData.get(player)
	if crate == nil or data == nil then
		return nil
	end

	local result = CrateRolls.roll(crate, Cosmetics.Items, Cosmetics.Rarities, data.Cosmetics.Owned, rng)
	if result.isDupe then
		data.Cash += result.cashRefund
	else
		CosmeticsService.grant(player, result.itemId)
	end

	local payload: OpenResult = {
		crateId = crateId,
		itemId = result.itemId,
		rarity = result.rarity,
		isDupe = result.isDupe,
		cashRefund = result.cashRefund,
	}
	Network.fire("CrateOpened", player, payload)
	return payload
end

function CrateService.openWithCash(player: Player, crateId: string): (OpenResult?, string?)
	local crate = Crates[crateId]
	if crate == nil or crate.CashPrice == nil then
		return nil, "invalid_crate"
	end
	local data = PlayerData.get(player)
	if data == nil then
		return nil, "no_profile"
	end
	if data.Cash < crate.CashPrice then
		return nil, "insufficient_cash"
	end

	data.Cash -= crate.CashPrice
	return rollAndGrant(player, crateId), nil
end

function CrateService.openFromReceipt(player: Player, crateId: string): boolean
	return rollAndGrant(player, crateId) ~= nil
end

function CrateService.start()
	Network.handleProtected("OpenCrate", {
		rateLimit = 2,
		validate = function(_player, crateId)
			if typeof(crateId) ~= "string" then
				return false, "crateId must be a string"
			end
			return true
		end,
	}, function(player, crateId)
		return CrateService.openWithCash(player, crateId)
	end)
end

return CrateService
