-- Description: Runs ArenaUI source with a root-render fault and missing prelude to verify the arena remains presented and cleans bootstrap state.
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
	}
end

local function node(className: string, name: string): any
	local children = {}
	local attributes = {}
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
	end
	result.Destroying = signal()
	return result
end

local function add(parent: any, child: any): any
	child.Parent = parent
	return child
end

local function runArenaUi(scenario: string)
	local now = 0
	local delayed: { { at: number, callback: () -> () } } = {}
	local suspended: { thread } = {}
	local renders: { string } = {}
	local containers: { any } = {}
	local starts: { string } = {}
	local loading = { uiPresented = 0, issues = {}, replicaRequests = 0, teleportRegistered = 0, cameraReleased = 0 }
	local replicated = node("ReplicatedStorage", "ReplicatedStorage")
	local replicatedFirst = node("ReplicatedFirst", "ReplicatedFirst")
	local packages = add(replicated, node("Folder", "Packages"))
	local shared = add(replicated, node("Folder", "Shared"))
	local sharedGame = add(shared, node("Folder", "Game"))
	local sharedUi = add(shared, node("Folder", "UI"))
	local components = add(sharedUi, node("Folder", "Components"))
	local services = add(sharedUi, node("Folder", "Services"))
	local economy = add(sharedGame, node("Folder", "Economy"))
	local settings = add(sharedGame, node("Folder", "Settings"))
	local progression = add(sharedGame, node("Folder", "Progression"))
	local placeClient = node("Folder", "Client")
	local scriptParent = add(placeClient, node("Folder", "Scripts"))
	local scriptNode = add(scriptParent, node("LocalScript", "ArenaUI"))
	local modulesRoot = add(placeClient, node("Folder", "Modules"))
	local arenaUiModules = add(modulesRoot, node("Folder", "UI"))
	local arenaUi = add(placeClient, node("Folder", "UI"))
	local starterPlayer = node("StarterPlayer", "StarterPlayer")
	local player = node("Player", "LocalPlayer")
	local values: { [string]: any } = {}
	local function module(parent: any, name: string, value: any)
		local script = add(parent, node("ModuleScript", name))
		values[script:GetFullName()] = value
	end
	local function lifecycle(name: string): any
		return {
			start = function()
				table.insert(starts, name)
			end,
			stop = function() end,
			destroy = function() end,
		}
	end
	local react = {
		createElement = function(component, props)
			return { component = component, props = props }
		end,
	}
	local function makeContainer(name: string): any
		local container = {
			Name = name,
			Destroyed = false,
			Destroy = function(self)
				self.Destroyed = true
			end,
		}
		table.insert(containers, container)
		return container
	end
	local reactRoblox = {
		createRoot = function(container)
			return {
				render = function(_, element)
					table.insert(renders, container.Name)
					if scenario == "combat-render-throws" and container.Name == "ArenaCombatRoot" then
						error("simulated combat HUD render fault")
					end
					if element.props and element.props.OnPresented then
						element.props.OnPresented()
					end
				end,
				unmount = function() end,
			}
		end,
	}
	module(packages, "react", react)
	module(packages, "react-roblox", reactRoblox)
	module(packages, "replica", {
		RequestData = function()
			loading.replicaRequests += 1
		end,
	})
	module(shared, "Network", { fireServer = function() end })
	module(components, "LoadingScreen", {})
	module(components, "EmoteWheel", {})
	module(services, "ReactRoot", {
		create = function(name)
			return makeContainer(name)
		end,
		createDetached = function(name)
			return makeContainer(name)
		end,
	})
	module(services, "TeleportGui", {
		prepare = function() end,
		register = function()
			loading.teleportRegistered += 1
			return false
		end,
	})
	module(services, "EmoteWheelController", {
		start = function()
			table.insert(starts, "EmoteWheelController")
		end,
		stop = function() end,
		subscribe = function(callback)
			callback({ open = false })
			return function() end
		end,
	})
	module(services, "CombatMenuClient", lifecycle("CombatMenuClient"))
	module(services, "UIFeedback", lifecycle("UIFeedback"))
	module(economy, "EconomyStore", lifecycle("EconomyStore"))
	module(economy, "ShopClient", lifecycle("ShopClient"))
	module(settings, "SettingsStore", lifecycle("SettingsStore"))
	module(progression, "SeasonStore", lifecycle("SeasonStore"))
	module(arenaUiModules, "ArenaLoadingClient", {
		start = function()
			table.insert(starts, "ArenaLoadingClient")
		end,
		destroy = function() end,
		markUiPresented = function()
			loading.uiPresented += 1
		end,
		reportStartupIssue = function(path, reason)
			table.insert(loading.issues, `{path}: {reason}`)
		end,
		failStartup = function(path, reason)
			table.insert(loading.issues, `{path}: {reason}`)
		end,
	})
	for _, name in
		{
			"ModeVoteClient",
			"SplashdownClient",
			"ArenaTeleportClient",
			"PostMatchClient",
			"ArenaCoreUI",
			"ThrowUXClient",
		}
	do
		module(arenaUiModules, name, lifecycle(name))
	end
	module(arenaUiModules, "ArenaMenuClient", {
		getSnapshot = function()
			return { open = false }
		end,
	})
	for _, name in { "ArenaApp", "CombatHUD", "ArenaMenu", "PostMatchApp" } do
		module(arenaUi, name, {})
	end
	module(starterPlayer, "PlayerModule", {
		Combat = {
			registerHudExclusion = function()
				return true
			end,
			releaseCameraSuppression = function()
				loading.cameraReleased += 1
			end,
			requestCameraSuppression = function() end,
		},
	})
	local servicesByName = {
		ReplicatedFirst = replicatedFirst,
		ReplicatedStorage = replicated,
		Players = { LocalPlayer = player },
		StarterPlayer = starterPlayer,
	}
	local function resume(thread: thread)
		local ok, reason = coroutine.resume(thread)
		assert(ok, tostring(reason))
		if coroutine.status(thread) == "suspended" then
			table.insert(suspended, thread)
		end
	end
	local environment: any = {
		game = {
			GetService = function(_, name)
				return assert(servicesByName[name], `unexpected service {name}`)
			end,
		},
		Enum = { ScreenInsets = { None = "None", CoreUISafeInsets = "Safe" } },
		warn = function() end,
		task = {
			delay = function(_, callback)
				table.insert(delayed, { at = now + _, callback = callback })
			end,
			spawn = function(callback)
				resume(coroutine.create(callback))
			end,
			wait = function() end,
		},
		require = function(target)
			if scenario == "ui-feedback-hangs" and target.Name == "UIFeedback" then
				coroutine.yield()
			end
			return assert(values[target:GetFullName()], `unexpected require {target:GetFullName()}`)
		end,
		script = scriptNode,
	}
	local ok, reason = pcall(function()
		luau.load(
			luau.compile(fs.readFile("places/arena/client/Scripts/ArenaUI.client.luau")),
			{ debugName = "ArenaUI", environment = environment, injectGlobals = true }
		)()
	end)
	assert(ok, `{scenario}: ArenaUI startup aborted: {tostring(reason)}`)
	local function advance(seconds: number)
		now += seconds
		for _, entry in delayed do
			if entry.at <= now then
				entry.at = math.huge
				entry.callback()
			end
		end
	end
	local function resumeSuspended()
		local pending = suspended
		suspended = {}
		for _, thread in pending do
			resume(thread)
		end
	end
	return replicatedFirst, renders, containers, starts, loading, scriptNode, advance, resumeSuspended
end

do
	local replicatedFirst, renders, containers, starts, loading = runArenaUi("combat-render-throws")
	assert(
		replicatedFirst:GetAttribute("ReactLoadingPresented") == true,
		"prelude watchdog did not release SimulationClient"
	)
	assert(table.find(renders, "ArenaPostMatchRoot") ~= nil, "render failure prevented later healthy roots")
	assert(
		table.find(starts, "UIFeedback") ~= nil and table.find(starts, "ThrowUXClient") ~= nil,
		"render failure stopped healthy UI services"
	)
	assert(loading.uiPresented > 0, "render failure withheld UI presentation readiness")
	assert(#loading.issues > 0, "render failure was not recorded as a nonfatal startup diagnostic")
	assert(loading.replicaRequests == 1, "recoverable UI fault skipped authoritative Replica.RequestData")
	assert(loading.teleportRegistered == 1, "recoverable UI fault skipped return-teleport registration")
	assert(loading.cameraReleased > 0, "recoverable UI fault skipped EmoteWheel camera subscription")
	local bootstrapRemoved = false
	local failedRootDisposed = false
	for _, container in containers do
		if container.Name == "ArenaLoadingBootstrap" then
			bootstrapRemoved = container.Destroyed
		elseif container.Name == "ArenaCombatRoot" then
			failedRootDisposed = container.Destroyed
		end
	end
	assert(bootstrapRemoved, "startup overlay was retained after a recoverable UI fault")
	assert(failedRootDisposed, "failed UI root was retained after render cleanup")
end

do
	local replicatedFirst, renders, containers, _starts, _loading, scriptNode, advance, resumeSuspended =
		runArenaUi("ui-feedback-hangs")
	assert(
		table.find(renders, "ArenaLoadingBootstrap") ~= nil,
		"suspended UI load did not first present the arrival overlay"
	)
	advance(15)
	assert(
		replicatedFirst:GetAttribute("ReactLoadingPresented") == true,
		"watchdog did not release a suspended UI startup"
	)
	local bootstrapDestroyed = false
	for _, container in containers do
		if container.Name == "ArenaLoadingBootstrap" then
			bootstrapDestroyed = container.Destroyed
		end
	end
	assert(bootstrapDestroyed, "watchdog retained the arrival overlay after a suspended UI startup")
	local rootsBeforeLateResume = #renders
	scriptNode.Destroying:Fire()
	resumeSuspended()
	assert(#renders == rootsBeforeLateResume, "late UI module completion recreated roots after cleanup")
end

print("ArenaUI actual-source root-fault, watchdog, and late-resume regressions: 2 scenarios passed")
