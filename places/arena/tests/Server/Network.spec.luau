-- Description: In-place spec that every declared remote is materialized with the right class and that the rate-limiting and validation middleware wrappers behave and compose correctly.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local FakePlayer = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("FakePlayer"))

local EXPECTED_REMOTES = {
	EquipCosmetic = "RemoteFunction",
	OpenCrate = "RemoteFunction",
	CrateOpened = "RemoteEvent",
	StorePurchaseGranted = "RemoteEvent",
	ReportDeviceClass = "RemoteEvent",
	CombatFeed = "RemoteEvent",
	MatchSummary = "RemoteEvent",
	GetQuestState = "RemoteFunction",
	ClaimQuest = "RemoteFunction",
	QuestStateChanged = "RemoteEvent",
	DamageFeedback = "RemoteEvent",
	SubmitModeVote = "RemoteEvent",
	ArenaClientReady = "RemoteEvent",
	TeleportPresentationReady = "RemoteEvent",
	TeleportStatus = "RemoteEvent",
	RequestLobbyReturn = "RemoteEvent",
	SubmitCombatInput = "RemoteEvent",
	SetClientSetting = "RemoteEvent",
	SetClientSettingRequest = "RemoteFunction",
	OnboardingState = "RemoteEvent",
	OnboardingReady = "RemoteFunction",
	OnboardingAction = "RemoteEvent",
	OnboardingDebug = "RemoteEvent",
	CombatSimEvent = "UnreliableRemoteEvent",
	JumpPadImpulse = "UnreliableRemoteEvent",
}

local nextUserId = 400000
local function freshPlayer(): any
	nextUserId += 1
	return FakePlayer.new(nextUserId)
end

return function()
	local simulationIt = if RunService:IsRunning() then it else itSKIP

	describe("Network remotes", function()
		it("materializes every declared remote with its declared class", function()
			local folder = ReplicatedStorage:FindFirstChild("Remotes")
			expect(folder).to.be.ok()

			for name, className in EXPECTED_REMOTES do
				local remote = folder:FindFirstChild(name)
				expect(remote).to.be.ok()
				expect(remote.ClassName).to.equal(className)
			end
		end)

		it("registers handlers on declared remotes without erroring", function()
			Network.handle("GetQuestState", function()
				return nil
			end)
			Network.handle("ReportDeviceClass", function() end)
		end)
	end)

	describe("Network middleware", function()
		it("withRateLimit admits up to the limit per second and then rejects", function()
			local player = freshPlayer()
			local calls = 0
			local handler = Network.withRateLimit(3, function(_player)
				calls += 1
				return "ok"
			end)

			for _ = 1, 3 do
				expect(handler(player)).to.equal("ok")
			end
			local result, reason = handler(player)
			expect(result).never.to.be.ok()
			expect(reason).to.equal("rate_limited")
			expect(calls).to.equal(3)
		end)

		it("gives each rate-limited remote an independent budget", function()
			local player = freshPlayer()
			local chatty = Network.withRateLimit(1, function(_player)
				return "chatty"
			end, "ReportAnalyticsEvent")
			local guarded = Network.withRateLimit(1, function(_player)
				return "guarded"
			end, "OpenCrate")

			expect(chatty(player)).to.equal("chatty")
			expect((chatty(player))).never.to.be.ok()
			expect(guarded(player)).to.equal("guarded")
		end)

		it("applies known action budgets and shares unknown actions in the default bucket", function()
			local first = freshPlayer()
			local second = freshPlayer()
			local handler = Network.withActionRateLimits({
				default = { limit = 1 },
				JoinByCode = { limit = 1 },
				StartMatchmaking = { limit = 1 },
			}, function(_player, action)
				return action
			end, "PartyRequest")

			expect(handler(first, "JoinByCode")).to.equal("JoinByCode")
			local _, joinReason = handler(first, "JoinByCode")
			expect(joinReason).to.equal("rate_limited")
			-- A known action has its own bucket, including when another action is full.
			expect(handler(first, "StartMatchmaking")).to.equal("StartMatchmaking")
			-- Non-string and unknown actions share one bounded default bucket.
			expect(handler(first, "UnrecognizedAction")).to.equal("UnrecognizedAction")
			local _, malformedReason = handler(first, 42)
			expect(malformedReason).to.equal("rate_limited")
			-- The same known action has an independent budget per player.
			expect(handler(second, "JoinByCode")).to.equal("JoinByCode")
		end)

		simulationIt("uses a configured action window", function()
			local player = freshPlayer()
			local handler = Network.withActionRateLimits({
				default = { limit = 1, window = 0.05 },
			}, function(_player, action)
				return action
			end, "PartyRequest")

			expect(handler(player, "AnyAction")).to.equal("AnyAction")
			local _, reason = handler(player, "AnotherAction")
			expect(reason).to.equal("rate_limited")
			task.wait(0.06)
			expect(handler(player, 42)).to.equal(42)
		end)

		it("tracks rate limits per player", function()
			local first = freshPlayer()
			local second = freshPlayer()
			local handler = Network.withRateLimit(1, function(_player)
				return "ok"
			end)

			expect(handler(first)).to.equal("ok")
			expect(handler(second)).to.equal("ok")
			expect((handler(first))).never.to.be.ok()
			expect((handler(second))).never.to.be.ok()
		end)

		simulationIt("readmits after the one-second window elapses", function()
			local player = freshPlayer()
			local handler = Network.withRateLimit(1, function(_player)
				return "ok"
			end)

			expect(handler(player)).to.equal("ok")
			expect((handler(player))).never.to.be.ok()
			task.wait(1.05)
			expect(handler(player)).to.equal("ok")
		end)

		it("withValidation rejects before the handler runs", function()
			local player = freshPlayer()
			local calls = 0
			local handler = Network.withValidation(function(_player, value)
				return typeof(value) == "string", "string_required"
			end, function(_player, value)
				calls += 1
				return value
			end)

			expect(handler(player, "fine")).to.equal("fine")
			local result, reason = handler(player, 42)
			expect(result).never.to.be.ok()
			expect(reason).to.equal("invalid_args")
			expect(calls).to.equal(1)
		end)

		it("invalid packets consume the budget before further validation", function()
			local player = freshPlayer()
			local validated = 0
			local composed = Network.withRateLimit(
				1,
				Network.withValidation(function(_player, value)
					validated += 1
					return typeof(value) == "string", "string_required"
				end, function(_player, value)
					return value
				end)
			)

			local result, reason = composed(player, 42)
			expect(result).never.to.be.ok()
			expect(reason).to.equal("invalid_args")

			local accepted, deniedReason = composed(player, "fine")
			expect(accepted).to.equal(nil)
			expect(deniedReason).to.equal("rate_limited")
			expect(validated).to.equal(1)
		end)

		it("runs action limiting after validation", function()
			local player = freshPlayer()
			local actions = 0
			local composed = Network.withRateLimit(
				3,
				Network.withValidation(
					function(_player, action)
						return typeof(action) == "string"
					end,
					Network.withActionRateLimits({
						default = { limit = 1 },
					}, function(_player, action)
						actions += 1
						return action
					end, "PartyRequest"),
					"PartyRequest"
				)
			)

			local _, invalidReason = composed(player, 42)
			expect(invalidReason).to.equal("invalid_args")
			expect(composed(player, "valid")).to.equal("valid")
			local _, actionReason = composed(player, "second")
			expect(actionReason).to.equal("rate_limited")
			expect(actions).to.equal(1)
		end)
	end)
end
