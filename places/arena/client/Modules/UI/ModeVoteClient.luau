-- Description: Client adapter for the authoritative game-mode ballot, decoding the replicated vote snapshot into the shape the mode-select UI renders and submitting the local player's vote.

--!strict

local Listeners = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Util")
		:WaitForChild("Listeners")
)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local ModeVoteClient = {}

export type Snapshot = {
	admitted: boolean,
	open: boolean,
	startsAt: number,
	endsAt: number,
	durationSeconds: number,
	options: { string },
	voteCounts: { [string]: number },
	scoreTargets: { [string]: number },
	selectedModeId: string?,
	winnerModeId: string?,
	mapOptions: { string },
	mapVoteCounts: { [string]: number },
	selectedMapId: string?,
	winnerMapId: string?,
	currentMapId: string?,
	revision: number,
}

local player = Players.LocalPlayer
local started = false
local stateFolder: Folder? = nil
local stateConnections: { RBXScriptConnection } = {}
local connections: { RBXScriptConnection } = {}
local listeners: Listeners.Collection<Snapshot> = Listeners.new("ModeVoteClient", false, "listener failed")
local projected = {
	open = false,
	startsAt = 0,
	endsAt = 0,
	durationSeconds = 0,
	options = {},
	voteCounts = {},
	scoreTargets = {},
	winnerModeId = nil,
	mapOptions = {},
	mapVoteCounts = {},
	winnerMapId = nil,
	currentMapId = nil,
	revision = 0,
}

local function admitted(): boolean
	local admission = player:GetAttribute("ArenaAdmission")
	return admission == "Matched" or admission == "Direct"
end

local function snapshot(): Snapshot
	local counts = table.clone(projected.voteCounts)
	local selectedModeId = player:GetAttribute("ModeVoteSelection")
	local selectedMapId = player:GetAttribute("MapVoteSelection")
	return {
		admitted = admitted(),
		open = projected.open,
		startsAt = projected.startsAt,
		endsAt = projected.endsAt,
		durationSeconds = projected.durationSeconds,
		options = table.clone(projected.options),
		voteCounts = counts,
		scoreTargets = table.clone(projected.scoreTargets),
		selectedModeId = if typeof(selectedModeId) == "string" then selectedModeId else nil,
		winnerModeId = projected.winnerModeId,
		mapOptions = table.clone(projected.mapOptions),
		mapVoteCounts = table.clone(projected.mapVoteCounts),
		selectedMapId = if typeof(selectedMapId) == "string" then selectedMapId else nil,
		winnerMapId = projected.winnerMapId,
		currentMapId = projected.currentMapId,
		revision = projected.revision,
	}
end

local function notify()
	local value = snapshot()
	listeners.emit(value)
end

local function decode(value: string)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, value)
	if not ok or typeof(data) ~= "table" then
		return
	end
	local options = {}
	local counts = {}
	local targets = {}
	if typeof(data.scoreTargets) == "table" then
		for modeId, target in data.scoreTargets do
			if typeof(modeId) == "string" and typeof(target) == "number" then
				targets[modeId] = target
			end
		end
	end
	if typeof(data.options) == "table" then
		for _, modeId in data.options do
			if typeof(modeId) == "string" then
				table.insert(options, modeId)
			end
		end
	end
	if typeof(data.voteCounts) == "table" then
		for modeId, count in data.voteCounts do
			if typeof(modeId) == "string" and typeof(count) == "number" then
				counts[modeId] = count
			end
		end
	end
	local mapOptions = {}
	local mapCounts = {}
	if typeof(data.mapOptions) == "table" then
		for _, mapId in data.mapOptions do
			if typeof(mapId) == "string" then
				table.insert(mapOptions, mapId)
			end
		end
	end
	if typeof(data.mapVoteCounts) == "table" then
		for mapId, count in data.mapVoteCounts do
			if typeof(mapId) == "string" and typeof(count) == "number" then
				mapCounts[mapId] = count
			end
		end
	end
	projected = {
		open = data.open == true,
		startsAt = if typeof(data.startsAt) == "number" then data.startsAt else 0,
		endsAt = if typeof(data.endsAt) == "number" then data.endsAt else 0,
		durationSeconds = if typeof(data.durationSeconds) == "number" then data.durationSeconds else 0,
		options = options,
		voteCounts = counts,
		scoreTargets = targets,
		winnerModeId = if typeof(data.winnerModeId) == "string" and data.winnerModeId ~= ""
			then data.winnerModeId
			else nil,
		mapOptions = mapOptions,
		mapVoteCounts = mapCounts,
		winnerMapId = if typeof(data.winnerMapId) == "string" and data.winnerMapId ~= "" then data.winnerMapId else nil,
		currentMapId = if typeof(data.currentMapId) == "string" and data.currentMapId ~= ""
			then data.currentMapId
			else nil,
		revision = if typeof(data.revision) == "number" then data.revision else 0,
	}
	notify()
end

local function decodeLegacy(folder: Folder)
	local options = {}
	local counts = {}
	local optionCount = (folder:GetAttribute("optionCount") :: number?) or 0
	for index = 1, optionCount do
		local modeId = folder:GetAttribute(`Option{index}Id`)
		if typeof(modeId) == "string" and modeId ~= "" then
			table.insert(options, modeId)
			counts[modeId] = (folder:GetAttribute(`Option{index}Count`) :: number?) or 0
		end
	end
	local winnerModeId = folder:GetAttribute("winnerModeId")
	projected = {
		open = folder:GetAttribute("open") == true,
		startsAt = (folder:GetAttribute("startsAt") :: number?) or 0,
		endsAt = (folder:GetAttribute("endsAt") :: number?) or 0,
		durationSeconds = (folder:GetAttribute("durationSeconds") :: number?) or 0,
		options = options,
		voteCounts = counts,
		scoreTargets = {},
		winnerModeId = if typeof(winnerModeId) == "string" and winnerModeId ~= "" then winnerModeId else nil,
		mapOptions = {},
		mapVoteCounts = {},
		winnerMapId = nil,
		currentMapId = nil,
		revision = (folder:GetAttribute("revision") :: number?) or 0,
	}
	notify()
end

local function attach(folder: Folder)
	if stateFolder ~= nil then
		return
	end
	stateFolder = folder
	local function attachSnapshot(child: Instance)
		if child.Name ~= "Snapshot" or not child:IsA("StringValue") then
			return
		end
		table.insert(
			stateConnections,
			child:GetPropertyChangedSignal("Value"):Connect(function()
				decode(child.Value)
			end)
		)
		decode(child.Value)
	end
	local value = folder:FindFirstChild("Snapshot")
	if value then
		attachSnapshot(value)
	else
		table.insert(
			stateConnections,
			folder.AttributeChanged:Connect(function()
				decodeLegacy(folder)
			end)
		)
		decodeLegacy(folder)
	end
	table.insert(stateConnections, folder.ChildAdded:Connect(attachSnapshot))
end

function ModeVoteClient.start()
	if started then
		return
	end
	started = true
	local existing = ReplicatedStorage:FindFirstChild("ModeVoteState")
	if existing and existing:IsA("Folder") then
		attach(existing)
	end
	table.insert(
		connections,
		ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == "ModeVoteState" and child:IsA("Folder") then
				attach(child)
			end
		end)
	)
	table.insert(connections, player:GetAttributeChangedSignal("ModeVoteSelection"):Connect(notify))
	table.insert(connections, player:GetAttributeChangedSignal("MapVoteSelection"):Connect(notify))
	table.insert(connections, player:GetAttributeChangedSignal("ArenaAdmission"):Connect(notify))
end

function ModeVoteClient.getSnapshot(): Snapshot
	return snapshot()
end

function ModeVoteClient.subscribe(callback: (Snapshot) -> ()): () -> ()
	ModeVoteClient.start()
	local unsubscribe = listeners.add(callback)
	callback(snapshot())
	return unsubscribe
end

function ModeVoteClient.vote(modeId: string)
	if admitted() then
		Network.fireServer("SubmitModeVote", modeId)
	end
end

function ModeVoteClient.voteMap(mapId: string)
	if admitted() then
		Network.fireServer("SubmitMapVote", mapId)
	end
end

function ModeVoteClient.destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, connection in stateConnections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(stateConnections)
	listeners.clear()
	stateFolder = nil
	started = false
end

return ModeVoteClient
