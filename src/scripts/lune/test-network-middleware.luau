-- Description: Headless contract probe for the production Network middleware.

--!nonstrict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local now = 0
local warningMessages = {}

local function signal()
	local listeners = {}
	local event = {}
	function event:Connect(callback)
		local connection = {}
		listeners[connection] = callback
		function connection.Disconnect()
			listeners[connection] = nil
		end
		return connection
	end
	function event:Fire(...)
		for connection, callback in table.clone(listeners) do
			if listeners[connection] then
				callback(...)
			end
		end
	end
	return event
end

local nodeMethods = {}
local nodeMeta = {
	__index = nodeMethods,
	__newindex = function(node, key, value)
		if key == "Parent" then
			rawset(node, key, value)
			if value ~= nil then
				value._children[node.Name] = node
			end
		else
			rawset(node, key, value)
		end
	end,
}

local function newNode(className: string, name: string?): any
	return setmetatable({
		ClassName = className,
		Name = name,
		_children = {},
	}, nodeMeta)
end

function nodeMethods:FindFirstChild(name: string): any
	return self._children[name]
end

function nodeMethods:WaitForChild(name: string): any
	local child = self._children[name]
	assert(child ~= nil, `missing child {name}`)
	return child
end

function nodeMethods:IsA(className: string): boolean
	return self.ClassName == className
end

local remotes = newNode("Folder", "Remotes")
local replicatedStorage = newNode("ReplicatedStorage", "ReplicatedStorage")
replicatedStorage._children.Remotes = remotes
remotes.Parent = replicatedStorage

local players = {
	PlayerRemoving = signal(),
}
local runService = {}
function runService:IsServer(): boolean
	return true
end

local game = {}
function game:GetService(name: string): any
	if name == "ReplicatedStorage" then
		return replicatedStorage
	elseif name == "RunService" then
		return runService
	elseif name == "Players" then
		return players
	end
	error(`unexpected service {name}`)
end

local instance = {}
function instance.new(className: string): any
	local node = newNode(className)
	if className == "RemoteEvent" or className == "UnreliableRemoteEvent" then
		node.OnServerEvent = signal()
	end
	return node
end

local networkChunk = luau.load(luau.compile(fs.readFile("src/shared/Network.luau")), {
	debugName = "Network.contract-probe",
	environment = {
		game = game,
		Instance = instance,
		os = {
			clock = function()
				return now
			end,
		},
		warn = function(message: string)
			table.insert(warningMessages, message)
		end,
	},
	injectGlobals = true,
})
local Network = networkChunk()

local function player(userId: number): any
	return {
		UserId = userId,
		Name = `ProbePlayer{userId}`,
	}
end

local function equal(actual: any, expected: any, message: string)
	assert(actual == expected, `{message}: expected {tostring(expected)}, got {tostring(actual)}`)
end

local function warningCount(): number
	return #warningMessages
end

local function invoke(remoteName: string, target: any, ...): ...any
	local remote = remotes:WaitForChild(remoteName)
	assert(remote.OnServerInvoke ~= nil, `{remoteName} did not register a server invoke`)
	return remote.OnServerInvoke(target, ...)
end

local cases = {}
local failures = {}

local function runCase(name: string, callback: () -> ())
	local ok, err = pcall(callback)
	if ok then
		table.insert(cases, { name = name, status = "passed" })
	else
		table.insert(cases, { name = name, status = "failed", error = tostring(err) })
		table.insert(failures, name)
	end
end

runCase("action middleware rejects registration without a default budget", function()
	local callbacks = 0
	for _, rules in { false, {}, { default = {} }, { default = { limit = "2" } } } do
		local ok, err = pcall(Network.withActionRateLimits, rules, function()
			callbacks += 1
		end, "InvalidConfiguration")
		equal(ok, false, "invalid rules must fail during registration")
		assert(tostring(err):find("require a default budget", 1, true), tostring(err))
	end
	equal(callbacks, 0, "invalid configuration never dispatches")
end)

runCase("handleProtected orders overall before validation", function()
	local validated = 0
	local callbacks = 0
	Network.handleProtected("PartyRequest", {
		rateLimit = 1,
		actionRateLimits = { default = { limit = 1 } },
		validate = function(_player, action)
			validated += 1
			return typeof(action) == "string" and action == "valid"
		end,
	}, function(_player, _action)
		callbacks += 1
		return "handled"
	end)

	local first, firstReason = invoke("PartyRequest", player(1), "invalid")
	equal(first, nil, "invalid result")
	equal(firstReason, "invalid_args", "invalid reason")
	local second, secondReason = invoke("PartyRequest", player(1), "valid")
	equal(second, nil, "overall result")
	equal(secondReason, "rate_limited", "overall reason")
	equal(validated, 1, "validation count")
	equal(callbacks, 0, "callback count")
end)

runCase("handleProtected orders validation before action", function()
	local validated = 0
	local callbacks = 0
	Network.handleProtected("OpenCrate", {
		rateLimit = 10,
		actionRateLimits = { default = { limit = 1 } },
		validate = function(_player, action)
			validated += 1
			return typeof(action) == "string" and action == "valid"
		end,
	}, function(_player, _action)
		callbacks += 1
		return "handled"
	end)

	local invalid, invalidReason = invoke("OpenCrate", player(2), 42)
	equal(invalid, nil, "invalid action result")
	equal(invalidReason, "invalid_args", "invalid action reason")
	equal(invoke("OpenCrate", player(2), "valid"), "handled", "valid callback")
	local denied, deniedReason = invoke("OpenCrate", player(2), "valid")
	equal(denied, nil, "action result")
	equal(deniedReason, "rate_limited", "action reason")
	equal(validated, 3, "validation count")
	equal(callbacks, 1, "callback count")
end)

runCase("action buckets are independent by action remote and player", function()
	local rules = {
		default = { limit = 1 },
		KnownA = { limit = 1 },
		KnownB = { limit = 1 },
	}
	local handler = Network.withActionRateLimits(rules, function(_player, action)
		return action
	end, "RemoteA")
	local otherRemote = Network.withActionRateLimits(rules, function(_player, action)
		return action
	end, "RemoteB")

	local first = player(3)
	equal(handler(first, "KnownA"), "KnownA", "known action")
	local _, knownDenied = handler(first, "KnownA")
	equal(knownDenied, "rate_limited", "known action limit")
	equal(handler(first, "KnownB"), "KnownB", "second known action")
	equal(handler(first, "UnknownOne"), "UnknownOne", "default action")
	local _, malformedDenied = handler(first, 42)
	equal(malformedDenied, "rate_limited", "shared malformed default")
	equal(otherRemote(first, "KnownA"), "KnownA", "independent remote")
	equal(handler(player(4), "KnownA"), "KnownA", "independent player")
end)

runCase("limiter admits exactly at the reset boundary", function()
	local handler = Network.withRateLimit(1, function()
		return "ok"
	end, "Boundary", 2)
	now = 10
	equal(handler(player(5)), "ok", "first request")
	now = 11.999
	local _, beforeReason = handler(player(5))
	equal(beforeReason, "rate_limited", "before boundary")
	now = 12
	equal(handler(player(5)), "ok", "at boundary")
end)

runCase("rejection warnings are bounded and do not use raw reasons or actions", function()
	local handler = Network.withRateLimit(1, function()
		return "ok"
	end, "WarnRemote")
	now = 20
	equal(handler(player(6)), "ok", "warning first request")
	handler(player(6))
	local afterFirst = warningCount()
	now = 24.9
	handler(player(6))
	equal(warningCount(), afterFirst, "warning five second window")
	now = 25
	handler(player(6))
	equal(warningCount(), afterFirst + 1, "warning reset")

	local validation = Network.withValidation(function()
		return false, "secretReason"
	end, function()
		return "unexpected"
	end, "ValidationRemote")
	now = 30
	validation(player(6))
	validation(player(6))
	equal(warningCount(), afterFirst + 2, "validation warning bound")
	equal(string.find(warningMessages[#warningMessages], "secretReason"), nil, "raw validation reason")

	local actions = Network.withActionRateLimits({ default = { limit = 1 } }, function(_player, action)
		return action
	end, "ActionWarningRemote")
	now = 40
	actions(player(6), "raw-one")
	actions(player(6), "raw-two")
	local actionWarningCount = warningCount()
	actions(player(6), "raw-three")
	equal(warningCount(), actionWarningCount, "action warning bound")
	equal(string.find(warningMessages[#warningMessages], "raw-two"), nil, "raw action in warning")
end)

runCase("player removal clears limiter and warning state", function()
	local handler = Network.withRateLimit(1, function()
		return "ok"
	end, "CleanupRemote")
	local leaving = player(99)
	now = 50
	equal(handler(leaving), "ok", "cleanup first request")
	handler(leaving)
	local beforeRemoval = warningCount()
	players.PlayerRemoving:Fire(leaving)
	local rejoined = player(99)
	equal(handler(rejoined), "ok", "cleanup limiter reset")
	handler(rejoined)
	equal(warningCount(), beforeRemoval + 1, "cleanup warning reset")
end)

local evidenceDirectory = ".review/production/2026-09-09-batch1/r03"
fs.writeDir(evidenceDirectory)
local evidence = {
	status = if #failures == 0 then "passed" else "failed",
	actualSource = "src/shared/Network.luau",
	caseCount = #cases,
	failureCount = #failures,
	cases = cases,
	warningCount = #warningMessages,
	clock = "mocked os.clock with exact boundary checks",
	playerRemoval = "mocked Players.PlayerRemoving signal",
}
fs.writeFile(`{evidenceDirectory}/network-middleware-probe.json`, serde.encode("json", evidence, true) .. "\n")
print(serde.encode("json", evidence, true))
process.exit(if #failures == 0 then 0 else 1)
