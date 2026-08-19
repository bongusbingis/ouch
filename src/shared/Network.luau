local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local IS_SERVER = RunService:IsServer()

local folder
if IS_SERVER then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local definitions = {
	PartyRequest = "function",
	PartyPacket = "event",
	EquipCosmetic = "function",
	OpenCrate = "function",
	PurchaseCosmetic = "function",
	GetSeasonPassState = "function",
	ClaimSeasonTier = "function",
	ClaimAllSeasonTiers = "function",
	CrateOpened = "event",
	StorePurchaseGranted = "event",
	ReportDeviceClass = "event",
	CombatFeed = "event",
	MatchSummary = "event",
	GetQuestState = "function",
	ClaimQuest = "function",
	QuestStateChanged = "event",
	SeasonPassStateChanged = "event",
	DamageFeedback = "event",
	SubmitModeVote = "event",
	ArenaClientReady = "event",
	SubmitCombatInput = "event",
	CombatSimEvent = "unreliable",
	ReportAnalyticsEvent = "event",
}
local rateLimitCounters = {}

local function checkRateLimit(player, name, limit)
	local userId = player.UserId
	rateLimitCounters[userId] = rateLimitCounters[userId] or {}
	local counter = rateLimitCounters[userId][name]
	local now = os.clock()
	if not counter or now > counter.resetTime then
		rateLimitCounters[userId][name] = { count = 1, resetTime = now + 1 }
		return true
	end
	if counter.count >= limit then
		return false
	end
	counter.count += 1
	return true
end

local REMOTE_CLASS = {
	["function"] = "RemoteFunction",
	["event"] = "RemoteEvent",
	["unreliable"] = "UnreliableRemoteEvent",
}

if IS_SERVER then
	for name, kind in definitions do
		local className = REMOTE_CLASS[kind] or "RemoteEvent"
		local remote = folder:FindFirstChild(name)
		if remote == nil then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		assert(remote:IsA(className), `[Network] Remotes.{name} must be a {className}`)
	end

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		rateLimitCounters[player.UserId] = nil
	end)
end

local Network = {}

-- Composable middleware: wrap handlers rather than threading a middleware
-- config object.

-- Each wrapper owns an independent per-player budget. Callers pass the remote
-- name so warnings name it; without one the budget is still private to this
-- wrapper, because a shared key would let a chatty remote throttle every other.
local anonymousBuckets = 0

function Network.withRateLimit(limit, handler, bucket)
	local key = bucket
	if key == nil then
		anonymousBuckets += 1
		key = `anonymous:{anonymousBuckets}`
	end
	return function(player, ...)
		if not checkRateLimit(player, key, limit) then
			warn(("[Network] Rate limited: %s on %s"):format(player.Name, key))
			return nil, "rate_limited"
		end
		return handler(player, ...)
	end
end

function Network.withValidation(validate, handler)
	return function(player, ...)
		local ok, reason = validate(player, ...)
		if not ok then
			warn(("[Network] Validation failed for %s — %s"):format(player.Name, reason or "?"))
			return nil, "invalid_args"
		end
		return handler(player, ...)
	end
end

function Network.withLogging(handler)
	return function(player, ...)
		print(("[Network] called by %s"):format(player.Name))
		return handler(player, ...)
	end
end

-- Sugar over Network.handle for callers that pass a middleware table.
function Network.handleProtected(name, middleware, callback)
	assert(IS_SERVER, "[Network] handleProtected can only be called on the server")
	local handler = callback
	if middleware.rateLimit then
		handler = Network.withRateLimit(middleware.rateLimit, handler, name)
	end
	if middleware.validate then
		handler = Network.withValidation(middleware.validate, handler)
	end
	if middleware.logging then
		handler = Network.withLogging(handler)
	end
	Network.handle(name, handler)
end

function Network.handle(name, callback)
	assert(IS_SERVER, "[Network] handle can only be called on the server")
	local remote = folder:WaitForChild(name)
	if remote:IsA("RemoteFunction") then
		remote.OnServerInvoke = callback
	else
		remote.OnServerEvent:Connect(callback)
	end
end

function Network.call(name, ...)
	assert(not IS_SERVER, "[Network] call can only be called on the client")
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteFunction"), `[Network] Remotes.{name} must be a RemoteFunction`)
	return remote:InvokeServer(...)
end

-- nil target = fire to all clients (without passing nil as a payload arg)
function Network.fire(name, target, ...)
	assert(IS_SERVER, "[Network] fire can only be called on the server")
	local remote = folder:WaitForChild(name)
	if typeof(target) == "Instance" and target:IsA("Player") then
		remote:FireClient(target, ...)
	else
		remote:FireAllClients(...)
	end
end

-- Client-side fire-and-forget for event remotes (call() is for RemoteFunctions)
function Network.fireServer(name, ...)
	assert(not IS_SERVER, "[Network] fireServer can only be called on the client")
	local remote = folder:WaitForChild(name)
	assert(
		remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent"),
		`[Network] Remotes.{name} must be an event remote`
	)
	remote:FireServer(...)
end

function Network.on(name, callback)
	assert(not IS_SERVER, "[Network] on can only be called on the client")
	local remote = folder:WaitForChild(name)
	assert(
		remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent"),
		`[Network] Remotes.{name} must be an event remote`
	)
	return remote.OnClientEvent:Connect(callback)
end

return Network
