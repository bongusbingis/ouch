-- Description: Loads, saves, and replicates player profiles, exposing a write-through proxy so mutations replicate automatically, plus the balance, XP, and progression mutators every other service goes through.

local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replica = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("replica"))
local ProfileStore = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("profilestore"))
local Promise = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("promise"))

local Env = require(script.Parent.Parent.Env)
local DataConfig = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Data")
)
local WriteThroughProxy = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Data"):WaitForChild("WriteThroughProxy")
)

local MatchAwards = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("MatchAwards")
)
local BattlePassLogic = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("BattlePassLogic")
)
local Seasons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Seasons"))

local Data = {}
Data._profiles = {}
Data._loaded = {}
Data._loadGeneration = {}
Data._writeLeaseCounts = {}
Data._pendingSaves = {}
Data._loading = {}

local loadedListeners = {}

local _profileToken = Replica.Token("GameProfile")
local _dataStore = ProfileStore.New(Env.PrimaryDataKey or "DefaultDataKey", DataConfig.Template)

local DebugConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Debug"))
if game:GetService("RunService"):IsStudio() and DebugConfig.MockProfiles == true then
	_dataStore = _dataStore.Mock
	warn("[Data] Studio mock profiles enabled (Debug.MockProfiles)")
end

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

local EMOTE_SLOT_COUNT = 8

-- DataStores reject arrays with holes, so the slot list is always a dense
-- eight-entry array where an empty string marks an empty slot.
local function _migrateEmoteSlots(data)
	local slots = data.Cosmetics.EmoteSlots
	if type(slots) ~= "table" then
		slots = {}
	end
	if type(data.Cosmetics.Equipped.EmoteAssets) == "string" and data.Cosmetics.Equipped.EmoteAssets ~= "" then
		slots[1] = data.Cosmetics.Equipped.EmoteAssets
		data.Cosmetics.Equipped.EmoteAssets = nil
	end
	local dense = {}
	for index = 1, EMOTE_SLOT_COUNT do
		local value = slots[index]
		dense[index] = if type(value) == "string" then value else ""
	end
	data.Cosmetics.EmoteSlots = dense
end

local function readyConversionCheck(record, id): (boolean, string?)
	if type(record) ~= "table" or type(record.Ready) ~= "boolean" then
		local received = if type(record) == "table" then record.Ready else record
		return false,
			`MatchAwards.Pending.{tostring(id)}.Ready: expected boolean, received {tostring(received)}; repair the persisted V1 award before replay`
	end
	if not record.Ready then
		return MatchAwards.validateMarkers(record, tostring(id))
	end
	return true, nil
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
		_migrateEmoteSlots(profile.Data)
		local journal = MatchAwards.ensure(profile.Data)
		for id, record in journal.Pending do
			local valid, reason = readyConversionCheck(record, id)
			if not valid then
				warn(`[Data] user {player.UserId} award {tostring(id)}: {reason}`)
				profile:EndSession()
				reject(reason)
				player:Kick("Data load failed.\nPlease rejoin!")
				return
			end
		end
		for _, record in journal.Pending do
			record.Ready = true
		end

		local sessionConn
		sessionConn = profile.OnSessionEnd:Connect(function()
			warn(
				`[Data] session ended for {player.Name}; present={player:IsDescendantOf(PlayersService)}\n{debug.traceback()}`
			)
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

-- CrateService prepares these values on detached tables. Apply the wallet,
-- ownership, pity and receipt payload without yielding, before replication.
-- Profile.Data and Replica.Data share this root; a failed FireClient must not
-- turn an already-applied crate into a retryable grant.
function Data.commitCrateOpen(player, expectedData, draft): boolean
	local entry = Data._profiles[player.UserId]
	if entry == nil or entry.Data ~= expectedData or not entry.Profile:IsActive() then
		return false
	end
	local values = {
		Bonks = draft.Bonks,
		Cosmetics = draft.Cosmetics,
		Crates = draft.Crates,
		ReceiptWork = draft.ReceiptWork,
	}
	for key, value in values do
		entry.Profile.Data[key] = value
	end
	local ok, err = pcall(entry.Replica.SetValues, entry.Replica, {}, values)
	if not ok then
		warn(`[Data] Crate committed but replication failed for user {player.UserId}: {err}`)
	end
	return true
end

function Data.isLoaded(player)
	return Data._loaded[player.UserId] == true
end

function Data.savedReceipts(player)
	local entry = Data._profiles[player.UserId]
	return if entry and entry.Profile.LastSavedData then entry.Profile.LastSavedData.Receipts or {} else {}
end

function Data.confirmReceiptSaved(player, receiptKey): boolean
	local entry = Data._profiles[player.UserId]
	if entry == nil then
		return false
	end
	local profile = entry.Profile
	local function saved()
		local receipts = profile.LastSavedData and profile.LastSavedData.Receipts
		return receipts ~= nil and receipts[receiptKey] ~= nil
	end
	if saved() then
		return true
	end
	if not profile:IsActive() then
		return false
	end
	profile:Save()
	local deadline = os.clock() + DataConfig.Persistence.ReceiptSaveTimeoutSeconds
	while not saved() and profile:IsActive() and os.clock() < deadline do
		task.wait(DataConfig.Persistence.SavePollSeconds)
	end
	return saved()
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

local function applyProgressionDelta(d, delta)
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
end

function Data.applyProgression(player, delta: ProgressionDelta)
	local d = Data.get(player)
	if d == nil then
		return false
	end
	applyProgressionDelta(d, delta)
	_syncLeaderStats(player)
	return true
end

function Data.canQueueMatchAward(player): boolean
	local data = Data.get(player)
	return data ~= nil
		and MatchAwards.hasCapacity(MatchAwards.ensure(data), DataConfig.Persistence.MaxPendingMatchAwards)
end

function Data.matchAwards(player)
	local data = Data.get(player)
	return if data then MatchAwards.ensure(data) else nil
end

function Data.beginMatchAward(player, id, seasonId)
	local journal = Data.matchAwards(player)
	if journal == nil then
		return nil
	end
	return MatchAwards.enqueue(journal, id, {
		SeasonId = seasonId,
		Ready = false,
		ProgressionApplied = false,
		SeasonApplied = false,
		Progress = { Elims = 0, Deaths = 0, Catches = 0, Wins = 0, Losses = 0, MatchesPlayed = 0, XP = 0, Bonks = 0 },
	}, DataConfig.Persistence.MaxPendingMatchAwards)
end

function Data.addMatchProgress(player, id, delta)
	local journal = Data.matchAwards(player)
	local record = journal and journal.Pending[id]
	if record == nil or record.Ready then
		return false
	end
	for field, value in delta do
		record.Progress[field] = (record.Progress[field] or 0) + value
	end
	return true
end

function Data.finishMatchAward(player, id, resultId, won)
	local journal = Data.matchAwards(player)
	local record = journal and journal.Pending[id]
	if record == nil or record.Ready then
		return false
	end
	record.ResultId = resultId
	record.Won = won
	record.Ready = true
	return true
end

function Data.resolveMatchAward(player, id, awarded, multipliers)
	local data = Data.get(player)
	local record = data and MatchAwards.ensure(data).Pending[id]
	if record == nil then
		return nil, `MatchAwards.Pending.{tostring(id)}: journal record is missing`
	end
	local valid, reason = MatchAwards.validatePending(record, tostring(id))
	if not valid then
		return nil, reason
	end
	if record.Awarded == nil then
		valid, reason = MatchAwards.validateDelta(awarded, `MatchAwards.Pending.{tostring(id)}.Awarded`)
		if not valid then
			return nil, reason
		end
		record.Awarded = awarded
		record.Multipliers = multipliers
		record.FirstMatch = data.Progression.MatchesPlayed == 0
	end
	return record
end

-- Read-only V1 eligibility, shared by career preflight and the season write.
-- The award write lease keeps this raw target stable between those calls.
local function seasonCreditPlan(raw, id, requireProgressionApplied): (any?, string?)
	if type(raw) ~= "table" then
		return nil, `MatchAwards.Pending.{tostring(id)}: active raw profile required before award payout`
	end
	local journal = raw.MatchAwards
	if type(journal) ~= "table" or journal.Version ~= 1 then
		local version = if type(journal) == "table" then journal.Version else nil
		return nil,
			`MatchAwards.Version: expected V1 (1), received {tostring(version)}; repair the persisted journal before award replay`
	end
	local record = if type(journal.Pending) == "table" then journal.Pending[id] else nil
	if type(id) ~= "string" or id == "" or type(record) ~= "table" then
		return nil, `MatchAwards.Pending.{tostring(id)}: nonempty award ID and persisted V1 record required`
	end
	local markersValid, markerReason = MatchAwards.validateMarkers(record, id)
	if not markersValid then
		return nil, markerReason
	end
	if not record.Ready then
		return nil,
			`MatchAwards.Pending.{id}.Ready: expected true before award payout; finish the persisted award before replay`
	end
	if requireProgressionApplied and not record.ProgressionApplied then
		return nil,
			`MatchAwards.Pending.{id}.ProgressionApplied: expected true before season credit; apply career payout first`
	end
	local amount = if type(record.Awarded) == "table" then record.Awarded.XP else nil
	if type(amount) ~= "number" or amount < 0 or amount % 1 ~= 0 or math.abs(amount) == math.huge then
		return nil,
			`MatchAwards.Pending.{id}.Awarded.XP: expected finite nonnegative integer, received {tostring(amount)}; repair the persisted V1 award before replay`
	end
	local seasonId = record.SeasonId
	if type(seasonId) ~= "string" or (seasonId ~= "" and Seasons.Definitions[seasonId] == nil) then
		return nil,
			`MatchAwards.Pending.{id}.SeasonId: unknown season {tostring(seasonId)}; restore its definition or repair this persisted award`
	end
	if type(raw.Season) ~= "table" then
		return nil, `Season: expected table before award {id} credit; repair persisted season state`
	end
	if type(raw.SeasonHistory) ~= "table" then
		return nil, `SeasonHistory: expected table before award {id} credit; repair persisted season state`
	end
	local activeValid, activeReason = BattlePassLogic.validateStoredState(raw.Season, "Season")
	if not activeValid then
		return nil, `{activeReason}; repair persisted season state before award replay`
	end
	local target: any = nil
	local newArchive = false
	if seasonId ~= "" then
		local targetPath = `SeasonHistory.{seasonId}`
		if raw.Season.Id == seasonId then
			target = raw.Season
			targetPath = "Season"
		else
			target = raw.SeasonHistory[seasonId]
			if target ~= nil then
				local valid, reason = BattlePassLogic.validateStoredState(target, targetPath, seasonId)
				if not valid then
					return nil, `{reason}; repair persisted season state before award replay`
				end
			elseif record.SeasonApplied and amount > 0 then
				return nil,
					`SeasonHistory.{seasonId}: missing for already season-applied positive-XP award {id}; inspect persisted credit before repair`
			elseif not record.SeasonApplied and amount > 0 then
				local count = 0
				for _ in raw.SeasonHistory do
					count += 1
				end
				if count >= DataConfig.Persistence.MaxSeasonArchives then
					return nil,
						`SeasonHistory.{seasonId}: archive capacity {DataConfig.Persistence.MaxSeasonArchives} reached before award {id} XP credit; settle or migrate an archive through an approved data operation`
				end
				newArchive = true
			end
		end
		if not record.SeasonApplied and amount > 0 then
			local current = if target ~= nil then target.XP else 0
			local nextXp = current + amount
			if nextXp < 0 or nextXp % 1 ~= 0 or math.abs(nextXp) == math.huge then
				return nil,
					`{targetPath}.XP: current {tostring(current)} + award {tostring(amount)} is nonfinite or noninteger; repair stored season state or award`
			end
		end
	end
	return { seasonId = seasonId, amount = amount, target = target, newArchive = newArchive }, nil
end

function Data.applyMatchAward(player, id): (boolean, string?)
	local journal = Data.matchAwards(player)
	local record = journal and journal.Pending[id]
	if record == nil then
		return false, `MatchAwards.Pending.{tostring(id)}: journal record is missing`
	end
	local valid, reason = MatchAwards.validatePending(record, tostring(id))
	if not valid then
		return false, reason
	end
	if record.Awarded == nil then
		return false, `MatchAwards.Pending.{tostring(id)}.Awarded: required before career payout`
	end
	local entry = Data._profiles[player.UserId]
	local plan, planReason = seasonCreditPlan(entry and entry.Profile and entry.Profile.Data, id, false)
	if plan == nil then
		return false, planReason
	end
	if record.ProgressionApplied then
		return true
	end
	local data = Data.get(player)
	if data == nil then
		return false
	end
	applyProgressionDelta(data, record.Awarded)
	record.ProgressionApplied = true
	_syncLeaderStats(player)
	return true
end

function Data.markMatchSeasonApplied(player, id)
	local journal = Data.matchAwards(player)
	local record = journal and journal.Pending[id]
	if record then
		record.SeasonApplied = true
	end
end

-- Match award writes hold acquireWriteLease. Profile.Data and Replica.Data share
-- the raw tables; write XP and its V1 journal marker before either notification.
-- A failed Replica send is retried in this session without repeating the credit.
function Data.creditMatchSeasonXp(player, id): (boolean, string?)
	local entry = Data._profiles[player.UserId]
	if
		entry == nil
		or entry.Profile == nil
		or not entry.Profile:IsActive()
		or (Data._writeLeaseCounts[player.UserId] or 0) == 0
	then
		return false, `award {tostring(id)}: active profile and award write lease required`
	end
	local raw = entry.Profile.Data
	local plan, planReason = seasonCreditPlan(raw, id, true)
	if plan == nil then
		return false, planReason
	end
	local record = raw.MatchAwards.Pending[id]
	local seasonId = plan.seasonId
	local amount = plan.amount
	if not record.SeasonApplied then
		if seasonId ~= "" and amount > 0 then
			local target = plan.target
			if plan.newArchive then
				target = BattlePassLogic.blankState(seasonId)
				raw.SeasonHistory[seasonId] = target
			end
			target.XP += amount
		end
		record.SeasonApplied = true
		entry.SeasonReplicationPending = entry.SeasonReplicationPending or {}
		entry.SeasonReplicationPending[id] = true
	end
	if entry.SeasonReplicationPending and entry.SeasonReplicationPending[id] then
		local ok, err = pcall(function()
			if seasonId ~= "" and amount > 0 then
				if raw.Season.Id == seasonId then
					entry.Replica:Set({ "Season", "XP" }, raw.Season.XP)
				else
					-- The first archive notification may have failed, so a retry must
					-- send the whole entry rather than assuming the client has its path.
					entry.Replica:Set({ "SeasonHistory", seasonId }, raw.SeasonHistory[seasonId])
				end
			end
			entry.Replica:Set({ "MatchAwards", "Pending", id, "SeasonApplied" }, true)
		end)
		if not ok then
			return false, `award {id} season {seasonId}: XP and marker committed; Replica notification failed: {err}`
		end
		entry.SeasonReplicationPending[id] = nil
	end
	return true, nil
end

function Data.completeMatchAward(player, id): boolean
	local journal = Data.matchAwards(player)
	local record = journal and journal.Pending[id]
	if record == nil or not record.ProgressionApplied or not record.SeasonApplied then
		return false
	end
	MatchAwards.complete(journal, id, os.time(), DataConfig.Persistence.CompletedMatchAwardHistory)
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

function Data.setFieldForAdmin(player, field, value)
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

function Data.addFieldForAdmin(player, field, amount)
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

	return Data.setFieldForAdmin(player, field, current + amount)
end

-- PlayerAdded and the startup sweep of existing players both call this, so a
-- player who joins during server start must not open two sessions on one key.
function Data.load(player)
	local userId = player.UserId
	local inFlight = Data._loading[userId]
	if inFlight then
		return inFlight
	end
	if Data._profiles[userId] then
		return Promise.resolve()
	end
	local generation = (Data._loadGeneration[userId] or 0) + 1
	Data._loadGeneration[userId] = generation
	Data._loaded[userId] = nil
	local promise
	promise = _loadPlayerData(player)
		:andThen(function()
			_buildLeaderStats(player):await()
			local d = Data.get(player)
			if d then
				_recalculateKDR(d)
				_syncLeaderStats(player)
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
		:finally(function()
			if Data._loading[userId] == promise then
				Data._loading[userId] = nil
			end
		end)
	Data._loading[userId] = promise
	return promise
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
		if Data._profiles[userId] ~= entry then
			return
		end
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
	for id, record in MatchAwards.ensure(entry.Data).Pending do
		local valid, reason = readyConversionCheck(record, id)
		if not valid then
			warn(`[Data] user {userId} award {tostring(id)}: {reason}`)
		else
			record.Ready = true
		end
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

Data._migrateEmoteSlots = _migrateEmoteSlots

return Data
