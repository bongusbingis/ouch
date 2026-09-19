-- Bounded actual-service fault runner. Platform transport/persistence are fixtures.
--!nonstrict
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local task = require("@lune/task")
local serde = require("@lune/serde")
local Loader = require("./loader")

local evidence = ".review/production/2026-09-09-batch1/r05-r06"
fs.writeDir(evidence)
local map = process.exec("rojo", { "sourcemap", "tests.project.json", "-o", evidence .. "/sourcemap.json" })
assert(map.ok, map.stderr)
local root, pure = Loader.build(evidence .. "/sourcemap.json")
local economy = root.ReplicatedStorage.Shared.Game.Economy
local config = root.ReplicatedStorage.Config
local Proxy = pure(root.ReplicatedStorage.Shared.Game.Data.WriteThroughProxy)
local realRolls = pure(economy.CrateRolls)
local deps = {
	Cosmetics = pure(config.Cosmetics.Cosmetics),
	Crates = pure(config.Economy.Crates),
	Shop = pure(config.Economy.Shop),
	Products = pure(config.Economy.Products),
	Bundles = pure(config.Economy.Bundles),
	Data = pure(config.Progression.Data),
	Analytics = pure(config.Infra.Analytics),
	Debug = {},
	FeaturedRotation = pure(economy.FeaturedRotation),
	CrateBatch = pure(economy.CrateBatch),
	ShopRotation = pure(economy.ShopRotation),
	DirectPurchase = pure(economy.DirectPurchase),
	CosmeticsLogic = pure(economy.CosmeticsLogic),
	ReceiptHistory = pure(economy.ReceiptHistory),
	WriteThroughProxy = Proxy,
	MatchAwards = {},
	Env = {},
	replica = {
		Token = function()
			return {}
		end,
	},
	profilestore = {
		New = function()
			return {}
		end,
	},
	promise = {},
	RewardService = {},
	GamePasses = pure(config.Economy.GamePasses),
	Seasons = pure(config.Progression.Seasons),
	BattlePassLogic = pure(root.ReplicatedStorage.Shared.Game.Progression.BattlePassLogic),
	Listeners = pure(root.ReplicatedStorage.Shared.Game.Util.Listeners),
	ClientRequests = { TimeoutSeconds = 0.03 },
	Emotes = pure(config.Cosmetics.Emotes),
	FeaturedRotation = pure(root.ReplicatedStorage.Shared.Game.Economy.FeaturedRotation),
	StarterOffer = pure(root.ReplicatedStorage.Shared.Game.Economy.StarterOffer),
	Boosts = pure(root.ReplicatedStorage.Shared.Game.Economy.Boosts),
}
local nodes = {}
local function node(name)
	if nodes[name] then
		return nodes[name]
	end
	local result = setmetatable({ Name = name }, {
		__index = function(_, key)
			if key == "WaitForChild" then
				return function(_, child)
					return node(child)
				end
			end
			return node(key)
		end,
	})
	nodes[name] = result
	return result
end
local function loadService(name, path)
	return luau.load(fs.readFile(path or ("src/server/Modules/" .. name .. ".luau")), {
		debugName = name,
		injectGlobals = true,
		environment = {
			game = {
				GetService = function(_, name)
					return node(name)
				end,
			},
			script = node(name),
			require = function(target)
				assert(deps[target.Name] ~= nil, "Unmapped dependency: " .. target.Name)
				return deps[target.Name]
			end,
			Random = {
				new = function()
					return {
						NextNumber = function()
							return 0
						end,
						NextInteger = function()
							return 1
						end,
					}
				end,
			},
			Enum = { ProductPurchaseDecision = { PurchaseGranted = "granted", NotProcessedYet = "pending" } },
			task = task,
		},
	})()
end
local sequence = 0
node("HttpService").GenerateGUID = function()
	sequence += 1
	return "open-" .. sequence
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			local entry = { callback = callback, active = true }
			table.insert(callbacks, entry)
			return {
				Disconnect = function()
					entry.active = false
				end,
			}
		end,
		Fire = function(_, player)
			for _, entry in callbacks do
				if entry.active then
					entry.callback(player)
				end
			end
		end,
	}
end
local player = { UserId = -905006, Name = "FaultFixture" }
local removing = signal()
node("Players").PlayerRemoving = removing
node("Players").GetPlayerByUserId = function()
	return player
end
node("RunService").IsStudio = function()
	return false
end
node("RunService").IsServer = function()
	return true
end
deps.AnalyticsService = setmetatable({}, {
	__index = function()
		return function() end
	end,
})
deps.Network = { fire = function() end, handleProtected = function() end }
deps.CrateRolls = {
	roll = function(...)
		return realRolls.roll(...)
	end,
}
deps.PaidRandomPolicyService = loadService("PaidRandomPolicyService")
deps.EntitlementService = loadService("EntitlementService")
deps.PlayerData = loadService("PlayerData")
deps.CosmeticsService = loadService("CosmeticsService")
deps.CrateService = loadService("CrateService")
deps.ShopService = loadService("ShopService")
deps.MonetizationService = loadService("MonetizationService")
deps.ClientRequest = loadService("ClientRequest", "src/shared/Game/Data/ClientRequest.luau")
local client = loadService("ShopClient", "src/shared/Game/Economy/ShopClient.luau")

local raw, profile, replica, saved, now, policyCalls, policyResult, policyLookup, failWrite, rollCalls
local function fresh()
	client.stop()
	deps.PaidRandomPolicyService._resetForTest()
	deps.MonetizationService._resetForTest()
	deps.ShopService._resetForTest()
	raw = Proxy.snapshot(deps.Data.Template)
	raw.Bonks = 10000
	saved = {}
	now, policyCalls, rollCalls = 0, 0, 0
	policyResult = { ArePaidRandomItemsRestricted = false }
	policyLookup, failWrite = nil, nil
	deps.CrateRolls.roll = function(...)
		rollCalls += 1
		return realRolls.roll(...)
	end
	deps.Network.fire = function() end
	replica = {
		Data = raw,
		Set = function(_, path, value)
			if failWrite then
				failWrite(path)
			end
			local target = raw
			for i = 1, #path - 1 do
				target = target[path[i]]
			end
			target[path[#path]] = value
		end,
		SetValues = function(_, _, values)
			for key, value in values do
				raw[key] = value
			end
			if failWrite then
				failWrite({ "SetValues" })
			end
		end,
	}
	profile = {
		Data = raw,
		LastSavedData = saved,
		IsActive = function()
			return true
		end,
		Save = function(self)
			self.LastSavedData = Proxy.snapshot(raw)
		end,
	}
	deps.PlayerData._profiles[player.UserId] = { Profile = profile, Replica = replica, Data = Proxy.wrap(raw, replica) }
	deps.PaidRandomPolicyService.start({
		players = { PlayerRemoving = removing },
		policyService = {
			GetPolicyInfoForPlayerAsync = function()
				policyCalls += 1
				if policyLookup then
					return policyLookup()
				end
				return policyResult
			end,
		},
		clock = function()
			return now
		end,
		products = deps.Products,
	})
end
local cases = {}
local function check(name, callback)
	fresh()
	local ok, err = pcall(callback)
	table.insert(
		cases,
		{ case = name, outcome = if ok then "PASS" else "FAIL", detail = if ok then nil else tostring(err) }
	)
	print((if ok then "PASS " else "FAIL ") .. name .. (if ok then "" else ": " .. tostring(err)))
end
local function eq(actual, expected, label)
	assert(
		actual == expected,
		(label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)
	)
end
local crateId = "DodgeballCrate"
local function startClient(options)
	options = options or {}
	local events = {}
	local market = { PromptProductPurchaseFinished = signal(), PromptGamePassPurchaseFinished = signal() }
	deps.Network.on = function(name, callback)
		events[name] = callback
		return {
			Disconnect = function()
				events[name] = nil
			end,
		}
	end
	deps.Network.call = options.call
		or function(name, ...)
			if name == "OpenCrate" then
				return deps.CrateService.openWithBonks(player, ...)
			end
			if name == "GetShopState" then
				return deps.ShopService.stateFor(player)
			end
			return {}
		end
	deps.Network.fire = function(name, target, payload)
		assert(target == player, "Network.fire is server-only and requires the target player")
		if not options.dropReveal and events[name] then
			events[name](payload)
		end
	end
	local clientNetwork = {
		call = deps.Network.call,
		on = deps.Network.on,
		fire = function()
			error("Network.fire is server-only; clients must use fireServer")
		end,
		fireServer = function(name, sequence)
			eq(name, "AcknowledgeBonksCrate")
			deps.CrateService.acknowledgeBonksOpen(player, sequence)
		end,
	}
	client.start({ DeferMarketplaceData = true, Network = clientNetwork, Marketplace = market, Player = player })
	local state = deps.ShopService.stateFor(player)
	if options.legacy then
		state.bonksOpen = nil
	end
	events.ShopStateChanged(state)
	return events
end
check("second roll exception leaves wallet ownership and pity unchanged", function()
	local before = serde.encode("json", raw)
	deps.CrateRolls.roll = function(...)
		rollCalls += 1
		if rollCalls == 2 then
			error("injected second-roll failure")
		end
		return realRolls.roll(...)
	end
	local result, reason = deps.CrateService.openWithBonks(player, crateId, 5)
	eq(result, nil)
	eq(reason, "crate_roll_failed")
	assert(serde.encode("json", raw) == before, "rejected batch changed profile ownership/pity/wallet")
end)
check("malformed policy cannot permit a Bonks open", function()
	policyResult = {}
	local result, reason = deps.CrateService.openWithBonks(player, crateId)
	eq(result, nil)
	eq(reason, "policy_unavailable")
	eq(raw.Bonks, 10000)
	eq(rollCalls, 0)
end)
check("catalogue visibility cannot bypass historical paid balances", function()
	deps.PaidRandomPolicyService._resetForTest()
	deps.PaidRandomPolicyService.start({
		players = { PlayerRemoving = removing },
		products = { Catalog = {} },
		policyService = {
			GetPolicyInfoForPlayerAsync = function()
				return { ArePaidRandomItemsRestricted = true }
			end,
		},
	})
	local allowed, reason = deps.PaidRandomPolicyService.canReceivePaidRandom(player)
	eq(allowed, false)
	eq(reason, "paid_random_restricted")
end)
check("failed policy retries are bounded and retry after cooldown", function()
	policyLookup = function()
		error("injected lookup failure")
	end
	for _ = 1, 10 do
		deps.PaidRandomPolicyService.canReceivePaidRandom(player)
	end
	eq(policyCalls, 1)
	now = 6
	deps.PaidRandomPolicyService.canReceivePaidRandom(player)
	eq(policyCalls, 2)
end)
check("concurrent policy request stays unavailable with one lookup", function()
	local nested = false
	policyLookup = function()
		if nested then
			return { ArePaidRandomItemsRestricted = false }
		end
		nested = true
		local allowed, reason = deps.PaidRandomPolicyService.canReceivePaidRandom(player)
		eq(allowed, false)
		eq(reason, "policy_unavailable")
		return { ArePaidRandomItemsRestricted = false }
	end
	eq(deps.PaidRandomPolicyService.canReceivePaidRandom(player), true)
	eq(policyCalls, 1)
end)
check("profile replacement while policy yields cannot charge replacement profile", function()
	policyLookup = function()
		deps.PlayerData._profiles[player.UserId] = { Data = Proxy.snapshot(raw) }
		return { ArePaidRandomItemsRestricted = false }
	end
	local result, reason = deps.CrateService.openWithBonks(player, crateId)
	eq(result, nil)
	eq(reason, "no_profile")
	eq(rollCalls, 0)
end)
check("completed batch charges full price and resolves internal duplicates", function()
	local result = deps.CrateService.openWithBonks(player, crateId, 5)
	eq(result.count, 5)
	local refund = 0
	for _, entry in result.results do
		refund += entry.bonksRefund
	end
	eq(raw.Bonks, 10000 - deps.CrateService.priceFor(crateId) * 5 + refund)
	eq(result.results[1].isDupe, false)
	eq(result.results[2].isDupe, true)
end)
check("replication and reveal failures keep the complete charge and reward", function()
	failWrite = function()
		error("injected replication failure")
	end
	deps.Network.fire = function()
		error("injected reveal transport failure")
	end
	local result = deps.CrateService.openWithBonks(player, crateId)
	eq(result.count, 1)
	eq(raw.Bonks, 10000 - deps.CrateService.priceFor(crateId))
	eq(raw.Cosmetics.Owned[result.results[1].itemId], true)
end)
check("inactive profile cannot commit a crate", function()
	profile.IsActive = function()
		return false
	end
	local result = deps.CrateService.openWithBonks(player, crateId)
	eq(result, nil)
	eq(raw.Bonks, 10000)
	eq(next(raw.Cosmetics.Owned), nil)
end)
check("removed player cannot repopulate a completed policy lookup", function()
	policyLookup = function()
		removing:Fire(player)
		return { ArePaidRandomItemsRestricted = false }
	end
	local allowed, reason = deps.PaidRandomPolicyService.canReceivePaidRandom(player)
	eq(allowed, false)
	eq(reason, "policy_unavailable")
	policyLookup = nil
	policyResult = { ArePaidRandomItemsRestricted = true }
	eq(deps.PaidRandomPolicyService.canReceivePaidRandom(player), false)
	eq(policyCalls, 2)
end)
check("actual ShopService exposes unavailable while deterministic offers remain", function()
	policyResult = {}
	deps.ShopService.start({ sweepSeconds = 0 })
	local state = deps.ShopService.stateFor(player)
	eq(state.paidRandomAllowed, false)
	eq(state.paidRandomReason, "policy_unavailable")
	assert(#state.offers > 0, "deterministic offers disappeared")
end)
local function receiptSetup(id)
	local marketplace = {}
	deps.MonetizationService.start({
		marketplace = marketplace,
		network = deps.Network,
		analyticsService = deps.AnalyticsService,
		products = { ById = { [3709429401] = deps.Products.ById[3709429401] } },
	})
	return marketplace, { PlayerId = player.UserId, ProductId = 3709429401, PurchaseId = id }
end
check("receipt journal write failure retries identical committed roll", function()
	local marketplace, receipt = receiptSetup("journal-failure")
	failWrite = function(path)
		if path[1] == "ReceiptWork" and path[#path] == "Payload" then
			error("injected journal write failure")
		end
	end
	eq(marketplace.ProcessReceipt(receipt), "pending")
	failWrite = nil
	eq(marketplace.ProcessReceipt(receipt), "granted")
	eq(rollCalls, 1)
	eq(raw.Bonks, 10000, "no duplicate refund on receipt replay")
end)
check("restricted receipt retains existing 500 Bonks fallback once", function()
	policyResult = { ArePaidRandomItemsRestricted = true }
	local marketplace, receipt = receiptSetup("restricted")
	eq(marketplace.ProcessReceipt(receipt), "granted")
	eq(marketplace.ProcessReceipt(receipt), "granted")
	eq(raw.Bonks, 10500)
	eq(rollCalls, 0)
end)
check("unavailable receipt remains pending without grant", function()
	policyLookup = function()
		error("injected unavailable")
	end
	local marketplace, receipt = receiptSetup("unavailable")
	eq(marketplace.ProcessReceipt(receipt), "pending")
	eq(raw.Bonks, 10000)
	eq(rollCalls, 0)
end)
check("ambiguous committed save retries from saved snapshot without reroll", function()
	local marketplace, receipt = receiptSetup("ambiguous-save")
	profile.Save = function(self)
		self.LastSavedData = Proxy.snapshot(raw)
		error("injected error after save committed")
	end
	eq(marketplace.ProcessReceipt(receipt), "pending")
	local priorSaved = profile.LastSavedData
	eq(priorSaved.ReceiptWork[receipt.PurchaseId].Payload.kind, "Crate")
	-- A new profile object represents an earlier-server saved completion.
	raw = Proxy.snapshot(priorSaved)
	profile.Data, replica.Data = raw, raw
	deps.PlayerData._profiles[player.UserId].Data = Proxy.wrap(raw, replica)
	eq(marketplace.ProcessReceipt(receipt), "granted")
	eq(rollCalls, 1)
	eq(raw.Bonks, 10000)
end)
check("eighty completed receipts preserve old tombstones and bounded detail", function()
	local marketplace, receipt = receiptSetup("history-1")
	for index = 1, 80 do
		receipt.PurchaseId = string.format("history-%03d", index)
		eq(marketplace.ProcessReceipt(receipt), "granted")
	end
	local balance = raw.Bonks
	local count, details, tombstone = 0, 0, nil
	for key, record in raw.Receipts do
		count += 1
		if type(record) == "table" then
			details += 1
		else
			tombstone = key
		end
	end
	eq(count, 80)
	eq(details, 64)
	assert(tombstone ~= nil, "old receipt tombstone missing")
	receipt.PurchaseId = tombstone
	eq(marketplace.ProcessReceipt(receipt), "granted")
	eq(raw.Bonks, balance)
	eq(rollCalls, 80)
	print("80-receipt fixture JSON bytes: " .. #serde.encode("json", raw.Receipts))
end)
check("sixty-four pending receipts block new work but let existing work drain", function()
	for index = 1, 64 do
		raw.ReceiptWork["pending-" .. index] = { Items = {} }
	end
	local marketplace, receipt = receiptSetup("new-over-cap")
	eq(marketplace.ProcessReceipt(receipt), "pending")
	eq(rollCalls, 0)
	receipt.PurchaseId = "pending-1"
	eq(marketplace.ProcessReceipt(receipt), "granted")
	eq(rollCalls, 1)
	eq(raw.ReceiptWork["pending-1"], nil)
	receipt.PurchaseId = "new-over-cap"
	eq(marketplace.ProcessReceipt(receipt), "granted")
	eq(rollCalls, 2)
end)

check("Bonks retry replays exactly once after both response and reveal are lost", function()
	local calls, firstSequence = 0, nil
	startClient({
		dropReveal = true,
		call = function(name, ...)
			if name ~= "OpenCrate" then
				return {}
			end
			calls += 1
			local args = table.pack(...)
			firstSequence = firstSequence or args[3]
			eq(args[3], firstSequence, "retry identity")
			local result, reason = deps.CrateService.openWithBonks(player, ...)
			if calls == 1 then
				error("injected response lost after server commit")
			end
			return result, reason
		end,
	})
	local price = deps.CrateService.priceFor(crateId)
	eq(client.openCrate("crate", crateId, 1, price), true)
	eq(calls, 2)
	eq(rollCalls, 1)
	eq(raw.Bonks, 10000 - price)
	eq(client.snapshot().reveal.sequence, 1)
	eq(client.snapshot().bonksRecovery, nil)
end)
check("manual recovery keeps one intent after a lost response and throttled retry", function()
	local calls, dropping = 0, true
	startClient({
		dropReveal = true,
		call = function(name, ...)
			if name ~= "OpenCrate" then
				return {}
			end
			calls += 1
			local args = table.pack(...)
			eq(args[3], 1)
			if calls == 2 then
				return nil, "rate_limited"
			end
			local result, reason = deps.CrateService.openWithBonks(player, ...)
			if dropping then
				error("injected response loss")
			end
			return result, reason
		end,
	})
	local price = deps.CrateService.priceFor(crateId)
	local ok, reason = client.openCrate("crate", crateId, 1, price)
	eq(ok, false)
	eq(reason, "crate_recovery_required")
	eq(calls, 2)
	eq(rollCalls, 1)
	eq(client.snapshot().bonksRecovery.sequence, 1)
	local another, why = client.openCrate("other", "HammerCrate", 5, 500)
	eq(another, false)
	eq(why, "crate_recovery_required")
	eq(calls, 2, "no second intent sent")
	dropping = false
	eq(client.retryCrateOpen(), true)
	eq(calls, 3)
	eq(rollCalls, 1)
	eq(raw.Bonks, 10000 - price)
end)
check("a reveal received before response timeout completes without a false failure", function()
	local calls = 0
	startClient({
		call = function(name, ...)
			if name ~= "OpenCrate" then
				return {}
			end
			calls += 1
			local result = deps.CrateService.openWithBonks(player, ...)
			task.wait(0.2)
			return result
		end,
	})
	eq(client.openCrate("crate", crateId, 1, deps.CrateService.priceFor(crateId)), true)
	eq(calls, 1)
	eq(rollCalls, 1)
	eq(client.snapshot().pending["Crate:" .. crateId], nil)
end)
check("saved rejoin recovers unrevealed Bonks result and closing acknowledges exact sequence", function()
	local price = deps.CrateService.priceFor(crateId)
	local first = deps.CrateService.openWithBonks(player, crateId, 1, 1, price)
	profile:Save()
	raw = Proxy.snapshot(profile.LastSavedData)
	profile.Data, replica.Data = raw, raw
	deps.PlayerData._profiles[player.UserId].Data = Proxy.wrap(raw, replica)
	startClient()
	eq(client.snapshot().reveal.openId, first.openId)
	eq(rollCalls, 1)
	client.clearReveal()
	eq(raw.Crates.LastBonksOpen.revealed, true)
	eq(client.openCrate("again", crateId, 1, price), true)
	eq(raw.Crates.LastBonksOpen.sequence, 2)
	eq(rollCalls, 2)
	deps.CrateService.acknowledgeBonksOpen(player, 1)
	eq(raw.Crates.LastBonksOpen.revealed, false, "late acknowledgement cannot hide newer result")
	client.clearReveal()
	client.stop()
	startClient()
	eq(client.snapshot().reveal, nil)
end)
check("legacy server capability never receives a recoverable Bonks purchase", function()
	local calls = 0
	startClient({
		legacy = true,
		call = function()
			calls += 1
		end,
	})
	local ok, reason = client.openCrate("crate", crateId, 1, 500)
	eq(ok, false)
	eq(reason, "crate_recovery_unavailable")
	eq(calls, 0)
	eq(rollCalls, 0)
end)
check("identity mismatches stale sequences gaps and changed quotes cannot charge", function()
	local price = deps.CrateService.priceFor(crateId)
	deps.CrateService.openWithBonks(player, crateId, 1, 1, price)
	local balance = raw.Bonks
	local result, reason = deps.CrateService.openWithBonks(player, crateId, 5, 1, price)
	eq(result, nil)
	eq(reason, "crate_request_mismatch")
	result, reason = deps.CrateService.openWithBonks(player, crateId, 1, 3, price)
	eq(reason, "crate_request_gap")
	result, reason = deps.CrateService.openWithBonks(player, crateId, 1, 2, price + 1)
	eq(reason, "crate_price_changed")
	eq(raw.Bonks, balance)
	eq(rollCalls, 1)
	deps.CrateService.openWithBonks(player, crateId, 1, 2, price)
	balance = raw.Bonks
	result, reason = deps.CrateService.openWithBonks(player, crateId, 1, 1, price)
	eq(reason, "crate_request_stale")
	eq(raw.Bonks, balance)
	eq(rollCalls, 2)
end)
check("concurrent Bonks intents cannot roll while eligibility is in flight", function()
	local price = deps.CrateService.priceFor(crateId)
	policyLookup = function()
		local result, reason = deps.CrateService.openWithBonks(player, crateId, 1, 1, price)
		eq(result, nil)
		eq(reason, "crate_processing")
		result, reason = deps.CrateService.openWithBonks(player, "HammerCrate", 5, 1, 500)
		eq(result, nil)
		eq(reason, "crate_processing")
		return { ArePaidRandomItemsRestricted = false }
	end
	local result = deps.CrateService.openWithBonks(player, crateId, 1, 1, price)
	eq(result.sequence, 1)
	eq(rollCalls, 1)
end)
client.stop()

local failed = 0
for _, case in cases do
	if case.outcome == "FAIL" then
		failed += 1
	end
end
print(
	string.format(
		"%d cases; %d failed. Actual service source; mocked platform persistence, replication, policy and transport.",
		#cases,
		failed
	)
)
local suffix = process.args[1] or "latest"
assert(string.match(suffix, "^[%w_-]+$"), "invalid evidence suffix")
fs.writeFile(
	evidence .. "/" .. suffix .. ".json",
	serde.encode("json", {
		mode = "headless actual-service source with injected platform boundaries",
		device = "none",
		players = 1,
		network = "fixture",
		cases = cases,
		failed = failed,
	}, true)
)
process.exit(if failed == 0 then 0 else 1)
