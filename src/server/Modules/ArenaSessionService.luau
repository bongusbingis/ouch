--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local started = false

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

	Players.PlayerAdded:Connect(receive)
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
