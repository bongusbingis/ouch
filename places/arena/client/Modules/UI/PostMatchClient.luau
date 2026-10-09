-- Description: Arena adapter for authoritative post-match result packets, replay and return actions, and combat-cursor ownership while the results screen is up.

--!strict

local Listeners = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Util")
		:WaitForChild("Listeners")
)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ClientRequest = require(Shared:WaitForChild("Game"):WaitForChild("Data"):WaitForChild("ClientRequest"))
local PostMatchResult = require(Shared:WaitForChild("Game"):WaitForChild("PostMatch"):WaitForChild("PostMatchResult"))
local CombatMenuClient = require(Shared:WaitForChild("UI"):WaitForChild("Services"):WaitForChild("CombatMenuClient"))
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local PostMatchClient = {}

export type Action = "PlayAgain" | "CancelPlayAgain" | "ReturnToLobby" | "LeaveParty" | "FindMatch"

export type Snapshot = {
	visible: boolean,
	result: PostMatchResult.PlayerResult?,
	status: any?,
	requesting: boolean,
	pendingAction: Action?,
	error: string?,
	departing: boolean,
}

local CURSOR_REASON = "PostMatch"
local started = false
local state: Snapshot = {
	visible = false,
	result = nil,
	status = nil,
	requesting = false,
	pendingAction = nil,
	error = nil,
	departing = false,
}
local listeners: Listeners.Collection<Snapshot> = Listeners.new("PostMatchClient", true, "listener failed")
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
	listeners.emitWith(function(callback)
		callback(state)
	end)
end

local function setVisible(visible: boolean)
	if visible then
		CombatMenuClient.close()
		Combat.requestCursor(CURSOR_REASON)
	else
		Combat.releaseCursor(CURSOR_REASON)
	end
	publish({ visible = visible })
end

-- A player whose party is heading to the lobby keeps the results up after the
-- countdown, until the teleport screen takes over or they choose to stay; the
-- round-eligibility attribute flips the moment they stay.
local function lobbyBound(): boolean
	local status = state.status
	if status == nil then
		return false
	end
	return status.selfReturning == true or status.state == "Returning" or status.nextDestination == "Lobby"
end

local function syncPhase()
	local phase = if matchState then matchState:GetAttribute("phase") else nil
	if phase == "Results" and state.result ~= nil then
		awaitingResultsPhase = false
		publish({ departing = false })
		setVisible(true)
		return
	end
	if
		(phase == "Intermission" or phase == "Idle")
		and state.result ~= nil
		and lobbyBound()
		and Players.LocalPlayer:GetAttribute("ArenaRoundEligible") ~= true
	then
		publish({ departing = true })
		setVisible(true)
		return
	end
	setVisible(false)
	publish({ departing = false })
	if awaitingResultsPhase and (phase == nil or phase == "Active") then
		return
	end
	if phase == "Intermission" or phase == "Starting" or phase == "Active" or phase == "Idle" then
		requestGeneration += 1
		awaitingResultsPhase = false
		pendingStatus = nil
		publish({ result = CLEAR, status = CLEAR, requesting = false, pendingAction = CLEAR, error = CLEAR })
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
	publish({ result = result, status = status or CLEAR, requesting = false, pendingAction = CLEAR, error = CLEAR })
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
	publish({ status = status, requesting = false, pendingAction = CLEAR, error = status.error or CLEAR })
end

function PostMatchClient.start()
	if started then
		return
	end
	started = true
	table.insert(connections, Network.on("PostMatchResult", receiveResult))
	table.insert(connections, Network.on("PostMatchStatus", receiveStatus))
	table.insert(connections, Players.LocalPlayer:GetAttributeChangedSignal("ArenaRoundEligible"):Connect(syncPhase))

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
	local unsubscribe = listeners.add(listener)
	listener(state)
	return unsubscribe
end

function PostMatchClient.request(action: Action)
	local result = state.result
	if result == nil or state.requesting then
		return
	end
	requestGeneration += 1
	local generation = requestGeneration
	publish({ requesting = true, pendingAction = action, error = CLEAR })
	task.spawn(function()
		local ok, response = ClientRequest(Network.call, "PostMatchRequest", action, result.resultId)
		if generation ~= requestGeneration or not started then
			return
		end
		if not ok or typeof(response) ~= "table" then
			publish({
				requesting = false,
				pendingAction = CLEAR,
				error = if response == "request_timed_out" then "request_timed_out" else "request_failed",
			})
			return
		end
		if response.status then
			receiveStatus(response.status)
		end
		if response.ok ~= true then
			publish({ requesting = false, pendingAction = CLEAR, error = response.error or "request_failed" })
		elseif response.status == nil then
			publish({ requesting = false, pendingAction = CLEAR })
		end
	end)
end

function PostMatchClient.playAgain()
	local status = state.status
	PostMatchClient.request(if status and status.canReplay == false then "FindMatch" else "PlayAgain")
end

function PostMatchClient.returnToLobby()
	PostMatchClient.request("ReturnToLobby")
end

function PostMatchClient.leaveParty()
	PostMatchClient.request("LeaveParty")
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
	listeners.clear()
	Combat.releaseCursor(CURSOR_REASON)
	matchState = nil
	pendingStatus = nil
	awaitingResultsPhase = false
	state = {
		visible = false,
		result = nil,
		status = nil,
		requesting = false,
		pendingAction = nil,
		error = nil,
		departing = false,
	}
	started = false
end

return PostMatchClient
