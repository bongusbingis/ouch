-- Description: Owns the arena loading gate on the client: validates available gameplay hierarchy, warms optional media in the background, tracks streaming and initialization progress, reports readiness to the server, and publishes a snapshot the loading screen renders.

--!strict

local Listeners = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Util")
		:WaitForChild("Listeners")
)

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local arenaOrigin = require(script.Parent.Parent.Presentation.ArenaOrigin)

local Config = ReplicatedStorage:WaitForChild("Config")
local Animations = require(Config:WaitForChild("Infra"):WaitForChild("Animations"))
local Audio = require(Config:WaitForChild("Infra"):WaitForChild("Audio"))
local Cosmetics = require(Config:WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local GameModes = require(Config:WaitForChild("Gameplay"):WaitForChild("GameModes"))
local Queues = require(Config:WaitForChild("Gameplay"):WaitForChild("Queues"))
local Splashdown = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local Loading = require(Config:WaitForChild("Interface"):WaitForChild("Loading"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModeOptions = require(Shared:WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeOptions"))
local Network = require(Shared:WaitForChild("Network"))

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
	initializationDegraded: boolean,
	expectedPlayerCount: number,
	arrivedPlayerCount: number,
	readyPlayerCount: number,
	deadlineAt: number,
	gateReleased: boolean,
	modeOptions: { string },
	queueId: string?,
	fixedModeId: string?,
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
	queueId: string,
	fixedModeId: string?,
}

local player = Players.LocalPlayer
local started = false
local destroyed = false
local generation = 0
local readyTaskRunning = false
local listeners: Listeners.Collection<Snapshot> = Listeners.new("ArenaLoadingClient", false, "listener failed")
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
	initializationDegraded = false,
	fatalError = nil,
}

-- A missing projection is a waiting state. It cannot supply a queue or satisfy
-- readiness until a complete authoritative snapshot has been validated.
local serverState: ServerSnapshot? = nil
local snapshotError: string? = nil
local lastAcceptedRevision = 0
local lastAcceptedProjection: ServerSnapshot? = nil
local generalPreloadReady = false
local generalWorldReady = false
local generalPreloadGeneration = 0
local coursePreloadReady = true
local courseWorldReady = true
local coursePreloadGeneration = 0
local onServerSnapshotAccepted: ((boolean) -> ())? = nil
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
		and serverState ~= nil
		and serverState.expectedPlayerCount > 0
		and localState.gameLoaded
		and localState.simulationReady
		and localState.preloadReady
		and localState.streamReady
end

local function isLocalReady(): boolean
	return snapshotError == nil and baseReady()
end

local function currentSnapshot(): Snapshot
	local projected = serverState
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
		initializationDegraded = localState.initializationDegraded,
		expectedPlayerCount = if projected then projected.expectedPlayerCount else 0,
		arrivedPlayerCount = if projected then projected.arrivedPlayerCount else 0,
		readyPlayerCount = if projected then projected.readyPlayerCount else 0,
		deadlineAt = if projected then projected.deadlineAt else 0,
		gateReleased = if projected then projected.gateReleased else false,
		modeOptions = if projected then table.clone(projected.modeOptions) else {},
		queueId = if projected then projected.queueId else nil,
		fixedModeId = if projected then projected.fixedModeId else nil,
		matchPhase = if matchState then (matchState:GetAttribute("phase") :: string?) or "Idle" else "Idle",
		fatalError = snapshotError,
	}
end

local function notify()
	local snapshot = currentSnapshot()
	listeners.emit(snapshot)
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
		local attempts = 0
		while
			not destroyed
			and generation == currentGeneration
			and isLocalReady()
			and player:GetAttribute("ArenaReady") ~= true
			and attempts < 5
		do
			attempts += 1
			Network.fireServer("ArenaClientReady")
			task.wait(Loading.ArenaReadyRetrySeconds)
		end
		if generation == currentGeneration then
			readyTaskRunning = false
		end
	end)
end

local function changed()
	notify()
	tryReady()
end

local LOAD_SNAPSHOT_PATH = "ReplicatedStorage.ArenaLoadState.Snapshot"

local function scheduleInitializationTimeout(currentGeneration: number)
	task.delay(Loading.CriticalInitializationTimeoutSeconds, function()
		if destroyed or generation ~= currentGeneration or isLocalReady() then
			return
		end
		ArenaLoadingClient.reportStartupIssue(
			"ArenaLoadingClient.initialization",
			"initialization timed out; continuing with available client systems"
		)
		-- The deadline only releases client-owned work. It never creates or
		-- accepts a server projection, so trusted admission remains required.
		localState.gameLoaded = true
		localState.simulationReady = true
		localState.preloadReady = true
		localState.streamReady = true
		if serverState == nil then
			warn(
				`[ArenaLoadingClient] {LOAD_SNAPSHOT_PATH}: authoritative server snapshot is unavailable; waiting without reporting ready`
			)
			changed()
			return
		end
		changed()
	end)
end

local function countField(decoded: { [string]: any }, name: string): (number?, string?)
	local value = decoded[name]
	if typeof(value) ~= "number" or value % 1 ~= 0 or value < 0 or value > 100 then
		return nil, `{name} must be an integer from 0 to 100`
	end
	return value, nil
end

local function validateLoadSnapshot(decoded: any): (ServerSnapshot?, number?, string?)
	if typeof(decoded) ~= "table" then
		return nil, nil, "root must be an object"
	end
	if decoded.schemaVersion ~= 2 then
		return nil, nil, `schemaVersion must be 2; received {tostring(decoded.schemaVersion)}`
	end
	local revision = decoded.revision
	if typeof(revision) ~= "number" or revision % 1 ~= 0 or revision < 1 then
		return nil, nil, "revision must be a positive integer"
	end
	local expected, expectedError = countField(decoded, "expectedPlayerCount")
	if expected == nil then
		return nil, nil, expectedError
	end
	local arrived, arrivedError = countField(decoded, "arrivedPlayerCount")
	if arrived == nil then
		return nil, nil, arrivedError
	end
	local ready, readyError = countField(decoded, "readyPlayerCount")
	if ready == nil then
		return nil, nil, readyError
	end
	if ready > arrived then
		return nil, nil, `readyPlayerCount ({ready}) exceeds arrivedPlayerCount ({arrived})`
	end
	local deadlineAt = decoded.deadlineAt
	if typeof(deadlineAt) ~= "number" or deadlineAt ~= deadlineAt or deadlineAt < 0 or deadlineAt == math.huge then
		return nil, nil, "deadlineAt must be a finite nonnegative number"
	end
	if typeof(decoded.gateReleased) ~= "boolean" then
		return nil, nil, "gateReleased must be a boolean"
	end
	if expected == 0 and (arrived ~= 0 or ready ~= 0 or deadlineAt ~= 0 or decoded.gateReleased) then
		return nil,
			nil,
			"expectedPlayerCount is 0 but gate counters, deadlineAt, or gateReleased indicate an active gate"
	end
	local queueId = decoded.queueId
	if typeof(queueId) ~= "string" or not Queues.isEnabled(queueId) then
		return nil, nil, `queueId must name an enabled queue; received {tostring(queueId)}`
	end
	local rawOptions = decoded.modeOptions
	if typeof(rawOptions) ~= "table" or #rawOptions == 0 then
		return nil, nil, "modeOptions must be a nonempty array of mode IDs"
	end
	local options: { string } = {}
	local seen = {}
	local optionCount = 0
	for index, modeId in rawOptions do
		optionCount += 1
		if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #rawOptions then
			return nil, nil, `modeOptions has an invalid index {tostring(index)}`
		end
		if typeof(modeId) ~= "string" or modeId == "" then
			return nil, nil, `modeOptions[{index}] must be a nonempty mode ID`
		end
		if seen[modeId] then
			return nil, nil, `modeOptions[{index}] duplicates {modeId}`
		end
		local definition = GameModes.Modes[modeId]
		if definition == nil or definition.Enabled ~= true then
			return nil, nil, `modeOptions[{index}] names unavailable mode {modeId}`
		end
		if definition.Queue ~= queueId then
			return nil, nil, `modeOptions[{index}] mode {modeId} belongs to queue {definition.Queue}, not {queueId}`
		end
		seen[modeId] = true
		options[index] = modeId
	end
	if optionCount ~= #rawOptions then
		return nil, nil, "modeOptions must have contiguous numeric indices"
	end
	local resolved = ModeOptions.resolve(options)
	if not ModeOptions.equals(options, resolved) then
		return nil, nil, `modeOptions contains an unavailable registered mode; received {table.concat(options, ", ")}`
	end
	local fixedModeId = decoded.fixedModeId
	if fixedModeId ~= nil and (typeof(fixedModeId) ~= "string" or fixedModeId == "") then
		return nil, nil, "fixedModeId must be a nonempty mode ID when present"
	end
	local selection = Queues.get(queueId).ModeSelection
	if selection.Strategy == "Fixed" then
		if fixedModeId ~= selection.ModeId or #options ~= 1 or options[1] ~= fixedModeId then
			return nil, nil, `fixedModeId and modeOptions must name {selection.ModeId} for queueId {queueId}`
		end
	elseif fixedModeId ~= nil then
		return nil, nil, `fixedModeId must be absent for vote queueId {queueId}`
	end
	return {
		expectedPlayerCount = expected,
		arrivedPlayerCount = arrived,
		readyPlayerCount = ready,
		deadlineAt = deadlineAt,
		gateReleased = decoded.gateReleased,
		modeOptions = options,
		queueId = queueId,
		fixedModeId = fixedModeId,
	},
		revision,
		nil
end

local function sameProjection(first: ServerSnapshot, second: ServerSnapshot): boolean
	return first.expectedPlayerCount == second.expectedPlayerCount
		and first.arrivedPlayerCount == second.arrivedPlayerCount
		and first.readyPlayerCount == second.readyPlayerCount
		and first.deadlineAt == second.deadlineAt
		and first.gateReleased == second.gateReleased
		and first.queueId == second.queueId
		and first.fixedModeId == second.fixedModeId
		and ModeOptions.equals(first.modeOptions, second.modeOptions)
end

local function rejectLoadSnapshot(path: string, reason: string)
	local diagnostic = `{path}: {reason}`
	warn(`[ArenaLoadingClient] rejected {diagnostic}`)
	snapshotError = diagnostic
	serverState = nil
	generation += 1
	readyTaskRunning = false
	generalPreloadReady = false
	generalWorldReady = false
	coursePreloadReady = true
	courseWorldReady = true
	localState.preloadReady = false
	localState.preloadTimedOut = false
	localState.preloadFailed = false
	localState.preloadProgress = 0
	localState.worldReady = false
	localState.streamReady = false
	changed()
end

local function decodeLoadSnapshot(value: string)
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value)
	if not ok then
		rejectLoadSnapshot(LOAD_SNAPSHOT_PATH, `malformed JSON: {decoded}`)
		return
	end
	local projected, revision, reason = validateLoadSnapshot(decoded)
	if projected == nil or revision == nil then
		rejectLoadSnapshot(
			LOAD_SNAPSHOT_PATH,
			reason or "validator returned no reason; fix ArenaLoadingClient.validateLoadSnapshot"
		)
		return
	end
	if revision < lastAcceptedRevision then
		rejectLoadSnapshot(
			LOAD_SNAPSHOT_PATH,
			`revision {revision} is older than accepted revision {lastAcceptedRevision}`
		)
		return
	end
	if revision == lastAcceptedRevision then
		if lastAcceptedProjection ~= nil and sameProjection(lastAcceptedProjection, projected) then
			return
		end
		rejectLoadSnapshot(LOAD_SNAPSHOT_PATH, `revision {revision} contradicts the accepted projection`)
		return
	end
	local previousError = snapshotError
	serverState = projected
	lastAcceptedRevision = revision
	lastAcceptedProjection = projected
	snapshotError = nil
	if previousError then
		warn(`[ArenaLoadingClient] {LOAD_SNAPSHOT_PATH} recovered at revision {revision} after {previousError}`)
	end
	if onServerSnapshotAccepted then
		onServerSnapshotAccepted(previousError ~= nil)
	end
	changed()
end

local function attachLoadState(folder: Folder)
	loadState = folder
	local function attachSnapshot(child: Instance)
		if child.Name ~= "Snapshot" then
			return
		end
		if not child:IsA("StringValue") then
			rejectLoadSnapshot(LOAD_SNAPSHOT_PATH, "required StringValue has the wrong class")
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
	if existingLoadState then
		if existingLoadState:IsA("Folder") then
			attachLoadState(existingLoadState)
		else
			rejectLoadSnapshot("ReplicatedStorage.ArenaLoadState", "required Folder has the wrong class")
		end
	end
	local existingMatchState = ReplicatedStorage:FindFirstChild("MatchState")
	if existingMatchState and existingMatchState:IsA("Folder") then
		attachMatchState(existingMatchState)
	end
	table.insert(
		connections,
		ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == "ArenaLoadState" and loadState == nil then
				if child:IsA("Folder") then
					attachLoadState(child)
				else
					rejectLoadSnapshot("ReplicatedStorage.ArenaLoadState", "required Folder has the wrong class")
				end
			elseif child.Name == "MatchState" and child:IsA("Folder") and matchState == nil then
				attachMatchState(child)
			end
		end)
	)
end

local function optionalMediaInstances(): ({ Instance }, { Instance })
	local media: { Instance } = {}
	local transient: { Instance } = {}
	local seen: { [string]: boolean } = {}
	local seenInstances: { [Instance]: boolean } = {}
	local function contentId(value: any, path: string, allowBareNumber: boolean): string?
		local resolved = value
		if
			allowBareNumber
			and (typeof(value) == "number" or (typeof(value) == "string" and string.match(value, "^[1-9]%d*$")))
		then
			resolved = `rbxassetid://{value}`
		end
		if
			typeof(resolved) ~= "string"
			or (
				string.match(resolved, "^rbxassetid://[1-9]%d*$") == nil
				and string.match(resolved, "^rbxasset://fonts/families/[%w]+%.json$") == nil
			)
		then
			warn(
				`[ArenaLoadingClient] optional media skipped: {path} ({tostring(value)}) is not a supported content ID`
			)
			return nil
		end
		return resolved
	end
	local function add(instance: Instance, key: string)
		if seen[key] then
			instance:Destroy()
			return
		end
		seen[key] = true
		instance.Name = "ArenaOptionalMediaWarmup"
		table.insert(media, instance)
		table.insert(transient, instance)
	end
	local function addExisting(instance: Instance)
		if not seenInstances[instance] then
			seenInstances[instance] = true
			table.insert(media, instance)
		end
	end
	local function addSound(value: any, path: string)
		local id = contentId(value, path, false)
		if id then
			local sound = Instance.new("Sound")
			sound.SoundId = id
			add(sound, `Sound:{id}`)
		end
	end
	local function addImage(value: any, path: string, allowBareNumber: boolean)
		local id = contentId(value, path, allowBareNumber)
		if id then
			local image = Instance.new("ImageLabel")
			image.Image = id
			add(image, `ImageLabel:{id}`)
		end
	end
	local function addFont(id: string, path: string)
		local font = contentId(id, path, false)
		if font then
			local label = Instance.new("TextLabel")
			local set, reason = pcall(function()
				label.FontFace = Font.new(font)
			end)
			if set then
				add(label, `TextLabel:{font}`)
			else
				label:Destroy()
				warn(`[ArenaLoadingClient] optional font skipped: {path}: {reason}`)
			end
		end
	end
	local collected, reason = pcall(function()
		for index, value in Loading.CriticalContentIds do
			addImage(value, `Config.Interface.Loading.CriticalContentIds[{index}]`, false)
		end
		addFont("rbxasset://fonts/families/LuckiestGuy.json", "ArenaLoadingClient.LuckiestGuyFont")
		addFont("rbxasset://fonts/families/HighwayGothic.json", "ArenaLoadingClient.HighwayGothicFont")
		for name, definition in Audio.Gameplay do
			if typeof(definition) ~= "table" or typeof(definition.AssetIds) ~= "table" then
				warn(
					`[ArenaLoadingClient] optional media skipped: Config.Infra.Audio.Gameplay.{name}.AssetIds is not a table`
				)
			else
				for index, value in definition.AssetIds do
					addSound(value, `Config.Infra.Audio.Gameplay.{name}.AssetIds[{index}]`)
				end
			end
		end
		for _, modeId in GameModes.VoteOptions do
			local definition = GameModes.Modes[modeId]
			if definition == nil then
				warn(`[ArenaLoadingClient] optional media skipped: Config.Gameplay.GameModes.Modes.{modeId} is missing`)
			elseif definition.ThumbnailId ~= "" then
				addImage(definition.ThumbnailId, `Config.Gameplay.GameModes.Modes.{modeId}.ThumbnailId`, true)
			end
		end
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		if assets == nil then
			return
		end
		local animations = assets:FindFirstChild(Animations.FolderName)
		if animations and animations:IsA("Folder") then
			for _, clips in Animations.Clips do
				for _, clip in clips do
					local animation = animations:FindFirstChild(clip.Name)
					if animation and animation:IsA("Animation") then
						addExisting(animation)
					end
				end
			end
		end
		local cosmetics = assets:FindFirstChild("Cosmetics")
		if cosmetics and cosmetics:IsA("Folder") then
			local templates = cosmetics:FindFirstChild("Templates")
			if templates and templates:IsA("Folder") then
				for name in Cosmetics.VisualTemplates do
					local template = templates:FindFirstChild(name)
					if template and template:IsA("MeshPart") then
						addExisting(template)
					end
				end
			end
			for _, name in Cosmetics.VisualFolders do
				local folder = cosmetics:FindFirstChild(name)
				if folder and folder:IsA("Folder") then
					addExisting(folder)
				end
			end
		end
		for _, instance in CollectionService:GetTagged(Loading.CriticalPreloadTag) do
			addExisting(instance)
		end
	end)
	if not collected then
		warn(`[ArenaLoadingClient] optional media collection stopped: {reason}`)
		for _, instance in transient do
			instance:Destroy()
		end
		return {}, {}
	end
	return media, transient
end

local function requiredGameplayInstances(deadlineAt: number)
	local function required(parent: Instance, name: string, className: string): Instance
		local path = `{parent:GetFullName()}.{name}`
		local child = parent:WaitForChild(name, math.max(0.001, deadlineAt - os.clock()))
		assert(child ~= nil, `{path} is missing; restore the required {className} and republish Arena`)
		assert(
			child:IsA(className),
			`{path} must have class {className} (found {child.ClassName}); restore the authored instance and republish Arena`
		)
		return child
	end
	local assets = required(ReplicatedStorage, "Assets", "Folder")
	local rigs = required(assets, "Rigs", "Folder")
	required(rigs, "CharacterRig", "Model")
end

local function splashdownTemplates(deadlineAt: number): Folder
	local current: Instance = ReplicatedStorage
	local path = "ReplicatedStorage"
	for _, name in Splashdown.TemplatesPath do
		path ..= `.{name}`
		local child = current:WaitForChild(name, math.max(0.001, deadlineAt - os.clock()))
		assert(
			child and child:IsA("Folder"),
			`[ArenaLoadingClient] {path} must be a Folder; restore the authored Splashdown templates and republish Arena`
		)
		current = child
	end
	for _, courseId in Splashdown.CourseOrder do
		local coursePath = `{path}.{courseId}`
		local course = current:WaitForChild(courseId, math.max(0.001, deadlineAt - os.clock()))
		assert(
			course and course:IsA("Model"),
			`[ArenaLoadingClient] {coursePath} must be a Model; restore the authored course template and republish Arena`
		)
	end
	return current :: Folder
end

local function updatePreloadReady()
	localState.preloadReady = generalPreloadReady and coursePreloadReady
	localState.worldReady = generalWorldReady and courseWorldReady
	changed()
end

local function warmOptionalMedia(
	currentGeneration: number,
	media: { Instance },
	transient: { Instance },
	ownerPath: string
)
	if #media == 0 then
		return
	end
	local terminal = false
	local failures: { string } = {}
	local function active(): boolean
		return not terminal and not destroyed and generation == currentGeneration
	end
	local function cleanup()
		for _, instance in transient do
			instance:Destroy()
		end
	end
	local function finish(outcome: "Completed" | "Failed" | "Timeout", reason: string?)
		if terminal then
			return
		end
		terminal = true
		cleanup()
		if destroyed or generation ~= currentGeneration then
			return
		end
		if outcome == "Timeout" then
			localState.preloadTimedOut = true
		elseif outcome == "Failed" then
			localState.preloadFailed = true
		end
		if reason then
			warn(`[ArenaLoadingClient] optional media warmup at {ownerPath}: {reason}`)
		end
		report("Preload", {
			outcome = outcome,
			durationMs = math.floor((os.clock() - preloadStartedAt) * 1000 + 0.5),
		})
		changed()
	end
	task.delay(Loading.CriticalPreloadTimeoutSeconds, function()
		if not terminal then
			finish("Timeout", `did not finish within {Loading.CriticalPreloadTimeoutSeconds}s`)
		end
	end)
	task.spawn(function()
		local succeeded, reason = pcall(
			ContentProvider.PreloadAsync,
			ContentProvider,
			media,
			function(contentId, status)
				if active() and contentId ~= "" and status ~= Enum.AssetFetchStatus.Success then
					table.insert(failures, `{contentId} returned {status}`)
				end
			end
		)
		if not active() then
			if not terminal then
				finish("Completed", nil)
			end
			return
		end
		if not succeeded then
			finish("Failed", `PreloadAsync threw: {reason}`)
		elseif #failures > 0 then
			finish("Failed", table.concat(failures, "; "))
		else
			finish("Completed", nil)
		end
	end)
end

local function beginCoursePreload(currentGeneration: number)
	if coursePreloadGeneration == currentGeneration then
		return
	end
	coursePreloadGeneration = currentGeneration
	coursePreloadReady = false
	courseWorldReady = false
	updatePreloadReady()
	task.spawn(function()
		local found, templatesOrError = pcall(splashdownTemplates, os.clock() + Loading.CriticalPreloadTimeoutSeconds)
		if destroyed or generation ~= currentGeneration then
			return
		end
		if not found then
			warn(`[ArenaLoadingClient] optional Splashdown preload hierarchy unavailable: {templatesOrError}`)
			coursePreloadReady = true
			updatePreloadReady()
			return
		end
		coursePreloadReady = true
		courseWorldReady = true
		updatePreloadReady()
		warmOptionalMedia(currentGeneration, { templatesOrError }, {}, "ReplicatedStorage.Assets.Maps.Splashdown")
	end)
end

local function beginPreload(currentGeneration: number)
	if destroyed or generation ~= currentGeneration then
		return
	end
	task.spawn(function()
		local found, instancesOrError =
			pcall(requiredGameplayInstances, preloadStartedAt + Loading.CriticalPreloadTimeoutSeconds)
		if destroyed or generation ~= currentGeneration then
			return
		end
		if not found then
			warn(`[ArenaLoadingClient] preload gameplay hierarchy unavailable: {instancesOrError}`)
		else
			generalWorldReady = true
		end
		generalPreloadReady = true
		localState.preloadProgress = 1
		updatePreloadReady()
		local media, transient = optionalMediaInstances()
		warmOptionalMedia(currentGeneration, media, transient, "ArenaLoadingClient.optionalMedia")
	end)
end

local function beginStreaming(currentGeneration: number)
	task.spawn(function()
		if Workspace.StreamingEnabled then
			pcall(player.RequestStreamAroundAsync, player, arenaOrigin(), Loading.CriticalPreloadTimeoutSeconds)
		end
		if destroyed or generation ~= currentGeneration then
			return
		end
		localState.streamReady = true
		changed()
	end)
end

local function maybeBeginCoursePreload(currentGeneration: number)
	if destroyed or generation ~= currentGeneration or not localState.gameLoaded then
		return
	end
	local projected = serverState
	if projected == nil or projected.expectedPlayerCount == 0 then
		return
	end
	if projected.fixedModeId == "Splashdown" then
		beginCoursePreload(currentGeneration)
	elseif not coursePreloadReady then
		coursePreloadReady = true
		updatePreloadReady()
	end
end

onServerSnapshotAccepted = function(recovered)
	if destroyed or not localState.gameLoaded then
		return
	end
	if generalPreloadGeneration ~= generation then
		generalPreloadGeneration = generation
		preloadStartedAt = os.clock()
		maybeBeginCoursePreload(generation)
		beginPreload(generation)
		beginStreaming(generation)
		scheduleInitializationTimeout(generation)
		return
	end
	maybeBeginCoursePreload(generation)
	if recovered then
		scheduleInitializationTimeout(generation)
	end
end

function ArenaLoadingClient.getSnapshot(): Snapshot
	return currentSnapshot()
end

function ArenaLoadingClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	local unsubscribe = listeners.add(listener)
	listener(currentSnapshot())
	return unsubscribe
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

function ArenaLoadingClient.reportStartupIssue(ownerPath: string, reason: string)
	local diagnostic = `{ownerPath}: {reason}`
	warn(`[ArenaLoadingClient] startup issue at {diagnostic}`)
	localState.initializationDegraded = true
	changed()
end

-- Compatibility for existing client systems while callers move to the explicit
-- nonfatal diagnostic name. Client faults do not deny an admitted player entry.
function ArenaLoadingClient.failStartup(ownerPath: string, reason: string)
	ArenaLoadingClient.reportStartupIssue(ownerPath, reason)
end

function ArenaLoadingClient.markBallotPresented(startsAt: number)
	if startsAt <= 0 or reportedBallots[startsAt] then
		return
	end
	reportedBallots[startsAt] = true
	report("BallotImpression", { startsAt = startsAt })
end

function ArenaLoadingClient.retryInitialization()
	if destroyed or serverState == nil or snapshotError ~= nil then
		return
	end
	generation += 1
	readyTaskRunning = false
	localState.preloadReady = false
	localState.preloadProgress = 0
	localState.preloadFailed = false
	localState.preloadTimedOut = false
	localState.streamReady = false
	localState.worldReady = false
	generalPreloadReady = false
	generalWorldReady = false
	coursePreloadReady = true
	courseWorldReady = true
	generalPreloadGeneration = generation
	preloadStartedAt = os.clock()
	maybeBeginCoursePreload(generation)
	beginPreload(generation)
	beginStreaming(generation)
	changed()
	scheduleInitializationTimeout(generation)
end

function ArenaLoadingClient.start()
	if started then
		return
	end
	started = true
	destroyed = false
	readyTaskRunning = false
	generation += 1
	startedAt = os.clock()
	preloadStartedAt = startedAt

	watchRuntimeState()
	table.insert(connections, player:GetAttributeChangedSignal("ArenaAdmission"):Connect(changed))
	table.insert(connections, player:GetAttributeChangedSignal("ArenaReady"):Connect(changed))

	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		if destroyed then
			return
		end
		local currentGeneration = generation
		localState.gameLoaded = true
		report("Stage", {
			stage = "GameLoaded",
			durationMs = math.floor((os.clock() - startedAt) * 1000 + 0.5),
		})
		preloadStartedAt = os.clock()
		changed()
		generalPreloadGeneration = currentGeneration
		maybeBeginCoursePreload(currentGeneration)
		beginPreload(currentGeneration)
		beginStreaming(currentGeneration)
		scheduleInitializationTimeout(currentGeneration)
	end)

	scheduleInitializationTimeout(generation)
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
	listeners.clear()
	started = false
end

return ArenaLoadingClient
