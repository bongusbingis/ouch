local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replica = require(ReplicatedStorage.Packages.replica)
local ProfileStore = require(ReplicatedStorage.Packages.profilestore)
local Promise = require(ReplicatedStorage.Packages.promise)

local Env = require(script.Parent.Parent.Env)
local DataConfig = require(game.ReplicatedStorage.Config.Data)
local ProfileMigrations = require(ReplicatedStorage.Shared.Game.Data.ProfileMigrations)

local Data = {}
Data._profiles = {}

local _profileToken = Replica.Token("GameProfile")
local _dataStore = ProfileStore.New(Env.PrimaryDataKey or "DefaultDataKey", DataConfig.Template)

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

local function _wrapProxy(data, profileReplica, path)
	local proxy = {}
	setmetatable(proxy, {
		__index = function(_, key)
			local value = data[key]
			if type(value) == "table" then
				local newPath = table.clone(path or {})
				table.insert(newPath, key)
				return _wrapProxy(value, profileReplica, newPath)
			end
			return value
		end,
		__newindex = function(_, key, value)
			local fullPath = table.clone(path or {})
			table.insert(fullPath, key)
			local rawValue = value
			if type(value) == "table" then
				value = _wrapProxy(value, profileReplica, fullPath)
			end
			data[key] = value
			profileReplica:Set(fullPath, rawValue)
		end,
		__len = function(_)
			return #data
		end,
		-- __iter = function(_)
		-- 	return next, data, nil
		-- end,
		__pairs = function(_)
			return pairs(data)
		end,
		__ipairs = function(_)
			return ipairs(data)
		end,
		__iter = function(_)
			return pairs, data, nil
		end,
	})
	return proxy
end

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

		-- Ordering is load-bearing on all three counts:
		-- before Reconcile, so a migration can still tell "field absent" from
		-- "field at the template default"; before Replica.New, because after
		-- that every write emits a Set and partial migration state becomes
		-- visible to the client; and never downward, since a rolling deploy
		-- puts old servers in front of newer profiles.
		local migrated, reached, migrationError = ProfileMigrations.apply(profile.Data, DataConfig.SchemaVersion)
		if not migrated then
			warn(
				`[Data] Migration to v{DataConfig.SchemaVersion} failed for {player.Name} at v{reached}: {migrationError}`
			)
			profile:EndSession()
			player:Kick("Data load failed.\nPlease rejoin!")
			return
		end
		profile:Reconcile()

		-- Self-cleaning: disconnects after one fire so it doesn't accumulate.
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
			Data = _wrapProxy(profile.Data, profileReplica),
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

-- Stamped once, on the first session that ever loads this profile. The starter
-- offer window is measured from it, so it must never be rewritten on later joins.
function Data.markFirstJoin(player, now)
	local d = Data.get(player)
	if not d or d.Onboarding.FirstJoinAt > 0 then
		return false
	end
	d.Onboarding.FirstJoinAt = now or os.time()
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
	return _loadPlayerData(player)
		:andThen(function()
			_buildLeaderStats(player):await()
			local d = Data.get(player)
			if d then
				_recalculateKDR(d)
				_syncLeaderStats(player)
			end
		end)
		:andThen(function()
			print(`[Data] Loaded profile for {player.Name} ({player.UserId})`)
		end)
		:catch(function(err)
			warn(`[Data] CRITICAL — failed to load profile for {player.Name} ({player.UserId}): {err}`)
		end)
end

function Data.save(player)
	local entry = Data._profiles[player.UserId]
	if not entry then
		return
	end
	Data._profiles[player.UserId] = nil
	if entry.ReadyConnection then
		entry.ReadyConnection:Disconnect()
		entry.ReadyConnection = nil
	end
	entry.Replica:Destroy()
	entry.Profile:EndSession()
end

return Data
