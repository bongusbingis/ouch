-- Description: Loads SimulationClient source with injected Roblox dependencies and verifies degraded startup stays admitted and live.
--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, callback in callbacks do
				callback(...)
			end
		end,
		Wait = function()
			error("startup used an unbounded signal wait", 0)
		end,
	}
end

local function node(className: string, name: string): any
	local children = {}
	local attributes = {}
	local attributeSignals = {}
	local result: any
	local methods = {}
	result = setmetatable({ ClassName = className, Name = name, _children = children }, {
		__index = function(self, key)
			return methods[key] or children[key] or rawget(self, key)
		end,
		__newindex = function(self, key, value)
			if key == "Parent" and value then
				value._children[self.Name] = self
			end
			rawset(self, key, value)
		end,
	})
	function methods:WaitForChild(childName: string, _timeout: number?): any
		return children[childName]
	end
	function methods:FindFirstChild(childName: string): any
		return children[childName]
	end
	function methods:IsA(expected: string): boolean
		return self.ClassName == expected
	end
	function methods:GetFullName(): string
		return if self.Parent then self.Parent:GetFullName() .. "." .. self.Name else self.Name
	end
	function methods:GetAttribute(key: string): any
		return attributes[key]
	end
	function methods:SetAttribute(key: string, value: any)
		attributes[key] = value
		if attributeSignals[key] then
			attributeSignals[key]:Fire()
		end
	end
	function methods:GetAttributeChangedSignal(key: string): any
		attributeSignals[key] = attributeSignals[key] or signal()
		return attributeSignals[key]
	end
	result.ChildAdded = signal()
	result.Destroying = signal()
	return result
end

local function add(parent: any, child: any): any
	child.Parent = parent
	return child
end

local function loadSimulation(scenario: string, preludePresented: boolean): ({ any }, any, { boolean }, { string })
	local now = 0
	local delayed: { { at: number, callback: () -> () } } = {}
	local suspended: { thread } = {}
	local starts: { string } = {}
	local inputCalls: { boolean } = {}
	local loading = { failed = {}, simulationReady = 0 }
	local replicated = node("ReplicatedStorage", "ReplicatedStorage")
	local replicatedFirst = node("ReplicatedFirst", "ReplicatedFirst")
	replicatedFirst:SetAttribute("ReactLoadingPresented", if preludePresented then true else nil)
	local player = node("Player", "LocalPlayer")
	player:SetAttribute("ArenaReady", true)
	local playerScripts = add(player, node("Folder", "PlayerScripts"))
	local client = add(playerScripts, node("Folder", "Client"))
	local clientModules = add(client, node("Folder", "Modules"))
	local ui = add(clientModules, node("Folder", "UI"))
	local input = add(clientModules, node("Folder", "Input"))
	local presentation = add(clientModules, node("Folder", "Presentation"))
	local movement = add(clientModules, node("Folder", "Movement"))
	local config = add(replicated, node("Folder", "Config"))
	local configInfra = add(config, node("Folder", "Infra"))
	local configGameplay = add(config, node("Folder", "Gameplay"))
	local shared = add(replicated, node("Folder", "Shared"))
	local sharedGame = add(shared, node("Folder", "Game"))
	local adapters = add(sharedGame, node("Folder", "Adapters"))
	local mapFeatures = add(sharedGame, node("Folder", "MapFeatures"))
	local cosmetics = add(sharedGame, node("Folder", "Cosmetics"))
	local starterPlayer = node("StarterPlayer", "StarterPlayer")
	local scriptNode = add(node("Folder", "Scripts"), node("LocalScript", "SimulationClient"))
	local values: { [string]: any } = {}
	local function module(parent: any, name: string, value: any)
		local script = add(parent, node("ModuleScript", name))
		values[script:GetFullName()] = value
		return script
	end
	module(ui, "ArenaLoadingClient", {
		failStartup = function(path, reason)
			table.insert(loading.failed, `{path}: {reason}`)
		end,
		getSnapshot = function()
			return { localReady = true }
		end,
		subscribe = function(callback)
			callback({ localReady = true })
			return function() end
		end,
		markSimulationReady = function()
			loading.simulationReady += 1
		end,
	})
	local combat = {
		setInputEnabled = function(value)
			table.insert(inputCalls, value)
			if scenario == "input-throws" then
				error("simulated input control fault")
			end
		end,
		setCameraEnabled = function() end,
	}
	module(starterPlayer, "PlayerModule", { Combat = combat })
	module(configInfra, "Debug", { CombatTrace = false })
	module(configGameplay, "GameModes", {
		IsCombat = function()
			return true
		end,
	})
	module(config, "LiveConfig", {
		loadModules = function()
			return {}
		end,
	})
	module(adapters, "ConfigReplication", { startClient = function() end })
	local function core(name: string): any
		return {
			start = function()
				table.insert(starts, name)
				if scenario == "core-throws" and name == "AssistConfig" then
					error("simulated core start fault")
				end
			end,
			stop = function() end,
			destroy = function() end,
		}
	end
	module(input, "InputRouter", core("InputRouter"))
	module(input, "CombatInputSender", {
		start = function()
			table.insert(starts, "CombatInputSender")
		end,
		destroy = function() end,
		onIntent = function()
			return function() end
		end,
	})
	module(input, "AssistConfig", core("AssistConfig"))
	module(input, "CameraAssist", core("CameraAssist"))
	module(presentation, "CombatState", core("CombatState"))
	module(presentation, "VoteCamera", core("VoteCamera"))
	local presenterNames = {
		"ArmIK",
		"BallVisuals",
		"DamageFeedback",
		"DeathEffects",
		"HammerVisuals",
		"SplatEffects",
		"MatchAudio",
		"GameAudio",
		"PlayerHighlights",
		"SplashdownCamera",
		"SplashEffects",
		"SplashdownAudio",
		"JumpPadVisuals",
		"BumperVisuals",
		"HazardVisuals",
		"HazardCarriers",
		"EmotePlayback",
		"FanAirflow",
		"ChargeAim",
		"WeaponAnimations",
	}
	for _, name in presenterNames do
		module(presentation, name, {
			start = function()
				table.insert(starts, name)
				if scenario == "splat-require-throws" and name == "SplatEffects" then
					error("simulated SplatEffects start fault")
				end
			end,
			destroy = function() end,
			onEvent = function() end,
			notifyElim = function() end,
			onIntent = function() end,
		})
	end
	module(movement, "PlatformRider", core("PlatformRider"))
	module(mapFeatures, "RotatingPlatforms", {
		load = function()
			table.insert(starts, "RotatingPlatforms")
		end,
		destroy = function() end,
	})
	module(cosmetics, "CosmeticEffects", {
		start = function()
			table.insert(starts, "CosmeticEffects")
		end,
		destroy = function() end,
		onEvent = function() end,
	})
	local matchState = add(replicated, node("Folder", "MatchState"))
	matchState:SetAttribute("phase", "Active")
	matchState:SetAttribute("modeId", "Dodgeball")
	local services = {
		ReplicatedStorage = replicated,
		ReplicatedFirst = replicatedFirst,
		Players = { LocalPlayer = player },
		StarterPlayer = starterPlayer,
		RunService = {
			IsStudio = function()
				return false
			end,
		},
	}
	module(shared, "Network", {
		on = function()
			return function() end
		end,
	})
	local function resume(thread: thread)
		local ok, reason = coroutine.resume(thread)
		assert(ok, tostring(reason))
		if coroutine.status(thread) == "suspended" then
			table.insert(suspended, thread)
		end
	end
	local function advance(seconds: number)
		now += seconds
		for _, entry in delayed do
			if entry.at <= now then
				entry.at = math.huge
				entry.callback()
			end
		end
	end
	local environment: any = {
		game = {
			GetService = function(_, name)
				return assert(services[name], `unexpected service {name}`)
			end,
		},
		warn = function() end,
		task = {
			wait = function()
				now += 1
				return now
			end,
			delay = function(seconds, callback)
				table.insert(delayed, { at = now + seconds, callback = callback })
			end,
			spawn = function(callback)
				resume(coroutine.create(callback))
			end,
		},
		os = {
			clock = function()
				return now
			end,
		},
		require = function(target)
			if scenario == "splat-hangs" and target.Name == "SplatEffects" then
				coroutine.yield()
			elseif scenario == "splat-require-throws" and target.Name == "SplatEffects" then
				error("simulated SplatEffects require fault")
			end
			return assert(values[target:GetFullName()], `unexpected require {target:GetFullName()}`)
		end,
		script = scriptNode,
	}
	local ok, reason = pcall(function()
		luau.load(
			luau.compile(fs.readFile("places/arena/client/Scripts/SimulationClient.client.luau")),
			{ debugName = "SimulationClient", environment = environment, injectGlobals = true }
		)()
	end)
	assert(ok, `{scenario}: degraded SimulationClient startup aborted: {tostring(reason)}`)
	advance(5)
	return starts, loading, inputCalls, {}
end

for _, scenario in { "splat-require-throws", "splat-hangs", "core-throws", "input-throws" } do
	local starts, loading, inputs = loadSimulation(scenario, true)
	assert(#loading.failed == 0, `{scenario}: client fault called ArenaLoadingClient.failStartup`)
	assert(loading.simulationReady == 1, `{scenario}: simulation readiness was withheld`)
	assert(table.find(starts, "BallVisuals") ~= nil, `{scenario}: healthy presenters did not start`)
	if scenario == "splat-require-throws" or scenario == "splat-hangs" then
		assert(table.find(starts, "SplatEffects") == nil, "failed presenter was treated as started")
		assert(table.find(inputs, true) ~= nil, "optional presenter failure retained disabled combat input")
	end
end

do
	local _starts, loading = loadSimulation("healthy", false)
	assert(
		#loading.failed == 0 and loading.simulationReady == 1,
		"missing React prelude did not reach bounded simulation startup"
	)
end

print("Arena startup SimulationClient actual-source degradation regression: 5 scenarios passed")
