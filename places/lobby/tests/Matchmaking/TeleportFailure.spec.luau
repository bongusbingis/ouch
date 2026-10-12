--!nonstrict

-- Exercises arena teleport failure handling: the party stays together and queue-able without cloud services.

local Modules = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Modules")
local PartyService = require(Modules:WaitForChild("Matchmaking"):WaitForChild("PartyService"))

local function fixture(phase, storeFails)
	local players = {}
	local first = { UserId = 10, Parent = players }
	local second = { UserId = 20, Parent = players }
	local record = {
		partyId = "party",
		schemaVersion = 3,
		revision = 1,
		leaderUserId = 10,
		phase = phase,
		matchId = "match",
		members = { { userId = 10 }, { userId = 20 } },
		createdAt = 1,
		updatedAt = 1,
		leaseUntil = math.huge,
	}
	local errors = {}
	local soloMoves = {}
	local repository = {}
	function repository:UpdateParty(_partyId, transform)
		if storeFails then
			return nil, "store_down"
		end
		local nextRecord = transform(record)
		if nextRecord then
			record = nextRecord
		end
		return nextRecord
	end
	local service = PartyService.new(repository, {}, {}, {}, {}, {}, { players = players })
	service.NotifyCommitted = function(self, nextRecord)
		self._cache[nextRecord.partyId] = nextRecord
	end
	service._sendError = function(_self, _player, reason)
		table.insert(errors, reason)
	end
	service._moveMemberToSoloParty = function(_self, player)
		table.insert(soloMoves, player.UserId)
	end
	service._localPartyByUser = { [10] = "party", [20] = "party" }
	service._cache.party = record
	return {
		service = service,
		first = first,
		second = second,
		errors = errors,
		soloMoves = soloMoves,
		record = function()
			return record
		end,
	}
end

return function()
	describe("Arena teleport failure", function()
		it("returns the whole party to the lobby instead of splitting it", function()
			local f = fixture("Teleporting")
			f.service:HandleTeleportFailure(f.first)
			expect(f.record().phase).to.equal("Lobby")
			expect(f.record().matchId).to.equal(nil)
			expect(#f.record().members).to.equal(2)
			expect(#f.soloMoves).to.equal(0)
		end)
		it("leaves later failures of the same match in the returned party", function()
			local f = fixture("Assigned")
			f.service:HandleTeleportFailure(f.first)
			f.service:HandleTeleportFailure(f.second)
			expect(f.record().phase).to.equal("Lobby")
			expect(#f.soloMoves).to.equal(0)
			expect(#f.errors).to.equal(2)
		end)
		it("ignores a stale failure from an earlier match", function()
			local f = fixture("Assigned")
			f.record().matchId = "newMatch"
			f.service._teleportMatchByUser[20] = "oldMatch"
			f.service:HandleTeleportFailure(f.second)
			expect(f.record().phase).to.equal("Assigned")
			expect(f.record().matchId).to.equal("newMatch")
			expect(#f.soloMoves).to.equal(0)
		end)
		it("falls back to a solo party only when the record cannot be updated", function()
			local f = fixture("Teleporting", true)
			f.service:HandleTeleportFailure(f.first)
			expect(f.soloMoves[1]).to.equal(10)
		end)
	end)
end
