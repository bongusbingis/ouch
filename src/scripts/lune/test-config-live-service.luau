-- Description: Exercises the production live-config publisher with fake ConfigService and instances.
--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local function loadSource(path: string, environment: { [string]: any }): any
	return luau.load(luau.compile(fs.readFile(path)), {
		debugName = path,
		environment = environment,
		injectGlobals = true,
	})()
end

local overrides = loadSource("src/shared/Game/Config/ConfigOverrides.luau", {})
local runtime = loadSource("src/shared/Game/Config/ConfigRuntime.luau", {
	script = { Parent = { ConfigOverrides = { Name = "ConfigOverrides" } } },
	require = function(target)
		assert(target.Name == "ConfigOverrides", `unexpected runtime require {target.Name}`)
		return overrides
	end,
})

local methods = {}
local nodeMeta = {
	__index = methods,
	__newindex = function(self: any, key: string, value: any)
		if key == "Parent" and value ~= nil then
			value.children[self.Name] = self
		end
		rawset(self, key, value)
	end,
}
local function node(className: string, name: string): any
	return setmetatable({ ClassName = className, Name = name, children = {} }, nodeMeta)
end
function methods:WaitForChild(name: string): any
	local child = self.children[name]
	assert(child, `missing {self.Name}.{name}`)
	return child
end
local function add(parent: any, child: any)
	child.Parent = parent
end

local replicatedStorage = node("ReplicatedStorage", "ReplicatedStorage")
local config = node("Folder", "Config")
local shared = node("Folder", "Shared")
local gameFolder = node("Folder", "Game")
local configFolder = node("Folder", "Config")
add(replicatedStorage, config)
add(replicatedStorage, shared)
add(shared, gameFolder)
add(gameFolder, configFolder)

local liveConfig = {
	Entries = {
		{ Key = "Combat.Dodgeball.ThrowSpeed", Type = "number", Minimum = 10, Maximum = 1000 },
		{ Key = "Combat.Dodgeball.ThrowCooldown", Type = "number", Minimum = 0, Maximum = 10 },
		{ Key = "Combat.Dodgeball.Unknown", Type = "number", Minimum = 0, Maximum = 10 },
	},
	SimCritical = {},
	StateFolderName = "ConfigState",
	RetrySeconds = 30,
	ResyncSeconds = 300,
}
local dependencies: { [string]: any } = {
	LiveConfig = liveConfig,
	ConfigOverrides = overrides,
	ConfigRuntime = runtime,
}
for name in dependencies do
	add(configFolder, node("ModuleScript", name))
end
add(config, node("ModuleScript", "LiveConfig"))

local values: { [string]: any } = { ["Combat.Dodgeball.ThrowSpeed"] = 250 }
local onUpdate: (() -> ())? = nil
local sourceSnapshot = {
	Error = "None",
	UpdateAvailable = {
		Connect = function(_, callback: () -> ())
			onUpdate = callback
		end,
	},
	GetValue = function(_, key: string)
		return values[key]
	end,
	Refresh = function() end,
}
local configService = {
	GetConfigAsync = function()
		return sourceSnapshot
	end,
}
local httpService = {
	JSONEncode = function(_, value: any): string
		return serde.encode("json", value)
	end,
}
local warnings = {}
local spawnCount = 0
local service = loadSource("src/server/Modules/ConfigLiveService.luau", {
	game = {
		GetService = function(_, name: string)
			if name == "ConfigService" then
				return configService
			elseif name == "HttpService" then
				return httpService
			elseif name == "ReplicatedStorage" then
				return replicatedStorage
			end
			error(`unexpected service {name}`)
		end,
	},
	Instance = {
		new = function(className: string)
			return node(className, "")
		end,
	},
	Enum = { ConfigSnapshotErrorState = { None = "None" } },
	require = function(target)
		return assert(dependencies[target.Name], `unexpected require {target.Name}`)
	end,
	task = {
		spawn = function(callback: () -> ())
			spawnCount += 1
			if spawnCount == 1 then
				callback()
			end
		end,
		delay = function() end,
	},
	warn = function(message: string)
		table.insert(warnings, message)
	end,
})

local combat = { Dodgeball = { ThrowSpeed = 200, ThrowCooldown = 0.6 } }
service.start({ modules = { Combat = combat } })
local projection = replicatedStorage:WaitForChild("ConfigState"):WaitForChild("Snapshot")
local function expectProjection(revision: number, speed: number, cooldown: number?)
	local decoded = serde.decode("json", projection.Value)
	assert(decoded.revision == revision, `expected revision {revision}, got {decoded.revision}`)
	assert(decoded.overrides["Combat.Dodgeball.ThrowSpeed"] == speed, "published ThrowSpeed mismatch")
	assert(decoded.overrides["Combat.Dodgeball.ThrowCooldown"] == cooldown, "published ThrowCooldown mismatch")
end

expectProjection(1, 250, nil)
assert(combat.Dodgeball.ThrowSpeed == 250, "valid candidate did not update server")

values["Combat.Dodgeball.ThrowSpeed"] = "malformed"
values["Combat.Dodgeball.ThrowCooldown"] = 0.2
(onUpdate :: () -> ())()
expectProjection(1, 250, nil)
assert(
	combat.Dodgeball.ThrowSpeed == 250 and combat.Dodgeball.ThrowCooldown == 0.6,
	"malformed candidate changed server"
)

values["Combat.Dodgeball.ThrowSpeed"] = 300
(onUpdate :: () -> ())()
expectProjection(2, 300, 0.2)
assert(
	combat.Dodgeball.ThrowSpeed == 300 and combat.Dodgeball.ThrowCooldown == 0.2,
	"second valid candidate did not apply"
)

values["Combat.Dodgeball.Unknown"] = 5
values["Combat.Dodgeball.ThrowSpeed"] = 350
(onUpdate :: () -> ())()
expectProjection(2, 300, 0.2)
assert(combat.Dodgeball.ThrowSpeed == 300, "missing-target candidate changed server")
assert(#warnings == 2, `expected two rejected-candidate diagnostics, got {#warnings}`)
assert(string.find(warnings[1], "Combat.Dodgeball.ThrowSpeed", 1, true), "malformed-key diagnostic missing")
assert(string.find(warnings[2], "Combat.Dodgeball.Unknown", 1, true), "missing-target diagnostic missing")
print("ConfigLiveService actual-source publication: 4 scenarios passed")
