local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replica = require(ReplicatedStorage.Packages.replica)
local ProfileStore = require(ReplicatedStorage.Packages.profilestore)
local Promise = require(ReplicatedStorage.Packages.promise)

local Env = require(script.Parent.Parent.Env)
local DataConfig = require(game.ReplicatedStorage.Config.Data)

local Data = {}
Data._profiles = {}

local _profileToken = Replica.Token("GameProfile")
local _dataStore = ProfileStore.New(Env.PrimaryDataKey or "DefaultDataKey", DataConfig.Template)

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

		repeat
			task.wait()
		until profileReplica.ReadyPlayers[player] or player == nil or profile == nil

		if player == nil or profile == nil then
			reject(`Replica load failed for: {player.Name}`)
			return
		end

		Data._profiles[player.UserId] = {
			Profile = profile,
			Data = _wrapProxy(profile.Data, profileReplica),
			Replica = profileReplica,
		}
		Data._profiles[player.UserId].Replica:Subscribe(player)
		resolve(true)
	end)
end

local function _buildLeaderStats(player)
	return Promise.new(function(resolve)
		local leaderStats = Instance.new("Folder")
		leaderStats.Name = "leaderstats"
		leaderStats.Parent = player

		local entry = Data._profiles[player.UserId]
		if not entry then
			warn(`[Data] Profile missing for {player.Name} when building leaderstats`)
			resolve(false)
			return
		end

		for _, info in ipairs(DataConfig.Leaderstats) do
			local value = Instance.new(info.Type)
			value.Name = info.Name
			value.Parent = leaderStats
			value.Value = info._Build(player, entry)
		end

		resolve(true)
	end)
end

function Data.get(player)
	local entry = Data._profiles[player.UserId]
	return entry and entry.Data
end

function Data.addCash(player, amount)
	local d = Data.get(player)
	if d then
		d.Cash = d.Cash + amount
	end
end

function Data.addXP(player, amount)
	local d = Data.get(player)
	if d then
		d.Level.Points = d.Level.Points + amount
	end
end

function Data.load(player)
	return _loadPlayerData(player)
		:andThen(function()
			_buildLeaderStats(player):await()
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
	entry.Replica:Destroy()
	entry.Profile:EndSession()
end

return Data
