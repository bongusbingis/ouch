-- Name: PostMatchClient.luau
-- Author: Jack C.
-- Description: Arena adapter for authoritative post-match result packets, replay and return actions, and combat-cursor ownership while the results screen is up.
-- Created: 2026-08-25

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local PostMatchResult = require(Shared:WaitForChild("Game"):WaitForChild("PostMatch"):WaitForChild("PostMatchResult"))
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
local ArenaMenuClient = require(script.Parent.ArenaMenuClient)

local PostMatchClient = {}

export type Snapshot = {
	visible: boolean,
	result: PostMatchResult.PlayerResult?,
	status: any?,
	requesting: boolean,
	error: string?,
}

local CURSOR_REASON = "PostMatch"
local started = false
local state: Snapshot = {
	visible = false,
	result = nil,
	status = nil,
	requesting = false,
	error = nil,
}
local listeners: { (Snapshot) -> () } = {}
local connections: { RBXScriptConnection } = {}
local matchState: Folder? = nil
local phaseConnection: RBXScriptConnection? = nil
local requestGeneration = 0
local pendingStatus: any? = nil
local awaitingResultsPhase = false
local CLEAR = table.freeze({})

local function publish(changes: { [string]: any })
	local nextState = table.clone(state)
	local changed = false
	for key, value in changes do
		local nextValue = if value == CLEAR then nil else value
		if nextState[key] ~= nextValue then
			nextState[key] = nextValue
			changed = true
		end
	end
	if not changed then
		return
	end
	state = nextState :: Snapshot
	for _, listener in table.clone(listeners) do
		local ok, err = pcall(listener, state)
		if not ok then
			warn(`[PostMatchClient] listener failed: {err}`)
		end
	end
end

local function setVisible(visible: boolean)
	if visible then
		ArenaMenuClient.close()
		Combat.requestCursor(CURSOR_REASON)
	else
		Combat.releaseCursor(CURSOR_REASON)
	end
	publish({ visible = visible })
end

local function syncPhase()
	local phase = if matchState then matchState:GetAttribute("phase") else nil
	if phase == "Results" and state.result ~= nil then
		awaitingResultsPhase = false
		setVisible(true)
	elseif phase ~= "Results" then
		setVisible(false)
		if awaitingResultsPhase and (phase == nil or phase == "Active") then
			return
		end
		if phase == "Intermission" or phase == "Starting" or phase == "Active" or phase == "Idle" then
			requestGeneration += 1
			awaitingResultsPhase = false
			pendingStatus = nil
			publish({ result = CLEAR, status = CLEAR, requesting = false, error = CLEAR })
		end
	end
end

local function attachMatchState(folder: Folder)
	if phaseConnection then
		phaseConnection:Disconnect()
	end
	matchState = folder
	phaseConnection = folder:GetAttributeChangedSignal("phase"):Connect(syncPhase)
	syncPhase()
end

local function receiveResult(payload: any)
	local result, reason = PostMatchResult.parse(payload)
	if result == nil then
		warn(`[PostMatchClient] Ignored invalid result packet: {reason or "invalid_payload"}`)
		return
	end
	if result.endsAt <= Workspace:GetServerTimeNow() then
		return
	end
	local phase = if matchState then matchState:GetAttribute("phase") else nil
	if phase ~= nil and phase ~= "Active" and phase ~= "Results" then
		return
	end
	local currentResult = state.result
	if currentResult and currentResult.resultId == result.resultId then
		publish({ result = result })
		if phase == "Results" then
			awaitingResultsPhase = false
			setVisible(true)
		end
		return
	end
	requestGeneration += 1
	awaitingResultsPhase = phase ~= "Results"
	local status = if pendingStatus and pendingStatus.resultId == result.resultId then pendingStatus else nil
	pendingStatus = nil
	publish({ result = result, status = status or CLEAR, requesting = false, error = CLEAR })
	if phase == "Results" then
		setVisible(true)
	else
		setVisible(false)
	end
end

local function receiveStatus(status: any)
	local result = state.result
	if result == nil then
		if typeof(status) == "table" and typeof(status.resultId) == "string" then
			pendingStatus = status
		end
		return
	end
	if typeof(status) ~= "table" or status.resultId ~= result.resultId or typeof(status.revision) ~= "number" then
		return
	end
	local current = state.status
	if current and typeof(current.revision) == "number" and current.revision > status.revision then
		return
	end
	publish({ status = status, requesting = false, error = status.error or CLEAR })
end

function PostMatchClient.start()
	if started then
		return
	end
	started = true
	table.insert(connections, Network.on("PostMatchResult", receiveResult))
	table.insert(connections, Network.on("PostMatchStatus", receiveStatus))

	local existing = ReplicatedStorage:FindFirstChild("MatchState")
	if existing and existing:IsA("Folder") then
		attachMatchState(existing)
	end
	table.insert(
		connections,
		ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == "MatchState" and child:IsA("Folder") then
				attachMatchState(child)
			end
		end)
	)
end

function PostMatchClient.getSnapshot(): Snapshot
	return state
end

function PostMatchClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	PostMatchClient.start()
	table.insert(listeners, listener)
	listener(state)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function PostMatchClient.request(action: "PlayAgain" | "CancelPlayAgain" | "ReturnToLobby")
	local result = state.result
	if result == nil or state.requesting then
		return
	end
	requestGeneration += 1
	local generation = requestGeneration
	publish({ requesting = true, error = CLEAR })
	task.spawn(function()
		local ok, response = pcall(Network.call, "PostMatchRequest", action, result.resultId)
		if generation ~= requestGeneration or not started then
			return
		end
		if not ok or typeof(response) ~= "table" then
			publish({ requesting = false, error = "request_failed" })
			return
		end
		if response.status then
			receiveStatus(response.status)
		end
		if response.ok ~= true then
			publish({ requesting = false, error = response.error or "request_failed" })
		elseif response.status == nil then
			publish({ requesting = false })
		end
	end)
end

function PostMatchClient.playAgain()
	local status = state.status
	PostMatchClient.request(if status and status.state == "PlayAgain" then "CancelPlayAgain" else "PlayAgain")
end

function PostMatchClient.returnToLobby()
	PostMatchClient.request("ReturnToLobby")
end

function PostMatchClient.destroy()
	requestGeneration += 1
	if phaseConnection then
		phaseConnection:Disconnect()
		phaseConnection = nil
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(listeners)
	Combat.releaseCursor(CURSOR_REASON)
	matchState = nil
	pendingStatus = nil
	awaitingResultsPhase = false
	state = {
		visible = false,
		result = nil,
		status = nil,
		requesting = false,
		error = nil,
	}
	started = false
end

return PostMatchClient
