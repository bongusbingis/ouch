-- Description: Decides whether a player may be offered paid random items, so restricted regions and accounts see crates as preview-only rather than purchasable.

--!strict

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
type StartOptions = {
	players: any?,
	policyService: any?,
	products: any?,
	clock: (() -> number)?,
}

local PaidRandomPolicyService = {}

local started = false
local activePlayers: any = Players
local activePolicyService: any = PolicyService
local activeClock: () -> number = os.clock
local allowedByPlayer: { [Player]: boolean } = {}
local pendingByPlayer: { [Player]: {} } = {}
local retryAtByPlayer: { [Player]: number } = {}
local playerRemovingConnection: any = nil
local RETRY_SECONDS = 5

function PaidRandomPolicyService.canReceivePaidRandom(player: Player): (boolean, string?)
	-- Bonks are pooled with purchased and paid-boosted earnings. Hiding today's
	-- offers does not erase paid balances or outstanding crate receipts.
	local cached = allowedByPlayer[player]
	if cached ~= nil then
		return cached, if cached then nil else "paid_random_restricted"
	end
	if pendingByPlayer[player] ~= nil or activeClock() < (retryAtByPlayer[player] or 0) then
		return false, "policy_unavailable"
	end
	local request = {}
	pendingByPlayer[player] = request
	local ok, policy = pcall(function()
		return activePolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	-- PlayerRemoving invalidates an in-flight result; it cannot repopulate cache.
	if pendingByPlayer[player] ~= request then
		return false, "policy_unavailable"
	end
	pendingByPlayer[player] = nil
	if not ok or type(policy) ~= "table" or type(policy.ArePaidRandomItemsRestricted) ~= "boolean" then
		retryAtByPlayer[player] = activeClock() + RETRY_SECONDS
		warn(`[PaidRandomPolicyService] policy lookup failed for {player.Name}: {policy}`)
		return false, "policy_unavailable"
	end
	retryAtByPlayer[player] = nil
	local allowed = policy.ArePaidRandomItemsRestricted == false
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
	activeClock = if options and options.clock then options.clock else os.clock
	playerRemovingConnection = activePlayers.PlayerRemoving:Connect(function(player)
		allowedByPlayer[player] = nil
		pendingByPlayer[player] = nil
		retryAtByPlayer[player] = nil
	end)
end

function PaidRandomPolicyService._resetForTest()
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
	end
	started = false
	activePlayers = Players
	activePolicyService = PolicyService
	activeClock = os.clock
	table.clear(allowedByPlayer)
	table.clear(pendingByPlayer)
	table.clear(retryAtByPlayer)
	playerRemovingConnection = nil
end

return PaidRandomPolicyService
