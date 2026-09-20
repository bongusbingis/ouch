-- Description: Loads ArenaLoadingClient source with injected Roblox services and drives ContentProvider outcomes without Studio.
--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

type Signal = { Connect: (self: Signal, callback: (...any) -> ()) -> { Disconnect: (self: any) -> () } }

local function signal(): any
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			local connected = true
			return {
				Disconnect = function()
					connected = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, callback in callbacks do
				callback(...)
			end
		end,
	}
end

local function makeNode(className: string, nodeName: string): any
	local children = {}
	local attributes = {}
	local changed = {}
	local node: any
	local methods = {}
	local meta = {
		__index = function(self, key)
			if methods[key] then
				return methods[key]
			end
			if children[key] then
				return children[key]
			end
			return rawget(self, key)
		end,
		__newindex = function(self, key, value)
			if key == "Parent" and value then
				value._children[self.Name] = self
			end
			rawset(self, key, value)
		end,
	}
	node = setmetatable({
		ClassName = className,
		Name = nodeName,
		_children = children,
		_attributes = attributes,
		ChildAdded = signal(),
	}, meta)
	function methods:WaitForChild(childName: string, _timeout: number?): any
		return assert(children[childName], `missing {self.Name}.{childName}`)
	end
	function methods:FindFirstChild(childName: string): any
		return children[childName]
	end
	function methods:IsA(expected: string): boolean
		return self.ClassName == expected
	end
	function methods:GetChildren(): { any }
		local result = {}
		for _, child in children do
			table.insert(result, child)
		end
		return result
	end
	function methods:GetFullName(): string
		return if self.Parent then self.Parent:GetFullName() .. "." .. self.Name else self.Name
	end
	function methods:GetAttribute(name: string): any
		return attributes[name]
	end
	function methods:SetAttribute(name: string, value: any)
		attributes[name] = value
		if changed[name] then
			changed[name]:Fire()
		end
	end
	function methods:GetAttributeChangedSignal(name: string): Signal
		changed[name] = changed[name] or signal()
		return changed[name]
	end
	function methods:GetPropertyChangedSignal(name: string): Signal
		changed[name] = changed[name] or signal()
		return changed[name]
	end
	function methods:Destroy()
		self.Destroyed = true
	end
	return node
end

local function add(parent: any, child: any): any
	child.Parent = parent
	parent.ChildAdded:Fire(child)
	return child
end

local function loadClient(scenario: string, splashdown: boolean?, missingRig: boolean?, missingSnapshot: boolean?)
	local delayed: { { at: number, callback: () -> () } } = {}
	local now = 0
	local created = {}
	local requests = {}
	local lateCallbacks = {}
	local warnings = {}
	local replicated = makeNode("ReplicatedStorage", "ReplicatedStorage")
	local shared = add(replicated, makeNode("Folder", "Shared"))
	local gameFolder = add(shared, makeNode("Folder", "Game"))
	local util = add(gameFolder, makeNode("Folder", "Util"))
	local modes = add(gameFolder, makeNode("Folder", "Modes"))
	local config = add(replicated, makeNode("Folder", "Config"))
	local infra = add(config, makeNode("Folder", "Infra"))
	local cosmetics = add(config, makeNode("Folder", "Cosmetics"))
	local gameplay = add(config, makeNode("Folder", "Gameplay"))
	local interface = add(config, makeNode("Folder", "Interface"))
	local assets = add(replicated, makeNode("Folder", "Assets"))
	local rigs = add(assets, makeNode("Folder", "Rigs"))
	if not missingRig then
		add(rigs, makeNode("Model", "CharacterRig"))
	end
	add(assets, makeNode("Folder", "Animations"))
	local cosmeticAssets = add(assets, makeNode("Folder", "Cosmetics"))
	local templates = add(cosmeticAssets, makeNode("Folder", "Templates"))
	add(templates, makeNode("MeshPart", "Dodgeball"))
	if not missingSnapshot then
		local loadState = add(replicated, makeNode("Folder", "ArenaLoadState"))
		local snapshotValue = add(loadState, makeNode("StringValue", "Snapshot"))
		snapshotValue.Value = "valid"
	end
	local mapRoot = add(assets, makeNode("Folder", "Maps"))
	local courses = add(mapRoot, makeNode("Folder", "Splashdown"))
	add(courses, makeNode("Model", "CourseA"))

	local modules = {
		Listeners = {
			new = function()
				return {
					add = function()
						return function() end
					end,
					emit = function() end,
					clear = function() end,
				}
			end,
		},
		Animations = { FolderName = "Animations", Clips = {} },
		Audio = { Gameplay = { Pop = { AssetIds = { "rbxassetid://117503154823137" } } } },
		Cosmetics = { VisualTemplates = { Dodgeball = {} }, VisualFolders = {} },
		GameModes = {
			VoteOptions = { "Dodgeball" },
			Modes = {
				Dodgeball = { Enabled = true, Queue = "Arena", ThumbnailId = "" },
				Splashdown = { Enabled = true, Queue = "Splashdown", ThumbnailId = "" },
			},
		},
		Queues = {
			isEnabled = function(id)
				return id == "Arena" or id == "Splashdown"
			end,
			get = function(id)
				return {
					ModeSelection = if id == "Splashdown"
						then { Strategy = "Fixed", ModeId = "Splashdown" }
						else { Strategy = "Vote" },
				}
			end,
		},
		Splashdown = { TemplatesPath = { "Assets", "Maps", "Splashdown" }, CourseOrder = { "CourseA" } },
		Loading = {
			CriticalPreloadTimeoutSeconds = 1,
			CriticalInitializationTimeoutSeconds = 10,
			ArenaReadyRetrySeconds = 1,
			CriticalContentIds = { "rbxassetid://136021539696619" },
			CriticalPreloadTag = "CriticalPreload",
		},
		ModeOptions = {
			resolve = function(value)
				return value
			end,
			equals = function(a, b)
				return #a == #b and a[1] == b[1]
			end,
		},
		Network = {
			fireServer = function(name)
				table.insert(requests, { remote = name })
			end,
		},
		ArenaOrigin = function()
			return { X = 0, Y = 0, Z = 0 }
		end,
	}
	local function moduleNode(parent: any, name: string, key: string)
		local result = add(parent, makeNode("ModuleScript", name))
		result._key = key
		return result
	end
	moduleNode(util, "Listeners", "Listeners")
	moduleNode(infra, "Animations", "Animations")
	moduleNode(infra, "Audio", "Audio")
	moduleNode(cosmetics, "Cosmetics", "Cosmetics")
	moduleNode(gameplay, "GameModes", "GameModes")
	moduleNode(gameplay, "Queues", "Queues")
	moduleNode(gameplay, "Splashdown", "Splashdown")
	moduleNode(interface, "Loading", "Loading")
	moduleNode(modes, "ModeOptions", "ModeOptions")
	moduleNode(shared, "Network", "Network")
	local scriptParent = makeNode("Folder", "UI")
	local scriptModules = makeNode("Folder", "Modules")
	scriptParent.Parent = scriptModules
	local presentation = add(scriptModules, makeNode("Folder", "Presentation"))
	moduleNode(presentation, "ArenaOrigin", "ArenaOrigin")
	local scriptNode = add(scriptParent, makeNode("ModuleScript", "ArenaLoadingClient"))
	local player = makeNode("Player", "LocalPlayer")
	player:SetAttribute("ArenaAdmission", "Matched")
	local contentProvider = {
		PreloadAsync = function(_, inputs, callback)
			table.insert(requests, inputs)
			local isOptional = inputs[1]._transient == true or inputs[1].Name == "Splashdown"
			local isTransient = inputs[1]._transient == true
			if isOptional and scenario == "throw" then
				error("simulated optional media throw")
			end
			if isOptional and (scenario == "timeout" or scenario == "late" or scenario == "destroy") then
				table.insert(lateCallbacks, { callback = callback, thread = coroutine.running() })
				coroutine.yield()
			end
			for _, input in inputs do
				callback(
					if type(input) == "string" then input else "rbxassetid://mock",
					if isOptional and (scenario == "failure" or scenario == "course_failure")
						then "Failure"
						else "Success"
				)
			end
		end,
	}
	local instance = {
		new = function(className: string)
			local value = makeNode(className, className)
			value._transient = true
			table.insert(created, value)
			return value
		end,
	}
	local services = {
		ReplicatedStorage = replicated,
		Players = { LocalPlayer = player },
		CollectionService = {
			GetTagged = function()
				return {}
			end,
		},
		ContentProvider = contentProvider,
		HttpService = {
			JSONDecode = function(_, value)
				assert(value == "valid", "expected the valid server snapshot")
				return {
					schemaVersion = 2,
					revision = 1,
					expectedPlayerCount = 1,
					arrivedPlayerCount = 0,
					readyPlayerCount = 0,
					deadlineAt = 0,
					gateReleased = false,
					queueId = if splashdown then "Splashdown" else "Arena",
					fixedModeId = if splashdown then "Splashdown" else nil,
					modeOptions = if splashdown then { "Splashdown" } else { "Dodgeball" },
				}
			end,
		},
		Workspace = { StreamingEnabled = false },
	}
	local environment: any = {
		game = {
			GetService = function(_, name)
				return assert(services[name], `unexpected service {name}`)
			end,
			IsLoaded = function()
				return true
			end,
			Loaded = signal(),
		},
		Instance = instance,
		Font = {
			new = function(value)
				return { Family = value }
			end,
		},
		Enum = { AssetFetchStatus = { Success = "Success" } },
		warn = function(message)
			table.insert(warnings, message)
		end,
		os = {
			clock = function()
				return now
			end,
		},
		task = {
			spawn = function(callback)
				local thread = coroutine.create(callback)
				local ok, reason = coroutine.resume(thread)
				assert(ok, tostring(reason))
			end,
			delay = function(seconds, callback)
				table.insert(delayed, { at = now + seconds, callback = callback })
			end,
			wait = function() end,
		},
		require = function(target)
			return assert(modules[target._key], `unexpected require {target.Name}`)
		end,
		script = scriptNode,
	}
	local client = luau.load(
		luau.compile(fs.readFile("places/arena/client/Modules/UI/ArenaLoadingClient.luau")),
		{ debugName = "ArenaLoadingClient", environment = environment, injectGlobals = true }
	)()
	local function advance(seconds: number)
		now += seconds
		for _, entry in delayed do
			if entry.at <= now then
				entry.callback()
				entry.at = math.huge
			end
		end
	end
	return client, requests, created, lateCallbacks, warnings, advance, player, replicated
end

local function transientRequests(requests): { any }
	local result = {}
	for _, request in requests do
		for _, item in request do
			if type(item) == "table" and item._transient then
				table.insert(result, item)
			end
		end
	end
	return result
end

for _, scenario in { "success", "failure", "throw", "timeout", "late", "destroy" } do
	local client, requests, created, callbacks, _warnings, advance = loadClient(scenario)
	client.start()
	local media = transientRequests(requests)
	assert(#media >= 2, `{scenario}: typed optional media were not passed to ContentProvider`)
	local sawSound, sawFont = false, false
	for _, item in media do
		assert(type(item) == "table", `{scenario}: optional media request passed a raw string`)
		sawSound = sawSound or item.ClassName == "Sound"
		sawFont = sawFont or item.ClassName == "TextLabel"
	end
	assert(sawSound and sawFont, `{scenario}: expected Sound and Font typed optional media`)
	local sawCosmetic = false
	for _, request in requests do
		for _, item in request do
			if type(item) == "table" then
				sawCosmetic = sawCosmetic or (item.Name == "Dodgeball" and item.ClassName == "MeshPart")
			end
		end
	end
	assert(sawCosmetic, `{scenario}: keyed cosmetic template was not preloaded`)
	if scenario == "destroy" then
		client.destroy()
	else
		advance(2)
	end
	for _, pending in callbacks do
		pending.callback("rbxassetid://late", "Success")
		local resumed, reason = coroutine.resume(pending.thread)
		assert(resumed, tostring(reason))
	end
	local snapshot = client.getSnapshot()
	assert(
		snapshot.fatalError == nil,
		`{scenario}: optional media failure/timeout blocked startup: {tostring(snapshot.fatalError)}`
	)
	assert(
		snapshot.preloadReady == true and snapshot.worldReady == true,
		`{scenario}: optional media did not release core preload readiness`
	)
	if scenario == "timeout" or scenario == "late" then
		assert(snapshot.preloadTimedOut, `{scenario}: suspended optional media did not reach its timeout diagnostic`)
	elseif scenario == "failure" or scenario == "throw" then
		assert(snapshot.preloadFailed, `{scenario}: optional media failure did not set a diagnostic flag`)
	end
	for _, item in created do
		assert(item.Destroyed == true, `{scenario}: transient {item.ClassName} was not cleaned up`)
	end
	if scenario ~= "destroy" then
		client.markUiPresented()
		client.markVotePrepared()
		client.markSimulationReady()
		assert(client.getSnapshot().localReady, `{scenario}: optional media issue prevented public readiness`)
		local reportedReady = false
		for _, request in requests do
			reportedReady = reportedReady or request.remote == "ArenaClientReady"
		end
		assert(reportedReady, `{scenario}: public readiness did not report ArenaClientReady`)
	end
end

do
	local client, requests, _created, _callbacks, _warnings, advance = loadClient("course_failure", true)
	client.start()
	advance(2)
	local sawCourse = false
	for _, request in requests do
		if type(request[1]) == "table" then
			sawCourse = sawCourse or (request[1].Name == "Splashdown")
		end
	end
	assert(sawCourse, "Splashdown course media was not submitted to ContentProvider")
	local snapshot = client.getSnapshot()
	assert(snapshot.fatalError == nil and snapshot.preloadReady, "Splashdown media failure blocked arena entry")
end

do
	local client, _requests, _created, _callbacks, warnings, advance = loadClient("success", false, true)
	client.start()
	advance(2)
	local snapshot = client.getSnapshot()
	assert(snapshot.fatalError == nil and snapshot.preloadReady, "missing gameplay hierarchy blocked entry")
	assert(snapshot.worldReady == false, "missing gameplay hierarchy incorrectly reported the world ready")
	assert(#warnings > 0, "missing gameplay hierarchy did not emit a diagnostic")
end

do
	local client, requests = loadClient("success", false, false, true)
	client.start()
	client.markUiPresented()
	client.markVotePrepared()
	client.markSimulationReady()
	assert(client.getSnapshot().localReady == false, "client became ready without an authoritative server snapshot")
	for _, request in requests do
		assert(request.remote ~= "ArenaClientReady", "client reported ready without an authoritative server snapshot")
	end
end

do
	local client, requests, _created, _callbacks, _warnings, advance = loadClient("success")
	client.start()
	advance(2)
	client.markUiPresented()
	client.markVotePrepared()
	client.markSimulationReady()
	client.reportStartupIssue("SimulationClient", "simulated core start fault")
	local snapshot = client.getSnapshot()
	assert(snapshot.initializationDegraded == true, "nonfatal startup issue was not exposed for diagnostics")
	assert(
		snapshot.fatalError == nil and snapshot.localReady,
		"nonfatal startup issue withheld matched-client readiness"
	)
	local reportedReady = false
	for _, request in requests do
		reportedReady = reportedReady or request.remote == "ArenaClientReady"
	end
	assert(reportedReady, "nonfatal startup issue did not report matched client readiness")
end

do
	local client, requests, _created, _callbacks, _warnings, advance, player = loadClient("success")
	client.start()
	advance(2)
	player:SetAttribute("ArenaAdmission", "Rejected")
	client.markUiPresented()
	client.markVotePrepared()
	client.markSimulationReady()
	assert(client.getSnapshot().localReady == false, "client fabricated readiness after authoritative rejection")
	for _, request in requests do
		assert(request.remote ~= "ArenaClientReady", "client reported readiness after authoritative rejection")
	end
end

do
	local client, requests, _created, _callbacks, _warnings, advance, _player, replicated =
		loadClient("success", false, false, true)
	client.start()
	client.markUiPresented()
	client.markVotePrepared()
	client.markSimulationReady()
	advance(11)
	assert(client.getSnapshot().localReady == false, "startup timeout fabricated a missing authoritative snapshot")
	local loadState = add(replicated, makeNode("Folder", "ArenaLoadState"))
	local snapshot = makeNode("StringValue", "Snapshot")
	snapshot.Value = "valid"
	add(loadState, snapshot)
	advance(2)
	assert(client.getSnapshot().localReady, "late authoritative snapshot did not recover matched-client readiness")
	local reportedReady = false
	for _, request in requests do
		reportedReady = reportedReady or request.remote == "ArenaClientReady"
	end
	assert(reportedReady, "late authoritative snapshot did not report recovered client readiness")
end

print("ArenaLoadingClient actual-source preload and startup-admission regressions: 12 scenarios passed")
