-- Description: Declares and materializes every remote, with rate-limiting and validation middleware for client-invokable handlers.

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
	SetEmoteSlot = "function",
	PlayEmote = "event",
	EmotePlayed = "event",
	OpenCrate = "function",
	AcknowledgeBonksCrate = "event",
	PurchaseCosmetic = "function",
	GetSeasonPassState = "function",
	ClaimSeasonTier = "function",
	ClaimAllSeasonTiers = "function",
	CrateOpened = "event",
	StorePurchaseGranted = "event",
	ReportDeviceClass = "event",
	ReportAimPose = "unreliable",
	MarkSwipeThrowLearned = "event",
	SetClientSetting = "event",
	SetClientSettingRequest = "function",
	OnboardingState = "event",
	OnboardingReady = "function",
	OnboardingAction = "event",
	OnboardingDebug = "event",
	LobbyCombatTest = "event",
	CombatFeed = "event",
	MatchSummary = "event",
	PostMatchResult = "event",
	PostMatchStatus = "event",
	PostMatchRequest = "function",
	GetShopState = "function",
	GetPurchaseState = "function",
	ShopStateChanged = "event",
	GetQuestState = "function",
	ClaimQuest = "function",
	QuestStateChanged = "event",
	GetDailyRewardState = "function",
	ClaimDailyReward = "function",
	DailyRewardStateChanged = "event",
	SeasonPassStateChanged = "event",
	DamageFeedback = "event",
	SubmitModeVote = "event",
	ArenaClientReady = "event",
	TeleportPresentationReady = "event",
	TeleportStatus = "event",
	RequestLobbyReturn = "event",
	ReportArenaLoadingEvent = "event",
	DevEndMatch = "event",
	SubmitCombatInput = "event",
	SubmitWeaponEquip = "event",
	CombatSimEvent = "unreliable",
	JumpPadImpulse = "unreliable",
	BumperHit = "unreliable",
	ReportAnalyticsEvent = "event",
}
local rateLimitCounters = {}
local rejectionLogTimes = {}

local function checkRateLimit(player, name, limit, windowSeconds)
	local userId = player.UserId
	rateLimitCounters[userId] = rateLimitCounters[userId] or {}
	local counter = rateLimitCounters[userId][name]
	local now = os.clock()
	local window = windowSeconds or 1
	if not counter or now >= counter.resetTime then
		rateLimitCounters[userId][name] = { count = 1, resetTime = now + window }
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
		rejectionLogTimes[player.UserId] = nil
	end)
end

local Network = {}

local anonymousBuckets = 0

local function warnOnce(player, key, message)
	local userId = player.UserId
	rejectionLogTimes[userId] = rejectionLogTimes[userId] or {}
	local now = os.clock()
	local lastWarning = rejectionLogTimes[userId][key]
	if not lastWarning or now >= lastWarning + 5 then
		rejectionLogTimes[userId][key] = now
		warn(message)
	end
end

function Network.withRateLimit(limit, handler, bucket, windowSeconds)
	local key = bucket
	if key == nil then
		anonymousBuckets += 1
		key = `anonymous:{anonymousBuckets}`
	end
	return function(player, ...)
		if not checkRateLimit(player, key, limit, windowSeconds) then
			warnOnce(player, `rate:{key}`, ("[Network] Rate limited: %s on %s"):format(player.Name, key))
			return nil, "rate_limited"
		end
		return handler(player, ...)
	end
end

function Network.withValidation(validate, handler, bucket)
	local key = bucket
	if key == nil then
		anonymousBuckets += 1
		key = `anonymous:{anonymousBuckets}`
	end
	return function(player, ...)
		local ok, reason = validate(player, ...)
		if not ok then
			warnOnce(player, `validation:{key}`, ("[Network] Validation failed for %s on %s"):format(player.Name, key))
			return nil, "invalid_args"
		end
		return handler(player, ...)
	end
end

function Network.withActionRateLimits(rules, handler, bucket)
	assert(
		type(rules) == "table" and type(rules.default) == "table" and type(rules.default.limit) == "number",
		"[Network] Action rate limits require a default budget"
	)
	local defaultRule = rules.default
	local key = bucket
	if key == nil then
		anonymousBuckets += 1
		key = `anonymous:{anonymousBuckets}`
	end

	return function(player, action, ...)
		local rule = defaultRule
		local actionKey = "default"
		if typeof(action) == "string" then
			local candidate = rules[action]
			if type(candidate) == "table" and type(candidate.limit) == "number" then
				rule = candidate
				actionKey = action
			end
		end
		local actionBucket = `{key}:action:{actionKey}`
		local window = if type(rule.window) == "number" then rule.window else 1
		if not checkRateLimit(player, actionBucket, rule.limit, window) then
			warnOnce(
				player,
				`rate:{actionBucket}`,
				("[Network] Rate limited: %s on %s"):format(player.Name, actionBucket)
			)
			return nil, "rate_limited"
		end
		return handler(player, action, ...)
	end
end

function Network.handleProtected(name, middleware, callback)
	assert(IS_SERVER, "[Network] handleProtected can only be called on the server")
	local handler = callback
	if middleware.actionRateLimits then
		handler = Network.withActionRateLimits(middleware.actionRateLimits, handler, name)
	end
	if middleware.validate then
		handler = Network.withValidation(middleware.validate, handler, name)
	end
	if middleware.rateLimit then
		handler = Network.withRateLimit(middleware.rateLimit, handler, name)
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

function Network.fire(name, target, ...)
	assert(IS_SERVER, "[Network] fire can only be called on the server")
	local remote = folder:WaitForChild(name)
	if typeof(target) == "Instance" and target:IsA("Player") then
		remote:FireClient(target, ...)
	else
		remote:FireAllClients(...)
	end
end

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
