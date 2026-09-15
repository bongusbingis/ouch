-- Offline matchmaking regression probe: executes current matchmaking/repository/retry source against
-- atomic in-memory stores and a deterministic coroutine clock. No Roblox calls.
-- Run from repository root: lune run src/scripts/lune/probe-matchmaking-capacity.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")

local output = ".review/matchmaking"
local base = "places/lobby/server/Modules/Matchmaking/"
local files = {
	Config = "places/lobby/shared/Matchmaking/Config.luau",
	GameModes = "src/config/Gameplay/GameModes.luau",
	Queues = "src/config/Gameplay/Queues.luau",
	TeleportPayload = "src/shared/Game/Matchmaking/TeleportPayload.luau",
	ArenaReadinessGate = "src/shared/Game/Matchmaking/ArenaReadinessGate.luau",
	PopulationPolicy = "src/shared/Game/Matchmaking/PopulationPolicy.luau",
	PartyModel = base .. "PartyModel.luau",
	CloudRetry = base .. "CloudRetry.luau",
	PartyRepository = base .. "PartyRepository.luau",
	QueueRepository = base .. "QueueRepository.luau",
	MatchRepository = base .. "MatchRepository.luau",
	MatchmakerService = base .. "MatchmakerService.luau",
}

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = copy(child)
	end
	return result
end

local function count(values)
	local result = 0
	for _ in values do
		result += 1
	end
	return result
end

local function node(name)
	return setmetatable({ Name = name }, {
		__index = function(_, key)
			if key == "WaitForChild" then
				return function(_, child)
					return node(child)
				end
			end
			return node(key)
		end,
	})
end

local World = {}
World.__index = World
function World.new(latency)
	return setmetatable({
		now = 1000,
		latency = latency or 0,
		sequence = 0,
		events = {},
		maps = {},
		operations = {},
		notifications = {},
		warnings = {},
		guid = 0,
		crashed = 0,
	}, World)
end

function World:schedule(at, callback)
	self.sequence += 1
	table.insert(self.events, { at = at, sequence = self.sequence, thread = coroutine.create(callback) })
end

function World:run(untilTime)
	while #self.events > 0 do
		table.sort(self.events, function(a, b)
			return a.at < b.at or (a.at == b.at and a.sequence < b.sequence)
		end)
		local event = self.events[1]
		if untilTime and event.at > untilTime then
			self.now = untilTime
			return
		end
		table.remove(self.events, 1)
		self.now = event.at
		local ok, yielded = coroutine.resume(event.thread)
		assert(ok, tostring(yielded))
		if coroutine.status(event.thread) ~= "dead" then
			if yielded.stop then
				self.crashed += 1
			else
				self.sequence += 1
				table.insert(self.events, {
					at = self.now + yielded.delay,
					sequence = self.sequence,
					thread = event.thread,
				})
			end
		end
	end
	if untilTime then
		self.now = untilTime
	end
end

function World:call(worker, kind, structure, key, action)
	local operation = {
		worker = worker,
		kind = kind,
		structure = structure,
		key = key,
		startedAt = self.now,
		units = if kind == "UpdateAsync" then 2 elseif kind == "ReserveServerAsync" then 0 else 1,
	}
	table.insert(self.operations, operation)
	local fault = if self.fault then self.fault(operation, self) else nil
	local delay = if self.delay then self.delay(operation, self) else self.latency
	coroutine.yield({ delay = delay })
	if fault == "crash_before" then
		coroutine.yield({ stop = true })
	end
	if fault == "error_before" then
		operation.error = fault
		error("injected transient failure")
	end
	local result = action()
	operation.completedAt = self.now
	if kind == "GetRangeAsync" then
		operation.units = math.max(1, #result)
	end
	if fault == "crash_after" then
		coroutine.yield({ stop = true })
	end
	if fault == "error_after" then
		operation.error = fault
		error("injected ambiguous commit")
	end
	return copy(result)
end

function World:map(worker, name)
	local structure = string.match(name, ":([^:]+)$")
	if not self.maps[structure] then
		self.maps[structure] = {}
	end
	local records = self.maps[structure]
	local world = self
	local function live(key)
		local record = records[key]
		if record and record.expiresAt <= world.now then
			records[key] = nil
			return nil
		end
		return record
	end
	return {
		GetAsync = function(_, key)
			return world:call(worker, "GetAsync", structure, key, function()
				local record = live(key)
				return record and record.value
			end)
		end,
		SetAsync = function(_, key, value, ttl, sortKey)
			return world:call(worker, "SetAsync", structure, key, function()
				records[key] = { value = copy(value), expiresAt = world.now + ttl, sortKey = sortKey }
				return true
			end)
		end,
		UpdateAsync = function(_, key, transform, ttl)
			return world:call(worker, "UpdateAsync", structure, key, function()
				local record = live(key)
				local updated = transform(copy(record and record.value))
				if updated == nil then
					return nil
				end
				records[key] = { value = copy(updated), expiresAt = world.now + ttl }
				return updated
			end)
		end,
		RemoveAsync = function(_, key)
			return world:call(worker, "RemoveAsync", structure, key, function()
				records[key] = nil
				return true
			end)
		end,
		GetRangeAsync = function(_, _, limit)
			return world:call(worker, "GetRangeAsync", structure, "range", function()
				local items = {}
				for key in records do
					local record = live(key)
					if record then
						table.insert(items, { key = key, value = copy(record.value), sortKey = record.sortKey })
					end
				end
				table.sort(items, function(a, b)
					return a.sortKey < b.sortKey
				end)
				while #items > limit do
					table.remove(items)
				end
				return items
			end)
		end,
	}
end

function World:worker(id, queueId)
	queueId = queueId or "Arena"
	local world, cache = self, {}
	local fakeGame = { JobId = id }
	function fakeGame.GetService(_, serviceName)
		if serviceName == "HttpService" then
			return {
				GenerateGUID = function()
					world.guid += 1
					return "match-" .. tostring(world.guid)
				end,
			}
		end
		if serviceName == "RunService" then
			return {
				IsStudio = function()
					return true
				end,
			}
		end
		if serviceName == "MemoryStoreService" then
			return {
				GetHashMap = function(_, name)
					return world:map(id, name)
				end,
				GetSortedMap = function(_, name)
					return world:map(id, name)
				end,
			}
		end
		return node(serviceName)
	end
	local clock = table.clone(os)
	clock.time = function()
		return math.floor(world.now)
	end
	clock.clock = function()
		return world.now
	end
	local function load(name)
		if cache[name] then
			return cache[name]
		end
		local environment = {
			game = fakeGame,
			script = node(name),
			os = clock,
			require = function(target)
				return load(target.Name)
			end,
			DateTime = {
				now = function()
					return { UnixTimestampMillis = world.now * 1000 }
				end,
			},
			Random = {
				new = function()
					return {
						NextNumber = function(_, low, high)
							return (low + high) / 2
						end,
						NextInteger = function(_, low)
							return low
						end,
					}
				end,
			},
			Enum = { SortDirection = { Ascending = "Ascending" } },
			task = {
				wait = function(delay)
					coroutine.yield({ delay = delay })
				end,
			},
			warn = function(message)
				table.insert(world.warnings, tostring(message))
			end,
		}
		cache[name] = luau.load(fs.readFile(assert(files[name], name)), {
			debugName = files[name],
			environment = environment,
			injectGlobals = true,
		})()
		return cache[name]
	end
	local config = load("Config")
	local party = load("PartyRepository").new()
	local queue = load("QueueRepository").new(queueId)
	local matches = load("MatchRepository").new()
	local retry = load("CloudRetry")
	local teleport = {
		ReserveServer = function()
			local success, accessCode = retry.call("TeleportCoordinator.ReserveServer", function()
				return world:call(id, "ReserveServerAsync", "TeleportService", "reserve", function()
					return "reserved-" .. tostring(world.guid)
				end)
			end)
			return if success then accessCode else nil
		end,
	}
	local service = load("MatchmakerService").new(queueId, party, queue, matches, teleport, function(value, reason)
		table.insert(
			world.notifications,
			{ partyId = value.partyId, reason = reason, at = world.now, matchId = value.matchId }
		)
	end)
	return {
		service = service,
		party = party,
		queue = queue,
		matches = matches,
		config = config,
		payload = load("TeleportPayload"),
		gate = load("ArenaReadinessGate"),
	}
end

function World:seed(parties, size, state, queueId)
	queueId = queueId or "Arena"
	for index = 1, parties do
		local id = string.format("party-%04d", index)
		local ticket = {
			queueId = queueId,
			partyId = id,
			ticketId = "ticket-" .. id,
			partySize = size,
			enqueuedAt = 999 + index / 10000,
		}
		local members = {}
		for member = 1, size do
			table.insert(members, { userId = index * 10 + member })
		end
		local party = {
			partyId = id,
			phase = "Queued",
			members = members,
			leaderUserId = members[1].userId,
			queueTicket = copy(ticket),
			revision = 1,
			leaseUntil = 1090,
		}
		if state then
			state(party, index)
		end
		self.maps.PartyById[id] = { value = party, expiresAt = 1600 }
		self.maps[queueId][id] = { value = ticket, sortKey = ticket.enqueuedAt, expiresAt = 1180 }
	end
end

function World:summary()
	local counts, units, errors = {}, 0, 0
	for _, operation in self.operations do
		local name = operation.structure .. "." .. operation.kind
		counts[name] = (counts[name] or 0) + 1
		units += operation.units
		if operation.error then
			errors += 1
		end
	end
	local phases, assignments = {}, {}
	for id, record in self.maps.PartyById or {} do
		phases[record.value.phase] = (phases[record.value.phase] or 0) + 1
		if record.value.matchId then
			assignments[id] = record.value.matchId
		end
	end
	return {
		virtualElapsedSeconds = self.now - 1000,
		callCount = #self.operations,
		minimumMemoryStoreUnits = units,
		operationCounts = counts,
		errors = errors,
		phases = phases,
		assignments = assignments,
		matchRecords = count(self.maps.MatchById or {}),
		notifications = #self.notifications,
		crashedWorkers = self.crashed,
	}
end

local results = {}
local function case(name, callback)
	local started = os.clock()
	local result = callback()
	result.name = name
	result.harnessWallSeconds = os.clock() - started
	table.insert(results, result)
	print(
		string.format(
			"%s: %s | %d calls, %.3fs virtual",
			name,
			result.outcome,
			result.callCount or 0,
			result.virtualElapsedSeconds or 0
		)
	)
end

-- Execute the real queue/party repositories and matchmaker from two distinct
-- JobIds sharing one queue. The clock and cloud calls are simulated.
for _, queueId in { "Arena", "Splashdown" } do
	case(queueId .. "-two-solos-across-lobby-workers", function()
		local world = World.new(0.005)
		local first, second = world:worker("lobby-A", queueId), world:worker("lobby-B", queueId)
		world:seed(2, 1, nil, queueId)
		for at = 1000, 1034, first.config.WorkerPollInterval do
			for _, worker in { first, second } do
				world:schedule(at, function()
					worker.service:Tick()
				end)
			end
		end
		world:run()
		local result = world:summary()
		assert(result.matchRecords == 1 and result.phases.Assigned == 2, "both solos must share exactly one match")
		assert(
			result.assignments["party-0001"] == result.assignments["party-0002"],
			"workers must not split the racers"
		)
		local match = world.maps.MatchById[result.assignments["party-0001"]].value
		assert(#match.expectedUserIds == 2 and #match.parties == 2, "match must contain the actual two players")
		assert(match.queueId == queueId, "retain the selected mode's queue")
		local assignedAt = world.notifications[1].at
		assert(assignedAt >= 1029 and assignedAt < 1033, "assign at the 30-second fallback plus one poll")
		for _, party in match.parties do
			local payload = first.payload.build(match, party.partyId)
			assert(payload.expectedPlayerCount == 2, "arena must wait for the actual roster, not capacity")
			assert(first.payload.parse(payload), "arena must accept the small match payload")
			local gate = first.gate.new("Matched", payload.expectedPlayerCount, 1100)
			for _, userId in match.expectedUserIds do
				first.gate.arrive(gate, userId)
				first.gate.markReady(gate, userId)
			end
			local released, reason = first.gate.evaluate(gate, 1040)
			assert(released and reason == "all_ready", "two ready racers must release the arrival gate")
		end
		result.assignmentAgeSeconds = assignedAt - 999.0001
		result.outcome =
			"PASS: two lobby workers assign both solos to one match at the fallback; two-player arrival gate opens"
		return result
	end)
end

case("Splashdown-three-minute-wait-regression", function()
	local world = World.new(0)
	local worker = world:worker("lobby-A", "Splashdown")
	world:seed(2, 1, nil, "Splashdown")
	-- Model still-connected players whose queue records have been refreshed.
	for id, record in world.maps.Splashdown do
		record.value.enqueuedAt = 820
		record.sortKey = 820
		world.maps.PartyById[id].value.queueTicket.enqueuedAt = 820
	end
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(result.matchRecords == 1 and result.phases.Assigned == 2, "two racers waiting three minutes must match now")
	result.outcome = "PASS: the reported two-player three-minute wait forms a match on the next tick"
	return result
end)

for _, scenario in
	{
		{ name = "full-roster-immediate", parties = 30, size = 1, before = nil, at = 1000, expected = 30 },
		{ name = "four-racers-at-20s", parties = 4, size = 1, before = 1019, at = 1020, expected = 4 },
		{ name = "two-person-party-at-30s", parties = 1, size = 2, before = 1029, at = 1030, expected = 2 },
	}
do
	case("Splashdown-" .. scenario.name, function()
		local world = World.new(0)
		local worker = world:worker("lobby-A", "Splashdown")
		world:seed(scenario.parties, scenario.size, nil, "Splashdown")
		if scenario.before then
			world:schedule(scenario.before, function()
				worker.service:Tick()
			end)
			world:run()
			assert(world:summary().matchRecords == 0, "give the queue until its configured boundary to fill")
		end
		world:schedule(scenario.at, function()
			worker.service:Tick()
		end)
		world:run()
		local result = world:summary()
		assert(result.matchRecords == 1 and result.phases.Assigned == scenario.parties, "whole roster must be assigned")
		local match = world.maps.MatchById[result.assignments["party-0001"]].value
		assert(
			#match.expectedUserIds == scenario.expected and match.targetPlayers == 30,
			"keep capacity separate from roster"
		)
		assert(
			match.modeSelection.strategy == "Fixed" and match.modeSelection.modeId == "Splashdown",
			"retain race mode"
		)
		result.outcome = "PASS: match forms at the correct boundary with intact parties and fixed Splashdown mode"
		return result
	end)
end

case("Splashdown-lone-racer-waits-then-matches-new-opponent", function()
	local world = World.new(0)
	local worker = world:worker("lobby-A", "Splashdown")
	world:seed(2, 1, nil, "Splashdown")
	local secondTicket = world.maps.Splashdown["party-0002"]
	local secondParty = world.maps.PartyById["party-0002"]
	world.maps.Splashdown["party-0002"] = nil
	world.maps.PartyById["party-0002"] = nil
	world:schedule(1030, function()
		worker.service:Tick()
	end)
	world:run()
	assert(world:summary().matchRecords == 0 and world:summary().phases.Queued == 1, "do not start solo matches")
	secondTicket.value.enqueuedAt = 1032
	secondTicket.sortKey = 1032
	secondParty.value.queueTicket.enqueuedAt = 1032
	world.maps.Splashdown["party-0002"] = secondTicket
	world.maps.PartyById["party-0002"] = secondParty
	world:schedule(1032, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.matchRecords == 1 and result.phases.Assigned == 2,
		"new opponent must not reset the first player's wait"
	)
	result.outcome = "PASS: one racer waits safely; a newly queued opponent joins their match immediately after the cap"
	return result
end)

case("Splashdown-refresh-preserves-wait-and-timeout-survives-incomplete-ladder", function()
	local world = World.new(0)
	local worker = world:worker("lobby-A", "Splashdown")
	world:seed(2, 1, nil, "Splashdown")
	worker.config.Queues.Splashdown.MatchPopulationExpansion = {
		{ AfterSeconds = 0, MinimumPlayers = 30 },
		{ AfterSeconds = 10, MinimumPlayers = 20 },
	}
	world:schedule(1020, function()
		for _, record in world.maps.PartyById do
			assert(worker.queue:Refresh(record.value.queueTicket), "refresh must succeed")
		end
		worker.service:Tick()
	end)
	world:run()
	assert(world:summary().matchRecords == 0, "incomplete ladder still prefers a larger match before timeout")
	world:schedule(1030, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.matchRecords == 1 and result.phases.Assigned == 2,
		"explicit fallback must override the incomplete ladder"
	)
	result.outcome = "PASS: queue refresh retains age; an incomplete ladder cannot block the two-player timeout"
	return result
end)

case("Splashdown-stale-age-cannot-start-fresh-racers-early", function()
	local world = World.new(0)
	local worker = world:worker("lobby-A", "Splashdown")
	world:seed(4, 1, function(party, index)
		if index <= 2 then
			party.phase = "Lobby"
		end
	end, "Splashdown")
	for index = 1, 2 do
		local id = string.format("party-%04d", index)
		world.maps.Splashdown[id].value.enqueuedAt = 820
		world.maps.Splashdown[id].sortKey = 820
	end
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local before = world:summary()
	assert(
		before.matchRecords == 0 and before.phases.Queued == 2,
		"recheck age using only successfully claimed players"
	)
	world:schedule(1030, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.matchRecords == 1 and result.phases.Assigned == 2,
		"fresh racers remain eligible at their own threshold"
	)
	result.outcome = "PASS: stale tickets cannot start fresh players early or prevent their later match"
	return result
end)

case("Splashdown-reservation-failure-preserves-earned-wait", function()
	local world = World.new(0.005)
	local worker = world:worker("lobby-A", "Splashdown")
	world:seed(2, 1, nil, "Splashdown")
	world.fault = function(operation)
		return if operation.kind == "ReserveServerAsync" then "error_before" else nil
	end
	world:schedule(1030, function()
		worker.service:Tick()
	end)
	world:run()
	local before = world:summary()
	assert(before.matchRecords == 0 and before.phases.Queued == 2, "failed reservation must release both claims")
	for _, record in world.maps.PartyById do
		assert(record.value.queueTicket.enqueuedAt < 1000, "released claims must retain their original age")
	end
	world.fault = nil
	world:schedule(world.now + worker.config.WorkerPollInterval, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(result.matchRecords == 1 and result.phases.Assigned == 2, "retry must not impose another population wait")
	result.outcome = "PASS: exhausted reservation retries release intact parties; the next healthy tick matches them"
	return result
end)

for _, size in { 1, 4 } do
	for _, milliseconds in { 0, 5, 20, 100, 200 } do
		case(string.format("healthy-party%d-%dms", size, milliseconds), function()
			local world = World.new(milliseconds / 1000)
			local worker = world:worker("worker-A")
			world:seed(100, size)
			world:schedule(1000, function()
				worker.service:Tick()
			end)
			world:run()
			local result = world:summary()
			assert(result.phases.Assigned == 20 / size, "whole full match must be assigned")
			assert(result.callCount == 3 * (20 / size) + 5, "critical path operation count changed")
			assert(result.minimumMemoryStoreUnits == 100 + 5 * (20 / size) + 5, "request-unit floor changed")
			result.injectedLatencyMsPerCall = milliseconds
			result.partySize = size
			result.idealMatchesPerSecond = if milliseconds > 0 then 1 / result.virtualElapsedSeconds else nil
			result.leaseOverrun = result.virtualElapsedSeconds > worker.config.WorkerLeaseLifetime
			result.outcome = "PASS: exact current-source path measured; latency is injected"
			return result
		end)
	end
end

case("concurrent-workers-healthy-lease", function()
	local world = World.new(0.02)
	local first, second = world:worker("worker-A"), world:worker("worker-B")
	world:seed(40, 1)
	world:schedule(1000, function()
		first.service:Tick()
	end)
	world:schedule(1000, function()
		second.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(result.matchRecords == 1 and result.phases.Assigned == 20, "only the lease winner must form a match")
	assert(result.operationCounts["WorkerLease.UpdateAsync"] == 3, "one extra denied lease call must be counted")
	result.outcome = "PASS: one lease winner, one denied acquisition, one whole match"
	return result
end)

case("reservation-overruns-worker-and-claim-leases", function()
	local world = World.new(0.005)
	local first, second = world:worker("worker-A"), world:worker("worker-B")
	world:seed(40, 1)
	local delayed = false
	world.delay = function(operation)
		if operation.worker == "worker-A" and operation.kind == "ReserveServerAsync" and not delayed then
			delayed = true
			return 35
		end
		return 0.005
	end
	world:schedule(1000, function()
		first.service:Tick()
	end)
	world:schedule(1011, function()
		second.service:Tick()
	end)
	world:schedule(1031, function()
		second.service:Tick()
	end)
	world:schedule(1032, function()
		second.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.matchRecords == 2 and result.phases.Assigned == 40 and not result.phases.Queued,
		"late reservation must not publish a third record or clear newer assignments"
	)
	local matchingRecords = 0
	for _, record in world.maps.MatchById do
		if record.value.parties[1].partyId == "party-0001" then
			matchingRecords += 1
		end
	end
	assert(matchingRecords == 1, "only the authoritative new match may name the original parties")
	for _, operation in world.operations do
		assert(
			not (operation.worker == "worker-A" and operation.structure == "MatchById" and operation.kind == "SetAsync"),
			"expired reservation must stop before any Ready record write"
		)
	end
	result.outcome =
		"PASS: expired reservation publishes no Ready record and cannot clear the newer worker's assignments"
	result.trace = world.operations
	return result
end)

for _, reserveSeconds in { 8, 10 } do
	case(string.format("reservation-%ds-worker-deadline", reserveSeconds), function()
		local world = World.new(0.005)
		local first, second = world:worker("worker-A"), world:worker("worker-B")
		world:seed(20, 1)
		world.delay = function(operation)
			return if operation.worker == "worker-A" and operation.kind == "ReserveServerAsync"
				then reserveSeconds
				else 0.005
		end
		world:schedule(1000, function()
			first.service:Tick()
		end)
		world:run()
		local firstResult = world:summary()
		if reserveSeconds == 8 then
			assert(
				firstResult.matchRecords == 1 and firstResult.phases.Assigned == 20,
				"in-time reservation must still assign"
			)
			assert(firstResult.callCount == 65, "healthy reservation must add no cloud calls")
			firstResult.outcome = "PASS: reservation before the deadline retains the same match and operation path"
			return firstResult
		end
		assert(world.now < 1030, "fixture must abort before the original party claims would expire")
		assert(
			firstResult.matchRecords == 0 and firstResult.phases.Queued == 20,
			"expired worker must release its still-live claims"
		)
		assert(
			not firstResult.operationCounts["MatchById.SetAsync"],
			"no Ready write may start after the reservation deadline"
		)
		world:schedule(1011, function()
			second.service:Tick()
		end)
		world:run()
		local result = world:summary()
		assert(result.matchRecords == 1 and result.phases.Assigned == 20, "returned claims must remain matchable")
		result.afterExpiredReservation = firstResult
		result.outcome = "PASS: worker expiry aborts before claim expiry; all intact parties remain matchable"
		return result
	end)
end

case("late-reservation-cannot-clear-newer-in-flight-claims", function()
	local world = World.new(0.005)
	local first, second = world:worker("worker-A"), world:worker("worker-B")
	world:seed(40, 1)
	world.delay = function(operation)
		if operation.kind == "ReserveServerAsync" then
			if operation.worker == "worker-A" then
				return 35
			elseif world.now >= 1032 then
				return 4
			end
		end
		return 0.005
	end
	world:schedule(1000, function()
		first.service:Tick()
	end)
	for _, at in { 1011, 1031, 1032 } do
		world:schedule(at, function()
			second.service:Tick()
		end)
	end
	world:run(1035.5)
	local during = world:summary()
	assert(
		during.phases.Claimed == 20 and during.phases.Assigned == 20 and during.matchRecords == 1,
		"old cleanup must preserve all new claims"
	)
	local newClaim = world.maps.PartyById["party-0001"].value.claim.claimId
	assert(newClaim ~= "match-1", "the surviving claim must belong to the new worker")
	local lease = world.maps.WorkerLease["Worker:Arena"].value
	assert(
		lease.ownerJobId == "worker-B" and lease.expiresAt > world.now,
		"old cleanup must not release the new worker lease"
	)
	world:run()
	local result = world:summary()
	assert(
		result.phases.Assigned == 40 and result.matchRecords == 2,
		"new worker must finish both legitimate match sets"
	)
	assert(result.assignments["party-0001"] == newClaim, "new claim must remain the final assignment")
	result.duringNewReservation = during
	result.outcome = "PASS: late cleanup preserves newer in-flight party claims and worker lease, which finish normally"
	return result
end)

case("match-store-call-overrun-remains-unfenced", function()
	local world = World.new(0.005)
	local first, second = world:worker("worker-A"), world:worker("worker-B")
	world:seed(40, 1)
	world.delay = function(operation)
		return if operation.worker == "worker-A"
				and operation.structure == "MatchById"
				and operation.kind == "SetAsync"
			then 35
			else 0.005
	end
	world:schedule(1000, function()
		first.service:Tick()
	end)
	for _, at in { 1011, 1031, 1032 } do
		world:schedule(at, function()
			second.service:Tick()
		end)
	end
	world:run()
	local result = world:summary()
	assert(
		result.matchRecords == 3 and result.phases.Assigned == 40,
		"the separate delayed-store residual must remain visible"
	)
	result.outcome =
		"RESIDUAL REPRODUCED: an in-time SetMatch call can commit late; assignment tokens still prevent duplicate active assignments"
	result.trace = world.operations
	return result
end)

case("claimed-prefix-serves-oldest-viable-tail-in-first-tick", function()
	local world = World.new(0.005)
	local worker = world:worker("worker-A")
	world:seed(120, 1, function(party, index)
		if index <= 20 then
			party.phase = "Claimed"
			party.claim = { claimId = "dead-worker", expiresAt = 1030 }
		end
	end)
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.phases.Assigned == 20 and result.phases.Claimed == 20 and result.matchRecords == 1,
		"viable tail must match without altering live claims"
	)
	for index = 21, 40 do
		assert(result.assignments[string.format("party-%04d", index)], "oldest viable parties must be served first")
	end
	result.firstAssignmentAgeSeconds = world.notifications[#world.notifications].at - 999.0001
	result.outcome = "PASS: first tick assigns oldest 20 viable solos behind 20 live claims; no claim expiry required"
	return result
end)

case("stale-four-player-prefix-cleared-in-one-bounded-snapshot", function()
	local world = World.new(0.005)
	local worker = world:worker("worker-A")
	world:seed(105, 4, function(party, index)
		if index <= 100 then
			party.phase = "Lobby"
		end
	end)
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local beforeFinalTick = world:summary()
	assert(
		beforeFinalTick.matchRecords == 0 and beforeFinalTick.phases.Queued == 5,
		"the first fetched snapshot contains only stale tickets"
	)
	assert(
		count(world.maps.Arena) == 5,
		"one tick must clear the fetched 100 stale tickets without exceeding the snapshot"
	)
	world:schedule(1002, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(result.phases.Assigned == 5, "all viable parties must match after stale prefix cleanup")
	result.beforeFinalTick = beforeFinalTick
	result.outcome =
		"PASS: one tick clears the 100-row stale snapshot; next tick serves the five formerly hidden viable parties"
	return result
end)

case("stale-four-player-prefix-serves-viable-parties-in-first-tick", function()
	local world = World.new(0.005)
	local worker = world:worker("worker-A")
	world:seed(100, 4, function(party, index)
		if index <= 95 then
			party.phase = "Lobby"
		end
	end)
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.phases.Assigned == 5 and result.matchRecords == 1,
		"five viable parties inside the fetched prefix must match in one tick"
	)
	assert(count(world.maps.Arena) == 0, "all stale and assigned tickets in this snapshot must be removed")
	result.outcome =
		"PASS: one tick skips 95 stale four-player tickets and assigns the five viable parties already in the snapshot"
	return result
end)

for _, boundary in { "claimed", "reserved", "recorded", "partial_assignment" } do
	case("worker-death-after-" .. boundary, function()
		local world = World.new(0.005)
		local first, second = world:worker("worker-A"), world:worker("worker-B")
		world:seed(5, 4)
		local partyUpdates = 0
		world.fault = function(operation)
			if operation.worker ~= "worker-A" then
				return nil
			end
			if operation.structure == "PartyById" and operation.kind == "UpdateAsync" then
				partyUpdates += 1
			end
			if
				(boundary == "claimed" and partyUpdates == 5 and operation.structure == "PartyById")
				or (boundary == "reserved" and operation.kind == "ReserveServerAsync")
				or (boundary == "recorded" and operation.structure == "MatchById" and operation.kind == "SetAsync")
				or (
					boundary == "partial_assignment"
					and operation.structure == "Arena"
					and operation.kind == "RemoveAsync"
				)
			then
				return "crash_after"
			end
			return nil
		end
		world:schedule(1000, function()
			first.service:Tick()
		end)
		for secondOffset = 11, 35, 2 do
			world:schedule(1000 + secondOffset, function()
				second.service:Tick()
			end)
		end
		world:run()
		local result = world:summary()
		assert(
			result.crashedWorkers == 1 and result.phases.Assigned == 5 and not result.phases.Claimed,
			"all parties must recover after one worker death"
		)
		assert(result.matchRecords == 1, "worker-death recovery must retain one match")
		result.outcome =
			"PASS: all five intact parties recover to one match; worker death abandons coroutine without releasing lease"
		return result
	end)
end

case("ambiguous-claim-write-retry", function()
	local world = World.new(0.005)
	local worker = world:worker("worker-A")
	world:seed(5, 4)
	local failed = false
	world.fault = function(operation)
		if not failed and operation.structure == "PartyById" and operation.kind == "UpdateAsync" then
			failed = true
			return "error_after"
		end
		return nil
	end
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local first = world:summary()
	assert(
		first.phases.Claimed == 1 and first.phases.Queued == 4 and first.matchRecords == 0,
		"ambiguous claim must remain pending until recovery"
	)
	world:schedule(1031, function()
		worker.service:Tick()
	end)
	world:schedule(1033, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.phases.Assigned == 5 and result.errors == 1,
		"all parties must recover from one ambiguous claim write"
	)
	result.afterFirstTick = first
	result.outcome =
		"PASS WITH RECOVERY DELAY: committed claim with lost response is held until expiry; no duplicate active assignment"
	return result
end)

case("reservation-four-errors-releases-claims", function()
	local world = World.new(0.005)
	local worker = world:worker("worker-A")
	world:seed(5, 4)
	world.fault = function(operation)
		return if operation.kind == "ReserveServerAsync" then "error_before" else nil
	end
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.errors == 4 and result.phases.Queued == 5 and result.matchRecords == 0,
		"reservation retry exhaustion must release every claim"
	)
	result.outcome =
		"PASS: retry exhaustion returns all parties to queue; four attempts and midpoint-jitter backoff counted"
	return result
end)

for _, size in { 1, 4 } do
	case("low-population-party" .. size, function()
		local world = World.new(0)
		local worker = world:worker("worker-A")
		world:seed(2, size)
		for _, record in world.maps.Arena do
			record.value.enqueuedAt = 1000
		end
		for _, record in world.maps.PartyById do
			record.value.queueTicket.enqueuedAt = 1000
		end
		for _, time in { 1000, 1008, 1016, 1024, 1030 } do
			world:schedule(time, function()
				worker.service:Tick()
			end)
		end
		world:run()
		local result = world:summary()
		assert(result.phases.Assigned == 2, "two parties must match once population expansion allows them")
		assert(
			world.notifications[1].at == (if size == 1 then 1030 else 1024),
			"population expansion must start at the intended threshold"
		)
		result.outcome = "PASS: two solos start at 30s oldest age; two four-player parties start at 24s oldest age"
		return result
	end)
end

case("stale-ticket-age-does-not-relax-young-viable-population", function()
	local world = World.new(0)
	local worker = world:worker("worker-A")
	world:seed(6, 1)
	for index = 1, 6 do
		local id = string.format("party-%04d", index)
		local enqueuedAt = if index <= 4 then 900 else 1000
		world.maps.PartyById[id].value.queueTicket.enqueuedAt = enqueuedAt
		world.maps.Arena[id].value.enqueuedAt = enqueuedAt
		world.maps.Arena[id].sortKey = enqueuedAt + index / 10000
		if index <= 4 then
			world.maps.PartyById[id].value.phase = "Lobby"
		end
	end
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local first = world:summary()
	assert(
		first.matchRecords == 0 and first.phases.Queued == 2 and not first.phases.Claimed,
		"young viable parties must be released when stale age was the only reason to lower the minimum"
	)
	assert(
		not first.operationCounts["TeleportService.ReserveServerAsync"],
		"insufficient viable population must not reserve a server"
	)
	world:schedule(1030, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(result.phases.Assigned == 2, "young parties must remain usable at their own 30-second threshold")
	result.afterFirstTick = first
	result.outcome =
		"PASS: four old stale tickets cannot use their age to send two fresh solos into an early underfilled match"
	return result
end)

case("remaining-capacity-preserves-parties-and-oldest-fit-order", function()
	local world = World.new(0)
	local worker = world:worker("worker-A")
	world:seed(7, 4)
	for index, size in { [5] = 3, [7] = 1 } do
		local id = string.format("party-%04d", index)
		local party = world.maps.PartyById[id].value
		while #party.members > size do
			table.remove(party.members)
		end
		party.queueTicket.partySize = size
		world.maps.Arena[id].value.partySize = size
	end
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(result.phases.Assigned == 6 and result.phases.Queued == 1, "whole fitting parties must fill the match")
	assert(
		not result.assignments["party-0006"] and result.assignments["party-0007"],
		"skip the four-player party that cannot fit the remaining slot"
	)
	local matchRecord = world.maps.MatchById["match-1"].value
	assert(
		#matchRecord.expectedUserIds == 20 and #matchRecord.parties == 6,
		"one full match must contain the exact intact player set"
	)
	assert(#world.maps.PartyById["party-0006"].value.members == 4, "waiting party must not be split")
	result.outcome = "PASS: 4+4+4+4+3+1 fills 20, preserving the skipped four-player party for a later match"
	return result
end)

case("understated-ticket-cannot-overfill-authoritative-match", function()
	local world = World.new(0)
	local worker = world:worker("worker-A")
	world:seed(21, 1)
	local first = world.maps.PartyById["party-0001"].value
	for member = 2, 4 do
		table.insert(first.members, { userId = 10 + member })
	end
	first.queueTicket.partySize = 4
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.phases.Assigned == 20 and not result.assignments["party-0001"],
		"mismatched ticket size must be rejected while viable tail still matches"
	)
	assert(
		#world.maps.MatchById["match-1"].value.expectedUserIds == 20,
		"authoritative members must never exceed capacity"
	)
	assert(first.phase == "Queued" and #first.members == 4, "mismatched party must remain intact")
	result.outcome =
		"PASS: a one-player queue ticket cannot admit its four-player authority record and overfill the match"
	return result
end)

case("unknown-match-read-failure-preserves-expired-claims-and-tickets", function()
	local world = World.new(0.005)
	local worker = world:worker("worker-A")
	world:seed(40, 1, function(party, index)
		if index <= 20 then
			party.phase = "Claimed"
			party.claim = { claimId = "unknown-match", expiresAt = 999 }
		end
	end)
	world.fault = function(operation)
		return if operation.structure == "MatchById" and operation.kind == "GetAsync" then "error_before" else nil
	end
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.errors > 0 and result.phases.Claimed == 20 and result.phases.Queued == 20,
		"a failed match lookup cannot establish that expired claims may be released"
	)
	assert(
		count(world.maps.Arena) == 40 and result.matchRecords == 0,
		"unknown match state must not erase tickets or publish a match"
	)
	assert(
		not result.operationCounts["TeleportService.ReserveServerAsync"],
		"deadline-limited failed scan must not reserve"
	)
	result.outcome =
		"PASS: failed match reads preserve unknown claims and valid queue tickets; scanning stops after its local deadline"
	return result
end)

case("slow-claim-scan-stops-and-releases-partial-match", function()
	local world = World.new(0.005)
	local worker = world:worker("worker-A")
	world:seed(10, 4)
	world.delay = function(operation)
		if
			operation.structure == "PartyById"
			and operation.kind == "UpdateAsync"
			and world.maps.PartyById[operation.key].value.phase == "Queued"
		then
			return 2
		end
		return 0.005
	end
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.phases.Queued == 10 and not result.phases.Claimed and result.matchRecords == 0,
		"partial claims must be released when the worker claim deadline is exhausted"
	)
	assert(
		result.operationCounts["PartyById.UpdateAsync"] == 9,
		"four successful claims plus one expired attempt plus four releases expected"
	)
	assert(
		not result.operationCounts["TeleportService.ReserveServerAsync"],
		"a deadline-expired scan cannot start reservation"
	)
	result.outcome =
		"PASS: fifth slow claim returns after local deadline, admits no new party, and releases the four matching partial claims"
	return result
end)

case("retry-transform-rechecks-presence-with-current-time", function()
	local world = World.new(0.005)
	local worker = world:worker("worker-A")
	world:seed(20, 1, function(party)
		party.leaseUntil = 1001
	end)
	local attempts = 0
	world.fault = function(operation)
		if operation.structure == "PartyById" and operation.kind == "UpdateAsync" and operation.key == "party-0001" then
			attempts += 1
			if attempts == 1 then
				return "error_before"
			end
		end
		return nil
	end
	world.delay = function(operation)
		if
			operation.structure == "PartyById"
			and operation.kind == "UpdateAsync"
			and operation.key == "party-0001"
			and attempts == 2
		then
			return 1.2
		end
		return 0.005
	end
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.errors == 1 and attempts == 2 and not result.phases.Claimed and not result.phases.Assigned,
		"retry must observe the presence lease that expired while the request yielded"
	)
	assert(
		result.matchRecords == 0 and count(world.maps.Arena) == 0,
		"expired presence cannot be revived by stale captured time"
	)
	result.outcome =
		"PASS: retryable claim transform reads current time and rejects presence that expired during its cloud wait"
	return result
end)

case("queue-range-error-does-not-claim-or-remove-parties", function()
	local world = World.new(0.005)
	local worker = world:worker("worker-A")
	world:seed(20, 1)
	world.fault = function(operation)
		return if operation.kind == "GetRangeAsync" then "error_before" else nil
	end
	world:schedule(1000, function()
		worker.service:Tick()
	end)
	world:run()
	local result = world:summary()
	assert(
		result.errors == 4 and result.phases.Queued == 20 and count(world.maps.Arena) == 20,
		"failed candidate reads must preserve every valid party and ticket"
	)
	assert(
		not result.operationCounts["PartyById.UpdateAsync"] and result.matchRecords == 0,
		"no candidate authority work is allowed without a successful snapshot"
	)
	result.outcome = "PASS: exhausted range-read retries leave valid queue tickets and party authority untouched"
	return result
end)

local git = process.exec("git", { "rev-parse", "HEAD" })
assert(git.ok, git.stderr)
local sourceHashes = {}
for _, path in files do
	sourceHashes[path] = serde.hash("sha256", fs.readFile(path))
end
local demandSensitivity = {}
for _, scenario in
	{
		{ label = "30k globally requeue every 10m", population = 30000, interval = 600, fraction = 1 },
		{ label = "30k globally requeue every 5m", population = 30000, interval = 300, fraction = 1 },
		{ label = "50k globally requeue every 10m", population = 50000, interval = 600, fraction = 1 },
		{ label = "50k globally requeue every 5m", population = 50000, interval = 300, fraction = 1 },
		{ label = "50k; 25% globally requeue every 5m", population = 50000, interval = 300, fraction = 0.25 },
	}
do
	for _, size in { 1, 4 } do
		for _, milliseconds in { 5, 20 } do
			local arrivals = scenario.population * scenario.fraction / scenario.interval
			local parties = 20 / size
			local serializedSeconds = (3 * parties + 5) * milliseconds / 1000
			local serviceRate = 20 / serializedSeconds
			local beforeBurst = math.max(0, (arrivals - serviceRate) * 600)
			local afterBurst = math.max(0, beforeBurst + (2 * arrivals - serviceRate) * 300)
			local afterRecovery = math.max(0, afterBurst + (arrivals - serviceRate) * 300)
			table.insert(demandSensitivity, {
				scenario = scenario.label,
				freshEntriesPerSecond = 0,
				partySize = size,
				injectedMillisecondsPerCall = milliseconds,
				arrivalsPerSecond = arrivals,
				idealPlayerAssignmentsPerSecond = serviceRate,
				stableSteadyState = serviceRate > arrivals,
				backlogAfterTenMinuteSteady = beforeBurst,
				backlogAfterFiveMinuteTwoTimesBurst = afterBurst,
				backlogAfterFiveMinuteRecovery = afterRecovery,
				burstDrainedWithinFiveMinutes = afterRecovery < 0.001,
				idealDrainSeconds = if serviceRate > arrivals then afterBurst / (serviceRate - arrivals) else nil,
				queueUnitsPerMinuteAtDemand = arrivals / 20 * 60 * (100 + 2 * parties),
			})
		end
	end
end
local evidence = {
	schemaVersion = 1,
	sourceRevision = string.gsub(git.stdout, "%s+$", ""),
	sourceHashes = sourceHashes,
	mode = "offline real-source methods; fake atomic MemoryStore, clock, reserve and notification sinks",
	place = "lobby source only; no running Studio or published place exercised",
	players = "synthetic party records, maximum 120 solo players / 420 players in four-player records; zero real clients",
	limits = {
		"Latency is an injected sensitivity input, not a measured Roblox service latency.",
		"MemoryStore units are a documented minimum, excluding server-side UpdateAsync callback retries and actual throttle behavior.",
		"No messaging delivery, PartyService local reconciliation, teleport arrival, presence heartbeat or published quota exercised.",
		"Reserve seam mirrors the current CloudRetry wrapper; does not allocate a reserved server.",
		"Ideal throughput excludes poll/backoff gaps, fresh enqueue, cache updates, notifications and scheduler overhead.",
		"Active assignment uniqueness refers to the authoritative party record; duplicate ready match records are separately reported.",
		"Demand sensitivity is a fluid arithmetic model with constant ideal service rate; it does not execute 30k/50k users or claim a p95 assignment time.",
	},
	cases = results,
	demandSensitivity = demandSensitivity,
}
fs.writeDir(output)
fs.writeFile(output .. "/population-and-capacity.json", serde.encode("json", evidence, true))
print("Matchmaking evidence written: " .. output .. "/population-and-capacity.json")
