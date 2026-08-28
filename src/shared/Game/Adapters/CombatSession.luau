-- Name: CombatSession.luau
-- Author: Jack C.
-- Description: The single owner of whether combat is live for a player in this place, projected from the server host onto one player attribute so every client module reads the same answer.
-- Created: 2026-08-27

--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CombatSession = {}

-- The server host decides; the client only ever reads this projection. Keeping
-- the answer in one attribute is what lets the same combat modules run in the
-- arena (a match) and in the lobby (onboarding) without either knowing the
-- other's rules.
CombatSession.Attribute = "CombatLive"

export type Host = {
	isParticipant: (player: Player) -> boolean,
	isLive: () -> boolean,
}

local IS_SERVER = RunService:IsServer()

local host: Host? = nil
local stamped: { [Player]: boolean } = {}

local function project(player: Player, value: boolean)
	if stamped[player] == value then
		return
	end
	stamped[player] = value
	player:SetAttribute(CombatSession.Attribute, value)
end

function CombatSession.setHost(value: Host)
	assert(IS_SERVER, "[CombatSession] only the server installs a host")
	host = value
end

function CombatSession.hasHost(): boolean
	return host ~= nil
end

function CombatSession.isLive(player: Player?): boolean
	if IS_SERVER then
		local resolved = host
		if resolved == nil then
			return false
		end
		if player == nil then
			return resolved.isLive()
		end
		return resolved.isLive() and resolved.isParticipant(player :: Player)
	end
	local subject = player or Players.LocalPlayer
	return subject ~= nil and subject:GetAttribute(CombatSession.Attribute) == true
end

-- Called once per simulation step by the adapter, so the projection can never
-- drift from the host's answer by more than a tick.
function CombatSession.refresh()
	local resolved = host
	if resolved == nil then
		return
	end
	local live = resolved.isLive()
	for _, player in Players:GetPlayers() do
		project(player, live and resolved.isParticipant(player))
	end
end

function CombatSession.forget(player: Player)
	stamped[player] = nil
end

function CombatSession.observeLocal(listener: (boolean) -> ()): () -> ()
	assert(not IS_SERVER, "[CombatSession] observeLocal is a client API")
	local player = Players.LocalPlayer
	local connection = player:GetAttributeChangedSignal(CombatSession.Attribute):Connect(function()
		listener(CombatSession.isLive())
	end)
	listener(CombatSession.isLive())
	return function()
		connection:Disconnect()
	end
end

return CombatSession
