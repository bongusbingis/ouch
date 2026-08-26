-- Name: EntitlementService.luau
-- Author: Jack C.
-- Description: Caches which game passes each player owns and derives the best applicable XP and Bonks multipliers from them, exposing a readiness signal so awards never apply a half-known set.
-- Created: 2026-08-12

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePasses = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GamePasses"))
local Boosts = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("Boosts")
)

local EntitlementService = {}

type StartOptions = {
	players: any?,
	gamePasses: any?,
	wait: ((seconds: number) -> ())?,
}

local READY_ATTEMPTS = 40
local RETRY_SECONDS = 0.05

local started = false
local activePlayers: any = Players
local activeGamePasses: any = GamePasses
local activeWait: (seconds: number) -> () = task.wait
local ownedByUserId: { [number]: { [string]: boolean } } = {}
local playerRemovingConnection: any = nil

local function boostKeys(): { string }
	local keys = {}
	for key, definition in activeGamePasses.Catalog do
		if definition.Boosts ~= nil then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

function EntitlementService.setOwnership(player: Player, passKey: string, owned: boolean)
	local entries = ownedByUserId[player.UserId]
	if entries == nil then
		entries = {}
		ownedByUserId[player.UserId] = entries
	end
	entries[passKey] = owned
end

function EntitlementService.has(player: Player, passKey: string): boolean
	local entries = ownedByUserId[player.UserId]
	return entries ~= nil and entries[passKey] == true
end

function EntitlementService.ownsAny(player: Player): boolean
	local entries = ownedByUserId[player.UserId]
	if entries == nil then
		return false
	end
	for _, owned in entries do
		if owned then
			return true
		end
	end
	return false
end

function EntitlementService.isReady(player: Player): boolean
	local entries = ownedByUserId[player.UserId]
	if entries == nil then
		return false
	end
	for _, key in boostKeys() do
		if entries[key] == nil then
			return false
		end
	end
	return true
end

function EntitlementService.awaitReady(player: Player, timeoutSeconds: number): boolean
	if EntitlementService.isReady(player) then
		return true
	end
	local attempts = math.max(1, math.min(READY_ATTEMPTS, math.ceil(timeoutSeconds / RETRY_SECONDS)))
	for _ = 1, attempts do
		if player.Parent == nil then
			return false
		end
		activeWait(RETRY_SECONDS)
		if EntitlementService.isReady(player) then
			return true
		end
	end
	return false
end

function EntitlementService.multipliers(player: Player): Boosts.Multipliers
	local entries = ownedByUserId[player.UserId] or {}
	return Boosts.multipliers(activeGamePasses.Catalog, entries)
end

function EntitlementService.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activePlayers = if options and options.players then options.players else Players
	activeGamePasses = if options and options.gamePasses then options.gamePasses else GamePasses
	activeWait = if options and options.wait then options.wait else task.wait
	playerRemovingConnection = activePlayers.PlayerRemoving:Connect(function(player)
		ownedByUserId[player.UserId] = nil
	end)
end

function EntitlementService._resetForTest()
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
	end
	started = false
	activePlayers = Players
	activeGamePasses = GamePasses
	activeWait = task.wait
	playerRemovingConnection = nil
	table.clear(ownedByUserId)
end

return EntitlementService
