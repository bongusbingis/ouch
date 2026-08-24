--!strict

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Animations = require(Config:WaitForChild("Animations"))
local Audio = require(Config:WaitForChild("Audio"))
local Cosmetics = require(Config:WaitForChild("Cosmetics"))
local GameModes = require(Config:WaitForChild("GameModes"))
local Loading = require(Config:WaitForChild("Loading"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local ArenaLoadingClient = {}

export type Snapshot = {
	admission: string,
	serverReady: boolean,
	localReady: boolean,
	gameLoaded: boolean,
	uiPresented: boolean,
	votePrepared: boolean,
	simulationReady: boolean,
	preloadReady: boolean,
	preloadTimedOut: boolean,
	preloadFailed: boolean,
	preloadProgress: number,
	worldReady: boolean,
	streamReady: boolean,
	expectedPlayerCount: number,
	arrivedPlayerCount: number,
	readyPlayerCount: number,
	deadlineAt: number,
	gateReleased: boolean,
	modeOptions: { string },
	matchPhase: string,
	fatalError: string?,
}

type ServerSnapshot = {
	expectedPlayerCount: number,
	arrivedPlayerCount: number,
	readyPlayerCount: number,
	deadlineAt: number,
	gateReleased: boolean,
	modeOptions: { string },
}

local player = Players.LocalPlayer
local started = false
local destroyed = false
local generation = 0
local readyTaskRunning = false
local listeners: { (Snapshot) -> () } = {}
local connections: { RBXScriptConnection } = {}
local stateConnections: { RBXScriptConnection } = {}
local loadState: Folder? = nil
local matchState: Folder? = nil

local localState = {
	gameLoaded = false,
	uiPresented = false,
	votePrepared = false,
	simulationReady = false,
	preloadReady = false,
	preloadTimedOut = false,
	preloadFailed = false,
	preloadProgress = 0,
	worldReady = false,
	streamReady = false,
	fatalError = nil,
}

local serverState: ServerSnapshot = {
	expectedPlayerCount = 1,
	arrivedPlayerCount = 0,
	readyPlayerCount = 0,
	deadlineAt = 0,
	gateReleased = false,
	modeOptions = table.clone(GameModes.VoteOptions),
}
local startedAt = 0
local preloadStartedAt = 0
local reportedLocalReady = false
local reportedBallots: { [number]: boolean } = {}

local function report(kind: string, fields: { [string]: any })
	fields.kind = kind
	Network.fireServer("ReportArenaLoadingEvent", fields)
end

local function disconnectStateConnections()
	for _, connection in stateConnections do
		connection:Disconnect()
	end
	table.clear(stateConnections)
end

local function exactAdmission(): string
	local value = player:GetAttribute("ArenaAdmission")
	return if value == "Matched" or value == "Direct" or value == "Rejected" then value else "Pending"
end

local function baseReady(): boolean
	local admission = exactAdmission()
	return (admission == "Matched" or admission == "Direct")
		and localState.gameLoaded
		and localState.uiPresented
		and localState.votePrepared
		and localState.simulationReady
		and localState.preloadReady
		and localState.streamReady
end

local function isLocalReady(): boolean
	return localState.fatalError == nil and baseReady()
end

local function currentSnapshot(): Snapshot
	return {
		admission = exactAdmission(),
		serverReady = player:GetAttribute("ArenaReady") == true,
		localReady = isLocalReady(),
		gameLoaded = localState.gameLoaded,
		uiPresented = localState.uiPresented,
		votePrepared = localState.votePrepared,
		simulationReady = localState.simulationReady,
		preloadReady = localState.preloadReady,
		preloadTimedOut = localState.preloadTimedOut,
		preloadFailed = localState.preloadFailed,
		preloadProgress = localState.preloadProgress,
		worldReady = localState.worldReady,
		streamReady = localState.streamReady,
		expectedPlayerCount = serverState.expectedPlayerCount,
		arrivedPlayerCount = serverState.arrivedPlayerCount,
		readyPlayerCount = serverState.readyPlayerCount,
		deadlineAt = serverState.deadlineAt,
		gateReleased = serverState.gateReleased,
		modeOptions = table.clone(serverState.modeOptions),
		matchPhase = if matchState then (matchState:GetAttribute("phase") :: string?) or "Idle" else "Idle",
		fatalError = localState.fatalError,
	}
end

local function notify()
	local snapshot = currentSnapshot()
	for _, listener in listeners do
		local ok, err = pcall(listener, snapshot)
		if not ok then
			warn(`[ArenaLoadingClient] listener failed: {err}`)
		end
	end
end

local function tryReady()
	if readyTaskRunning or destroyed or not isLocalReady() or player:GetAttribute("ArenaReady") == true then
		return
	end
	readyTaskRunning = true
	if not reportedLocalReady then
		reportedLocalReady = true
		report("Stage", {
			stage = "ClientReady",
			durationMs = math.floor((os.clock() - startedAt) * 1000 + 0.5),
		})
	end
	local currentGeneration = generation
	task.spawn(function()
		while
			not destroyed
			and generation == currentGeneration
			and isLocalReady()
			and player:GetAttribute("ArenaReady") ~= true
		do
			Network.fireServer("ArenaClientReady")
			task.wait(Loading.ArenaReadyRetrySeconds)
		end
		if generation == currentGeneration then
			readyTaskRunning = false
		end
	end)
end

local function changed()
	if localState.fatalError ~= nil and baseReady() then
		localState.fatalError = nil
	end
	notify()
	tryReady()
end

local function scheduleInitializationTimeout(currentGeneration: number)
	task.delay(Loading.CriticalInitializationTimeoutSeconds, function()
		if destroyed or generation ~= currentGeneration or isLocalReady() then
			return
		end
		localState.fatalError = "INITIALIZATION_TIMED_OUT"
		changed()
	end)
end

local function number(value: any, fallback: number): number
	return if typeof(value) == "number" then value else fallback
end

local function decodeLoadSnapshot(value: string)
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value)
	if not ok or typeof(decoded) ~= "table" then
		return
	end
	local options = {}
	if typeof(decoded.modeOptions) == "table" then
		for _, modeId in decoded.modeOptions do
			if typeof(modeId) == "string" then
				table.insert(options, modeId)
			end
		end
	end
	serverState = {
		expectedPlayerCount = math.max(1, number(decoded.expectedPlayerCount, 1)),
		arrivedPlayerCount = math.max(0, number(decoded.arrivedPlayerCount, 0)),
		readyPlayerCount = math.max(0, number(decoded.readyPlayerCount, 0)),
		deadlineAt = number(decoded.deadlineAt, 0),
		gateReleased = decoded.gateReleased == true,
		modeOptions = if #options > 0 then options else table.clone(GameModes.VoteOptions),
	}
	changed()
end

local function attachLoadState(folder: Folder)
	loadState = folder
	local function attachSnapshot(child: Instance)
		if child.Name ~= "Snapshot" or not child:IsA("StringValue") then
			return
		end
		table.insert(
			stateConnections,
			child:GetPropertyChangedSignal("Value"):Connect(function()
				decodeLoadSnapshot(child.Value)
			end)
		)
		decodeLoadSnapshot(child.Value)
	end
	local existing = folder:FindFirstChild("Snapshot")
	if existing then
		attachSnapshot(existing)
	end
	table.insert(stateConnections, folder.ChildAdded:Connect(attachSnapshot))
end

local function attachMatchState(folder: Folder)
	matchState = folder
	table.insert(stateConnections, folder:GetAttributeChangedSignal("phase"):Connect(changed))
	changed()
end

local function watchRuntimeState()
	local existingLoadState = ReplicatedStorage:FindFirstChild("ArenaLoadState")
	if existingLoadState and existingLoadState:IsA("Folder") then
		attachLoadState(existingLoadState)
	end
	local existingMatchState = ReplicatedStorage:FindFirstChild("MatchState")
	if existingMatchState and existingMatchState:IsA("Folder") then
		attachMatchState(existingMatchState)
	end
	table.insert(
		connections,
		ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == "ArenaLoadState" and child:IsA("Folder") and loadState == nil then
				attachLoadState(child)
			elseif child.Name == "MatchState" and child:IsA("Folder") and matchState == nil then
				attachMatchState(child)
			end
		end)
	)
end

local function criticalContentIds(): { string }
	local ids = table.clone(Loading.CriticalContentIds)
	local seen = {}
	for _, contentId in ids do
		seen[contentId] = true
	end
	local function add(contentId: string)
		if contentId ~= "" and not seen[contentId] then
			seen[contentId] = true
			table.insert(ids, contentId)
		end
	end
	add("rbxasset://fonts/families/LuckiestGuy.json")
	add("rbxasset://fonts/families/HighwayGothic.json")
	for _, definition in Audio.Gameplay do
		for _, contentId in definition.AssetIds do
			add(contentId)
		end
	end
	for _, modeId in GameModes.VoteOptions do
		local definition = GameModes.Modes[modeId]
		if definition and definition.ThumbnailId ~= nil and definition.ThumbnailId ~= "" then
			local value = tostring(definition.ThumbnailId)
			add(if string.find(value, "rbxassetid://", 1, true) == 1 then value else `rbxassetid://{value}`)
		end
	end
	return ids
end

local function criticalInstances(): { Instance }
	local result = {}
	local seen: { [Instance]: boolean } = {}
	local function add(instance: Instance)
		if not seen[instance] then
			seen[instance] = true
			table.insert(result, instance)
		end
	end
	for _, instance in CollectionService:GetTagged(Loading.CriticalPreloadTag) do
		add(instance)
	end
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local animations = assets:WaitForChild(Animations.FolderName)
	for _, clips in Animations.Clips do
		for _, clip in clips do
			if clip.Required then
				add(animations:WaitForChild(clip.Name))
			end
		end
	end
	local templates = assets:WaitForChild("Cosmetics"):WaitForChild("Templates")
	for _, template in Cosmetics.VisualTemplates do
		add(templates:WaitForChild(template.CarrierName))
	end
	return result
end

local function beginPreload(currentGeneration: number)
	local completedBatches = 0
	local function batchComplete()
		if destroyed or generation ~= currentGeneration then
			return
		end
		completedBatches += 1
		if completedBatches == 2 then
			localState.worldReady = true
			localState.preloadReady = true
			localState.preloadProgress = 1
			report("Preload", {
				outcome = if localState.preloadTimedOut
					then "CompletedAfterTimeout"
					else if localState.preloadFailed then "Failed" else "Completed",
				durationMs = math.floor((os.clock() - preloadStartedAt) * 1000 + 0.5),
			})
			changed()
		end
	end

	task.delay(Loading.CriticalPreloadTimeoutSeconds, function()
		if destroyed or generation ~= currentGeneration or localState.preloadReady then
			return
		end
		localState.preloadReady = true
		localState.preloadTimedOut = true
		report("Preload", {
			outcome = "Timeout",
			durationMs = math.floor((os.clock() - preloadStartedAt) * 1000 + 0.5),
		})
		changed()
	end)

	task.spawn(function()
		local ids = criticalContentIds()
		local completed = 0
		local seen = {}
		pcall(function()
			ContentProvider:PreloadAsync(ids, function(contentId, status)
				if destroyed or generation ~= currentGeneration then
					return
				end
				if status ~= Enum.AssetFetchStatus.Success then
					localState.preloadFailed = true
				end
				if not seen[contentId] then
					seen[contentId] = true
					completed += 1
					localState.preloadProgress = math.clamp(completed / math.max(#ids, 1), 0, 1)
					changed()
				end
			end)
		end)
		batchComplete()
	end)

	task.spawn(function()
		local instances = criticalInstances()
		if #instances > 0 then
			local success = pcall(ContentProvider.PreloadAsync, ContentProvider, instances)
			if not success and not destroyed and generation == currentGeneration then
				localState.preloadFailed = true
			end
		end
		batchComplete()
	end)
end

local function beginStreaming(currentGeneration: number)
	task.spawn(function()
		if Workspace.StreamingEnabled then
			local arena = Workspace:WaitForChild("Assets"):WaitForChild("Arena")
			local mapOrigin = arena:WaitForChild("MapOrigin")
			assert(
				mapOrigin:IsA("BasePart"),
				"[ArenaLoadingClient] Workspace.Assets.Arena.MapOrigin must be a BasePart"
			)
			pcall(player.RequestStreamAroundAsync, player, mapOrigin.Position, Loading.CriticalPreloadTimeoutSeconds)
		end
		if destroyed or generation ~= currentGeneration then
			return
		end
		localState.streamReady = true
		changed()
	end)
end

function ArenaLoadingClient.getSnapshot(): Snapshot
	return currentSnapshot()
end

function ArenaLoadingClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	table.insert(listeners, listener)
	listener(currentSnapshot())
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

function ArenaLoadingClient.markUiPresented()
	if not localState.uiPresented then
		localState.uiPresented = true
		changed()
	end
end

function ArenaLoadingClient.markVotePrepared()
	if not localState.votePrepared then
		localState.votePrepared = true
		changed()
	end
end

function ArenaLoadingClient.markSimulationReady()
	if not localState.simulationReady then
		localState.simulationReady = true
		changed()
	end
end

function ArenaLoadingClient.markBallotPresented(startsAt: number)
	if startsAt <= 0 or reportedBallots[startsAt] then
		return
	end
	reportedBallots[startsAt] = true
	report("BallotImpression", { startsAt = startsAt })
end

function ArenaLoadingClient.retryInitialization()
	if destroyed or not localState.gameLoaded or isLocalReady() then
		return
	end
	generation += 1
	local currentGeneration = generation
	readyTaskRunning = false
	localState.fatalError = nil
	localState.preloadReady = false
	localState.preloadTimedOut = false
	localState.preloadFailed = false
	localState.preloadProgress = 0
	localState.worldReady = false
	localState.streamReady = false
	preloadStartedAt = os.clock()
	changed()
	beginPreload(currentGeneration)
	beginStreaming(currentGeneration)
	scheduleInitializationTimeout(currentGeneration)
end

function ArenaLoadingClient.start()
	if started then
		return
	end
	started = true
	destroyed = false
	readyTaskRunning = false
	generation += 1
	local currentGeneration = generation
	startedAt = os.clock()
	preloadStartedAt = startedAt

	watchRuntimeState()
	table.insert(connections, player:GetAttributeChangedSignal("ArenaAdmission"):Connect(changed))
	table.insert(connections, player:GetAttributeChangedSignal("ArenaReady"):Connect(changed))

	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		if destroyed or generation ~= currentGeneration then
			return
		end
		localState.gameLoaded = true
		report("Stage", {
			stage = "GameLoaded",
			durationMs = math.floor((os.clock() - startedAt) * 1000 + 0.5),
		})
		preloadStartedAt = os.clock()
		changed()
		beginPreload(currentGeneration)
		beginStreaming(currentGeneration)
		scheduleInitializationTimeout(currentGeneration)
	end)

	changed()
end

function ArenaLoadingClient.destroy()
	if destroyed then
		return
	end
	destroyed = true
	generation += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	disconnectStateConnections()
	table.clear(connections)
	table.clear(listeners)
	started = false
end

return ArenaLoadingClient
