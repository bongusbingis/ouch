--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local ReturnPayload = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Matchmaking")
		:WaitForChild("ReturnPayload")
)
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local MatchService = require(script.Parent.MatchService)
local Env = require(script.Parent.Parent.Env)

-- Sends lobby-originated players back to their party once the results screen has
-- played out. The decision is per player, not per server: anyone who arrived
-- through matchmaking is returned with a payload naming their party, and anyone
-- who joined the arena directly is left alone so the vote reopens for them.
--
-- That split is what makes removing the lobby a configuration change rather than
-- a rewrite: with nobody arriving through matchmaking, nothing here ever fires.

local ArenaReturnService = {}

local started = false
local returning: { [Player]: boolean } = {}

local function partyGroups(): { [string]: { Player } }
	local groups: { [string]: { Player } } = {}
	for _, player in Players:GetPlayers() do
		if returning[player] or not ArenaSessionService.isAdmitted(player) then
			continue
		end
		local partyId = ArenaSessionService.partyIdFor(player)
		if partyId == nil then
			continue
		end
		local group = groups[partyId]
		if group == nil then
			group = {}
			groups[partyId] = group
		end
		table.insert(group, player)
	end
	return groups
end

local function sendGroup(partyId: string, matchId: string, players: { Player })
	local memberUserIds = {}
	for _, player in players do
		table.insert(memberUserIds, player.UserId)
		returning[player] = true
	end

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(ReturnPayload.build(partyId, matchId, memberUserIds))

	-- One call per party so the group lands together; a failure leaves them in
	-- the arena, where the vote reopens as it would for a direct join.
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, Env.LobbyPlaceId, players, options)
	if not ok then
		warn(`[ArenaReturnService] Could not return party "{partyId}": {err}`)
		for _, player in players do
			returning[player] = nil
		end
	end
end

local function returnParties()
	local session = ArenaSessionService.getSnapshot()
	if session == nil then
		return
	end
	for partyId, players in partyGroups() do
		sendGroup(partyId, session.matchId, players)
	end
end

function ArenaReturnService.start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(function(player)
		returning[player] = nil
	end)

	TeleportService.TeleportInitFailed:Connect(function(player)
		returning[player] = nil
	end)

	MatchService.onEvent(function(event)
		if event.kind == "MatchReset" then
			returnParties()
		end
	end)
end

return ArenaReturnService
