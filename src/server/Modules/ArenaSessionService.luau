--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local TeleportPayload = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Matchmaking")
		:WaitForChild("TeleportPayload")
)

local ArenaSessionService = {}

export type Snapshot = {
	matchId: string,
	expectedPlayerCount: number,
	modeOptions: { string },
	arrivedPlayerCount: number,
}

export type Admission = "Direct" | "Matched" | "Rejected"

type Session = {
	matchId: string,
	expectedPlayerCount: number,
	modeOptions: { string },
}

local session: Session? = nil
local partyByUserId: { [number]: string } = {}
local admissionByUserId: { [number]: Admission } = {}
local readyByUserId: { [number]: boolean } = {}
local readyListeners: { (Player) -> () } = {}
local started = false

local READY_ATTRIBUTE = "ArenaReady"

local function sameOptions(first: { string }, second: { string }): boolean
	if #first ~= #second then
		return false
	end
	for index, option in first do
		if second[index] ~= option then
			return false
		end
	end
	return true
end

local function arrivedPlayerCount(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if admissionByUserId[player.UserId] == "Matched" and partyByUserId[player.UserId] ~= nil then
			count += 1
		end
	end
	return count
end

-- A client reports ready once its UI exists, so the mode vote is not spent
-- before arriving players can see it. Readiness lives here beside admission
-- because both are per-player arrival facts, and it is projected as an attribute
-- so any client can read it the same way it reads ArenaAdmission.
local function setReady(player: Player)
	if readyByUserId[player.UserId] then
		return
	end
	readyByUserId[player.UserId] = true
	player:SetAttribute(READY_ATTRIBUTE, true)
	for _, listener in readyListeners do
		local ok, err = pcall(listener, player)
		if not ok then
			warn(`[ArenaSessionService] ready listener error: {err}`)
		end
	end
end

function ArenaSessionService.isReady(player: Player): boolean
	return readyByUserId[player.UserId] == true
end

function ArenaSessionService.onReady(listener: (Player) -> ())
	table.insert(readyListeners, listener)
end

local function setAdmission(player: Player, admission: Admission)
	admissionByUserId[player.UserId] = admission
	player:SetAttribute("ArenaAdmission", admission)
end

local function receive(player: Player)
	local success, joinData = pcall(player.GetJoinData, player)
	if not success then
		setAdmission(player, "Rejected")
		warn(`[ArenaSessionService] Could not read join data for {player.Name}`)
		return
	end

	local rawPayload = joinData.TeleportData
	if rawPayload == nil then
		if partyByUserId[player.UserId] ~= nil then
			setAdmission(player, "Matched")
		elseif admissionByUserId[player.UserId] == "Rejected" then
			setAdmission(player, "Rejected")
		else
			setAdmission(player, "Direct")
		end
		return
	end
	local payload, payloadError = TeleportPayload.parse(rawPayload)
	if not payload then
		setAdmission(player, "Rejected")
		warn(`[ArenaSessionService] Rejected teleport data for {player.Name}: {payloadError or "invalid_payload"}`)
		return
	end

	if session == nil then
		session = {
			matchId = payload.matchId,
			expectedPlayerCount = payload.expectedPlayerCount,
			modeOptions = table.clone(payload.modeSelection.options),
		}
	elseif
		session.matchId ~= payload.matchId
		or session.expectedPlayerCount ~= payload.expectedPlayerCount
		or not sameOptions(session.modeOptions, payload.modeSelection.options)
	then
		setAdmission(player, "Rejected")
		warn(`[ArenaSessionService] Rejected mismatched matchmaking session for {player.Name}`)
		return
	end

	partyByUserId[player.UserId] = payload.partyId
	setAdmission(player, "Matched")
end

function ArenaSessionService.start()
	if started then
		return
	end
	started = true

	Network.handleProtected("ArenaClientReady", { rateLimit = 4 }, setReady)

	Players.PlayerAdded:Connect(receive)
	Players.PlayerRemoving:Connect(function(player)
		readyByUserId[player.UserId] = nil
	end)
	for _, player in Players:GetPlayers() do
		receive(player)
	end
end

function ArenaSessionService.getSnapshot(): Snapshot?
	if session == nil then
		return nil
	end
	return {
		matchId = session.matchId,
		expectedPlayerCount = session.expectedPlayerCount,
		modeOptions = table.clone(session.modeOptions),
		arrivedPlayerCount = arrivedPlayerCount(),
	}
end

function ArenaSessionService.partyIdFor(player: Player): string?
	return partyByUserId[player.UserId]
end

function ArenaSessionService.isAdmitted(player: Player): boolean
	local admission = admissionByUserId[player.UserId]
	return admission == "Direct" or admission == "Matched"
end

return ArenaSessionService
