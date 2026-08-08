--!strict

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Products"))

-- Owns the server cache of Roblox's per-player paid-random-item policy and
-- gates Cash crates only when Cash can be purchased with Robux.

type StartOptions = {
	players: any?,
	policyService: any?,
	products: any?,
}

local PaidRandomPolicyService = {}

local started = false
local activePlayers: any = Players
local activePolicyService: any = PolicyService
local activeProducts: any = Products
local allowedByPlayer: { [Player]: boolean } = {}
local playerRemovingConnection: any = nil

local function hasPaidCash(): boolean
	for _, definition in activeProducts.Catalog do
		if definition.Enabled and definition.Type == "Cash" then
			return true
		end
	end
	return false
end

function PaidRandomPolicyService.canOpenCashCrate(player: Player): (boolean, string?)
	if not hasPaidCash() then
		return true, nil
	end
	local cached = allowedByPlayer[player]
	if cached ~= nil then
		return cached, if cached then nil else "paid_random_restricted"
	end
	local ok, policy = pcall(function()
		return activePolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if not ok or type(policy) ~= "table" then
		warn(`[PaidRandomPolicyService] policy lookup failed for {player.Name}: {policy}`)
		return false, "policy_unavailable"
	end
	local allowed = policy.ArePaidRandomItemsRestricted ~= true
	allowedByPlayer[player] = allowed
	return allowed, if allowed then nil else "paid_random_restricted"
end

function PaidRandomPolicyService.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activePlayers = if options and options.players then options.players else Players
	activePolicyService = if options and options.policyService then options.policyService else PolicyService
	activeProducts = if options and options.products then options.products else Products
	playerRemovingConnection = activePlayers.PlayerRemoving:Connect(function(player)
		allowedByPlayer[player] = nil
	end)
end

function PaidRandomPolicyService._resetForTest()
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
	end
	started = false
	activePlayers = Players
	activePolicyService = PolicyService
	activeProducts = Products
	table.clear(allowedByPlayer)
	playerRemovingConnection = nil
end

return PaidRandomPolicyService
