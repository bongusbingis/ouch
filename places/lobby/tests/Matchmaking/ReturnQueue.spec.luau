--!nonstrict

-- Exercises return reconciliation and the existing queue transaction without cloud services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Modules")
local PartyService = require(Modules:WaitForChild("Matchmaking"):WaitForChild("PartyService"))
local PartyModel = require(Modules.Matchmaking.PartyModel)
local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Protocol"))
local QueuePolicy = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Matchmaking")
		:WaitForChild("ReturnQueuePolicy")
)

local function fixture()
	local players = {}
	local leader = { UserId = 10, Parent = players }
	local member = { UserId = 20, Parent = players }
	function players:GetPlayerByUserId(userId)
		return if userId == 10 then leader else if userId == 20 then member else nil
	end
	local record = {
		partyId = "party",
		schemaVersion = 2,
		revision = 1,
		leaderUserId = 10,
		phase = "Teleporting",
		matchId = "match",
		members = { { userId = 10 }, { userId = 20 } },
		createdAt = 1,
		updatedAt = 1,
		leaseUntil = math.huge,
	}
	local queued = 0
	local errors = {}
	local enqueuesSucceed = true
	local banned = false
	local repository = {}
	function repository:GetParty()
		return record
	end
	function repository:UpdateParty(_partyId, transform)
		local nextRecord = transform(record)
		if nextRecord then
			record = nextRecord
		end
		return nextRecord
	end
	local service = PartyService.new(repository, {
		Enqueue = function()
			queued += 1
			return enqueuesSucceed
		end,
		Remove = function() end,
	}, {}, {}, {}, {
		HasBannedMember = function()
			return banned
		end,
	}, { players = players })
	service.NotifyCommitted = function(self, nextRecord)
		self._cache[nextRecord.partyId] = nextRecord
	end
	service._reportFunnel = function() end
	service._reportEvent = function() end
	service._sendError = function(_self, _player, reason)
		table.insert(errors, reason)
	end
	service._localPartyByUser = { [10] = "party", [20] = "party" }
	service._localPlayersByParty = { party = { [10] = leader } }
	local payload = {
		partyId = "party",
		matchId = "match",
		memberUserIds = { 10, 20 },
		returnMode = "Party",
		queueOnArrival = true,
	}
	local restored = service:_restoreReturningParty(leader, payload)
	service._cache.party = restored
	return {
		service = service,
		leader = leader,
		member = member,
		payload = payload,
		errors = errors,
		record = function()
			return record
		end,
		queued = function()
			return queued
		end,
		arrive = function()
			service._localPlayersByParty.party[20] = member
		end,
		failEnqueue = function()
			enqueuesSucceed = false
		end,
		ban = function()
			banned = true
		end,
	}
end

return function()
	describe("Return queue handoff", function()
		it("regroups the full party, then enqueues exactly once", function()
			local f = fixture()
			f.service:_queueReturningParties()
			expect(f.queued()).to.equal(0)
			f.arrive()
			f.service:_queueReturningParties()
			expect(f.queued()).to.equal(1)
			expect(f.record().phase).to.equal("Queued")
			expect(f.record().returnQueue).to.equal(nil)
			f.service:_queueReturningParties()
			expect(f.queued()).to.equal(1)
		end)
		it("allows the leader to cancel regrouping without a late arrival re-arming it", function()
			local f = fixture()
			expect(f.service:HandleRequest(f.member, Protocol.Actions.CancelMatchmaking).ok).to.equal(false)
			expect(f.service:HandleRequest(f.leader, Protocol.Actions.CancelMatchmaking).ok).to.equal(true)
			f.arrive()
			f.service:_restoreReturningParty(f.member, f.payload)
			f.service:_queueReturningParties()
			expect(f.queued()).to.equal(0)
			expect(f.record().returnQueue).to.equal(nil)
		end)
		it("expires incomplete arrivals with a visible error and a usable lobby", function()
			local f = fixture()
			f.record().returnQueue.expiresAt = 0
			f.service:_queueReturningParties()
			expect(f.queued()).to.equal(0)
			expect(f.record().phase).to.equal("Lobby")
			expect(f.record().returnQueue).to.equal(nil)
			expect(#f.errors > 0).to.equal(true)
		end)
		it("runs the existing ban check before a return can enter the queue", function()
			local f = fixture()
			f.arrive()
			f.ban()
			f.service:_queueReturningParties()
			expect(f.queued()).to.equal(0)
			expect(f.record().returnQueue).to.equal(nil)
			expect(f.errors[1]).to.equal(Protocol.Errors.Banned)
		end)
		it("rolls back a failed enqueue without repeated automatic attempts", function()
			local f = fixture()
			f.arrive()
			f.failEnqueue()
			f.service:_queueReturningParties()
			expect(f.record().phase).to.equal("Lobby")
			expect(f.record().returnQueue).to.equal(nil)
			f.service:_queueReturningParties()
			expect(f.queued()).to.equal(1)
			expect(#f.errors > 0).to.equal(true)
		end)
		it("cancels pending handoff on membership changes and does not alias its roster", function()
			local f = fixture()
			local copy = PartyModel.clone(f.record())
			copy.returnQueue.memberUserIds[1] = 30
			expect(f.record().returnQueue.memberUserIds[1]).to.equal(10)
			PartyModel.removeMember(copy, 10)
			expect(copy.leaderUserId).to.equal(20)
			expect(copy.returnQueue).to.equal(nil)
		end)
		it("preserves consumed intent on an ordinary lobby transition", function()
			local f = fixture()
			PartyModel.returnToLobby(f.record())
			QueuePolicy.arm(f.record(), f.payload, 1, 20)
			expect(f.record().returnQueue).to.equal(nil)
		end)
	end)
end
