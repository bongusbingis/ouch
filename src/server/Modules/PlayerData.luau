-- Name: PlayerData.luau
-- Author: Jack C.
-- Description: Loads, saves, and replicates player profiles, exposing a write-through proxy so mutations replicate automatically, plus the balance, XP, and progression mutators every other service goes through.
-- Created: 2026-07-12

local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replica = require(ReplicatedStorage.Packages.replica)
local ProfileStore = require(ReplicatedStorage.Packages.profilestore)
local Promise = require(ReplicatedStorage.Packages.promise)

local Env = require(script.Parent.Parent.Env)
local DataConfig = require(game.ReplicatedStorage.Config.Data)
local OnboardingConfig = require(game.ReplicatedStorage.Config.Onboarding)
local OnboardingState = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Onboarding")
		:WaitForChild("OnboardingState")
)
local WriteThroughProxy = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Data"):WaitForChild("WriteThroughProxy")
)

local Data = {}
Data._profiles = {}
Data._loaded = {}
Data._loadGeneration = {}
Data._writeLeaseCounts = {}
Data._pendingSaves = {}

local loadedListeners = {}

local _profileToken = Replica.Token("GameProfile")
local _dataStore = ProfileStore.New(Env.PrimaryDataKey or "DefaultDataKey", DataConfig.Template)
local WRITE_LEASE_TIMEOUT_SECONDS = 10

local function _notifyLoaded(player)
	for _, listener in table.clone(loadedListeners) do
		local ok, err = pcall(listener, player)
		if not ok then
			warn(`[Data] Loaded listener failed for {player.Name}: {err}`)
		end
	end
end

export type ProgressionDelta = {
	Elims: number?,
	Deaths: number?,
	Catches: number?,
	Wins: number?,
	Losses: number?,
	MatchesPlayed: number?,
	XP: number?,
	Bonks: number?,
}

local EDITABLE_PROGRESSION_FIELDS = {
	Elims = true,
	Deaths = true,
	Catches = true,
	Wins = true,
	Losses = true,
	MatchesPlayed = true,
}

local function _subscribeWhenReady(player, entry)
	local function subscribe()
		if Data._profiles[player.UserId] ~= entry then
			return
		end
		if not player:IsDescendantOf(PlayersService) then
			return
		end
		if entry.ReadyConnection then
			entry.ReadyConnection:Disconnect()
			entry.ReadyConnection = nil
		end
		entry.Replica:Subscribe(player)
	end

	if Replica.ReadyPlayers[player] then
		subscribe()
		return
	end

	entry.ReadyConnection = Replica.NewReadyPlayer:Connect(function(readyPlayer)
		if readyPlayer == player then
			subscribe()
		end
	end)
end

local function _loadPlayerData(player)
	return Promise.new(function(resolve, reject)
		local profile = _dataStore:StartSessionAsync(`Player_{player.UserId}`, {
			Cancel = function()
				return not player or not player:IsDescendantOf(PlayersService)
			end,
		})

		if not profile then
			reject(`Data load failed for: {player.Name}`)
			player:Kick("Data load failed.\nPlease rejoin!")
			return
		end

		profile:AddUserId(player.UserId)

		profile:Reconcile()

		local sessionConn
		sessionConn = profile.OnSessionEnd:Connect(function()
			if sessionConn then
				sessionConn:Disconnect()
				sessionConn = nil
			end
			if not Data._profiles[player.UserId] then
				return
			end
			if Data._profiles[player.UserId].ReadyConnection then
				Data._profiles[player.UserId].ReadyConnection:Disconnect()
				Data._profiles[player.UserId].ReadyConnection = nil
			end
			Data._profiles[player.UserId].Replica:Destroy()
			Data._profiles[player.UserId] = nil
			Data._loaded[player.UserId] = nil
			Data._writeLeaseCounts[player.UserId] = nil
			Data._pendingSaves[player.UserId] = nil
			Data._loadGeneration[player.UserId] = (Data._loadGeneration[player.UserId] or 0) + 1
			if player:IsDescendantOf(PlayersService) then
				player:Kick("Your data has been released.\nPlease rejoin!")
			end
		end)

		if not player:IsDescendantOf(PlayersService) then
			profile:EndSession()
			return
		end

		local profileReplica = Replica.New({
			Token = _profileToken,
			Data = profile.Data,
		})

		local entry = {
			Profile = profile,
			Data = WriteThroughProxy.wrap(profile.Data, profileReplica),
			Replica = profileReplica,
		}
		Data._profiles[player.UserId] = entry
		Data.markFirstJoin(player)
		_subscribeWhenReady(player, entry)
		resolve(true)
	end)
end

local function _buildLeaderStats(player)
	return Promise.new(function(resolve)
		local leaderStats = player:FindFirstChild("leaderstats")
		if leaderStats == nil then
			leaderStats = Instance.new("Folder")
			leaderStats.Name = "leaderstats"
			leaderStats.Parent = player
		end

		local entry = Data._profiles[player.UserId]
		if not entry then
			warn(`[Data] Profile missing for {player.Name} when building leaderstats`)
			resolve(false)
			return
		end

		for _, info in ipairs(DataConfig.Leaderstats) do
			local value = leaderStats:FindFirstChild(info.Name)
			if value == nil or not value:IsA(info.Type) then
				value = Instance.new(info.Type)
				value.Name = info.Name
				value.Parent = leaderStats
			end
			value.Value = info._Build(player, entry)
		end

		resolve(true)
	end)
end

local function _setProgressionAttributes(player, data)
	local progression = data.Progression
	player:SetAttribute("XP", data.Level.Points)
	player:SetAttribute("CareerElims", progression.Elims)
	player:SetAttribute("Deaths", progression.Deaths)
	player:SetAttribute("Catches", progression.Catches)
	player:SetAttribute("Wins", progression.Wins)
	player:SetAttribute("Losses", progression.Losses)
	player:SetAttribute("MatchesPlayed", progression.MatchesPlayed)
	player:SetAttribute("KDR", progression.KDR)
	player:SetAttribute("TutorialVersion", data.Tutorial.Version)
	player:SetAttribute("SwipeThrowLearned", data.Onboarding.SwipeThrowLearned == true)
end

-- The client never receives raw onboarding state; it reads this projection, so
-- the profile stays the only writable copy.
local function _setOnboardingAttributes(player, state)
	player:SetAttribute("OnboardingStatus", state.Status)
	player:SetAttribute("OnboardingCheckpoint", state.Checkpoint)
end

local function _readOnboarding(player)
	local d = Data.get(player)
	if d == nil then
		return nil
	end
	return OnboardingState.normalize(d.Onboarding)
end

local function _writeOnboarding(player, state)
	local d = Data.get(player)
	if d == nil then
		return false
	end
	local onboarding = d.Onboarding
	onboarding.Version = state.Version
	onboarding.Status = state.Status
	onboarding.Checkpoint = state.Checkpoint
	onboarding.SkippedAt = state.SkippedAt
	onboarding.Sessions = state.Sessions
	_setOnboardingAttributes(player, state)
	return true
end

function Data.getOnboarding(player)
	return _readOnboarding(player)
end

-- Every onboarding write goes through here: the caller supplies a pure
-- transition from OnboardingState and never touches the profile fields.
function Data.updateOnboarding(player, transform)
	local state = _readOnboarding(player)
	if state == nil then
		return nil
	end
	local migrated = OnboardingState.migrate(state, OnboardingConfig.Version)
	local next_ = transform(migrated)
	if next_ == nil then
		return nil
	end
	if not _writeOnboarding(player, next_) then
		return nil
	end
	return next_
end

local function _syncLeaderStats(player)
	local entry = Data._profiles[player.UserId]
	local leaderStats = player:FindFirstChild("leaderstats")
	if entry == nil or leaderStats == nil then
		return
	end
	for _, info in ipairs(DataConfig.Leaderstats) do
		local value = leaderStats:FindFirstChild(info.Name)
		if value and value:IsA(info.Type) then
			value.Value = info._Build(player, entry)
		end
	end
	_setProgressionAttributes(player, entry.Data)
end

local function _recalculateKDR(data)
	local progression = data.Progression
	progression.KDR = if progression.Deaths > 0 then progression.Elims / progression.Deaths else progression.Elims
end

function Data.get(player)
	local entry = Data._profiles[player.UserId]
	return entry and entry.Data
end

function Data.isLoaded(player)
	return Data._loaded[player.UserId] == true
end

function Data.onLoaded(listener)
	table.insert(loadedListeners, listener)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(loadedListeners, listener)
		if index then
			table.remove(loadedListeners, index)
		end
	end
end

function Data.addBonks(player, amount)
	local d = Data.get(player)
	if d then
		d.Bonks = d.Bonks + amount
	end
end

function Data.addXP(player, amount)
	local d = Data.get(player)
	if d then
		d.Level.Points = d.Level.Points + amount
		_syncLeaderStats(player)
	end
end

function Data.applyProgression(player, delta: ProgressionDelta)
	local d = Data.get(player)
	if not d then
		return false
	end

	local progression = d.Progression
	progression.Elims += delta.Elims or 0
	progression.Deaths += delta.Deaths or 0
	progression.Catches += delta.Catches or 0
	progression.Wins += delta.Wins or 0
	progression.Losses += delta.Losses or 0
	progression.MatchesPlayed += delta.MatchesPlayed or 0
	d.Level.Points += delta.XP or 0
	d.Bonks += delta.Bonks or 0
	_recalculateKDR(d)
	_syncLeaderStats(player)
	return true
end

function Data.completeTutorial(player): boolean
	local d = Data.get(player)
	if not d or d.Tutorial.Version >= DataConfig.TutorialVersion then
		return false
	end
	d.Tutorial.Version = DataConfig.TutorialVersion
	player:SetAttribute("TutorialVersion", d.Tutorial.Version)
	return true
end

function Data.markFirstJoin(player, now)
	local d = Data.get(player)
	if not d or d.Onboarding.FirstJoinAt > 0 then
		return false
	end
	d.Onboarding.FirstJoinAt = now or os.time()
	return true
end

function Data.markSwipeThrowLearned(player): boolean
	local d = Data.get(player)
	if not d or d.Onboarding.SwipeThrowLearned == true then
		return false
	end
	d.Onboarding.SwipeThrowLearned = true
	player:SetAttribute("SwipeThrowLearned", true)
	return true
end

function Data.setFieldForTesting(player, field, value)
	local d = Data.get(player)
	if not d or typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return false
	end

	local nextValue = math.max(math.floor(value), 0)
	if field == "Bonks" then
		d.Bonks = nextValue
	elseif field == "XP" then
		d.Level.Points = nextValue
	elseif EDITABLE_PROGRESSION_FIELDS[field] then
		d.Progression[field] = nextValue
	else
		return false
	end

	_recalculateKDR(d)
	_syncLeaderStats(player)
	return true
end

function Data.addFieldForTesting(player, field, amount)
	local d = Data.get(player)
	if not d or typeof(amount) ~= "number" or amount ~= amount or math.abs(amount) == math.huge then
		return false
	end

	local current
	if field == "Bonks" then
		current = d.Bonks
	elseif field == "XP" then
		current = d.Level.Points
	elseif EDITABLE_PROGRESSION_FIELDS[field] then
		current = d.Progression[field]
	else
		return false
	end

	return Data.setFieldForTesting(player, field, current + amount)
end

function Data.load(player)
	local generation = (Data._loadGeneration[player.UserId] or 0) + 1
	Data._loadGeneration[player.UserId] = generation
	Data._loaded[player.UserId] = nil
	return _loadPlayerData(player)
		:andThen(function()
			_buildLeaderStats(player):await()
			local d = Data.get(player)
			if d then
				_recalculateKDR(d)
				_syncLeaderStats(player)
				_setOnboardingAttributes(player, OnboardingState.normalize(d.Onboarding))
			end
		end)
		:andThen(function()
			if
				Data._loadGeneration[player.UserId] ~= generation
				or Data._profiles[player.UserId] == nil
				or not player:IsDescendantOf(PlayersService)
			then
				return
			end
			Data._loaded[player.UserId] = true
			_notifyLoaded(player)
			print(`[Data] Loaded profile for {player.Name} ({player.UserId})`)
		end)
		:catch(function(err)
			warn(`[Data] CRITICAL — failed to load profile for {player.Name} ({player.UserId}): {err}`)
		end)
end

local function _finishSave(userId, entry)
	if Data._profiles[userId] ~= entry then
		return
	end
	Data._profiles[userId] = nil
	Data._pendingSaves[userId] = nil
	Data._writeLeaseCounts[userId] = nil
	if entry.ReadyConnection then
		entry.ReadyConnection:Disconnect()
		entry.ReadyConnection = nil
	end
	entry.Replica:Destroy()
	entry.Profile:EndSession()
end

function Data.acquireWriteLease(player)
	local userId = player.UserId
	local entry = Data._profiles[userId]
	if entry == nil or Data._pendingSaves[userId] ~= nil then
		return nil
	end

	Data._writeLeaseCounts[userId] = (Data._writeLeaseCounts[userId] or 0) + 1
	local released = false
	return function()
		if released then
			return
		end
		released = true
		local count = Data._writeLeaseCounts[userId]
		if count == nil then
			return
		end
		if count > 1 then
			Data._writeLeaseCounts[userId] = count - 1
			return
		end
		Data._writeLeaseCounts[userId] = nil
		local pending = Data._pendingSaves[userId]
		if pending and pending.Entry == entry then
			_finishSave(userId, entry)
		end
	end
end

function Data.save(player)
	local userId = player.UserId
	local entry = Data._profiles[userId]
	if not entry or Data._pendingSaves[userId] ~= nil then
		return
	end
	Data._loaded[userId] = nil
	Data._loadGeneration[userId] = (Data._loadGeneration[userId] or 0) + 1
	if entry.ReadyConnection then
		entry.ReadyConnection:Disconnect()
		entry.ReadyConnection = nil
	end
	if (Data._writeLeaseCounts[userId] or 0) == 0 then
		_finishSave(userId, entry)
		return
	end

	local pending = { Entry = entry }
	Data._pendingSaves[userId] = pending
	task.delay(WRITE_LEASE_TIMEOUT_SECONDS, function()
		if Data._pendingSaves[userId] ~= pending then
			return
		end
		warn(`[Data] Timed out waiting for profile writes for user {userId}; closing the profile session`)
		_finishSave(userId, entry)
	end)
end

return Data
