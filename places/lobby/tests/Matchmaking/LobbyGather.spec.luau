--!nonstrict

local Modules = game:GetService("ServerScriptService").Server.Modules.Matchmaking
local Coordinator = require(Modules.LobbyGatherCoordinator)
local PartyService = require(Modules.PartyService)
local Protocol = require(game:GetService("ReplicatedStorage").Shared.Matchmaking.Protocol)

local function fixture()
	local f = { calls = 0, indexed = 0, players = {}, attached = true, arena = false }
	f.party = {
		partyId = "party",
		leaderUserId = 10,
		phase = "Lobby",
		revision = 1,
		members = { { userId = 10 }, { userId = 20 } },
	}
	f.presence = { partyId = "party", jobId = "leader-server", placeId = 123, publicServer = true, refreshedAt = 1000 }
	f.joinData = {
		SourcePlaceId = 123,
		SourceGameId = 456,
		TeleportData = { lobbyGatherVersion = 1, partyId = "party", targetJobId = "leader-server" },
	}
	f.player = {
		UserId = 20,
		Parent = f.players,
		GetJoinData = function()
			return f.joinData
		end,
	}
	f.repository = {
		GetParty = function()
			if f.onRead then
				f.onRead()
			end
			return f.party, f.partyError
		end,
		GetUserPresence = function()
			return f.presence, f.presenceError
		end,
		SetUserParty = function()
			f.indexed += 1
			return not f.indexError, f.indexError
		end,
	}
	f.teleport = {
		TeleportInitFailed = {
			Connect = function(_self, callback)
				f.failure = callback
				return {
					Disconnect = function()
						f.disconnected = true
					end,
				}
			end,
		},
		TeleportAsync = function(_self, placeId, players, options)
			f.calls += 1
			f.placeId = placeId
			f.target = options.ServerInstanceId
			f.data = options:GetTeleportData()
			f.teleportedPlayer = players[1]
			if f.throw then
				error("server unavailable")
			end
		end,
	}
	f.coordinator = Coordinator.new(f.repository, {
		players = f.players,
		teleportService = f.teleport,
		placeId = 123,
		gameId = 456,
		jobId = "source-server",
		enabled = true,
		now = function()
			return 1000
		end,
	})
	f.consider = function()
		f.coordinator:Consider(f.player, "party", function()
			return f.attached
		end, function()
			return f.arena
		end)
	end
	f.restore = function()
		return f.coordinator:RestoreArrival(f.player, function(party)
			f.restored = party
		end)
	end
	f.fail = function(token, placeId)
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ lobbyGatherToken = token })
		f.failure(f.player, Enum.TeleportResult.GameFull, "full", placeId or 123, options)
		options:Destroy()
	end
	return f
end

return function()
	describe("Lobby party gathering", function()
		it("targets the leader's public lobby once and keeps membership intact", function()
			local f = fixture()
			f.consider()
			f.consider()
			expect(f.calls).to.equal(1)
			expect(f.placeId).to.equal(123)
			expect(f.target).to.equal("leader-server")
			expect(f.teleportedPlayer).to.equal(f.player)
			expect(f.data.partyId).to.equal("party")
			expect(f.coordinator:IsGathering(f.player, "party")).to.equal(true)
			expect(f.coordinator:IsGathering(f.player, "different-party")).to.equal(false)
			expect(#f.party.members).to.equal(2)
			f.coordinator:Destroy()
		end)
		it("falls back after an immediate error without repeatedly teleporting", function()
			local f = fixture()
			f.throw = true
			f.consider()
			f.consider()
			expect(f.calls).to.equal(1)
			expect(f.coordinator:IsGathering(f.player)).to.equal(false)
			expect(#f.party.members).to.equal(2)
			f.coordinator:Destroy()
		end)
		it("handles only the matching asynchronous failure and allows a new leader server", function()
			local f = fixture()
			f.consider()
			f.fail("stale")
			f.fail(f.data.lobbyGatherToken, 999)
			expect(f.coordinator:IsGathering(f.player)).to.equal(true)
			f.fail(f.data.lobbyGatherToken)
			expect(f.coordinator:IsGathering(f.player)).to.equal(false)
			f.consider()
			expect(f.calls).to.equal(1)
			f.presence.jobId = "new-leader-server"
			f.consider()
			expect(f.calls).to.equal(2)
			f.coordinator:Destroy()
		end)
		for name, mutate in
			{
				["same server"] = function(f)
					f.presence.jobId = "source-server"
				end,
				["leader"] = function(f)
					f.player.UserId = 10
				end,
				["outsider"] = function(f)
					f.player.UserId = 30
				end,
				["queued party"] = function(f)
					f.party.phase = "Queued"
				end,
				["expired presence"] = function(f)
					f.presence.refreshedAt = 900
				end,
				["future presence"] = function(f)
					f.presence.refreshedAt = 1001
				end,
				["another place"] = function(f)
					f.presence.placeId = 999
				end,
				["private server"] = function(f)
					f.presence.publicServer = false
				end,
				["legacy presence"] = function(f)
					f.presence.placeId = nil
				end,
				["different party index"] = function(f)
					f.presence.partyId = "other"
				end,
				["missing job ID"] = function(f)
					f.coordinator._jobId = ""
				end,
				["disabled Studio teleports"] = function(f)
					f.coordinator._enabled = false
				end,
				["detached member"] = function(f)
					f.attached = false
				end,
				["arena transfer"] = function(f)
					f.arena = true
				end,
				["departed player"] = function(f)
					f.player.Parent = nil
				end,
			}
		do
			it("keeps state syncing for " .. name, function()
				local f = fixture()
				mutate(f)
				f.consider()
				expect(f.calls).to.equal(0)
				f.coordinator:Destroy()
			end)
		end
		it("rechecks party phase after a yielding read", function()
			local f = fixture()
			local reads = 0
			f.onRead = function()
				reads += 1
				if reads == 2 then
					f.party.phase = "Assigned"
				end
			end
			f.consider()
			expect(f.calls).to.equal(0)
			f.coordinator:Destroy()
		end)
		it("restores existing membership even if matchmaking advanced during transit", function()
			local f = fixture()
			f.party.phase = "Teleporting"
			expect(f.restore()).to.equal(true)
			expect(f.restored).to.equal(f.party)
			expect(f.indexed).to.equal(1)
			expect(f.party.phase).to.equal("Teleporting")
			f.coordinator:Destroy()
		end)
		it("restores membership on a different destination without a teleport loop", function()
			local f = fixture()
			expect(f.restore()).to.equal(true)
			f.consider()
			expect(f.calls).to.equal(0)
			f.coordinator:Destroy()
		end)
		for name, mutate in
			{
				["foreign source"] = function(f)
					f.joinData.SourceGameId = 999
				end,
				["foreign place"] = function(f)
					f.joinData.SourcePlaceId = 999
				end,
				["forged party"] = function(f)
					f.joinData.TeleportData.partyId = "other"
				end,
				["kicked member"] = function(f)
					f.party.members = { { userId = 10 } }
				end,
				["changed index"] = function(f)
					f.presence.partyId = "new-party"
				end,
			}
		do
			it("rejects arrival for " .. name, function()
				local f = fixture()
				mutate(f)
				expect(f.restore()).to.equal(false)
				expect(f.restored).to.equal(nil)
				f.coordinator:Destroy()
			end)
		end
		for _, field in { "presenceError", "partyError", "indexError" } do
			it("preserves membership when arrival fails on " .. field, function()
				local f = fixture()
				f[field] = "unavailable"
				local handled, message = f.restore()
				expect(handled).to.equal(true)
				expect(message).to.equal("unavailable")
				expect(f.restored).to.equal(nil)
				expect(#f.party.members).to.equal(2)
				f.coordinator:Destroy()
			end)
		end
		it("blocks mutating requests during transfer but allows snapshots", function()
			local f = fixture()
			f.consider()
			local service = PartyService.new(
				{},
				{},
				{},
				{},
				{},
				{},
				{ players = f.players, lobbyGatherCoordinator = f.coordinator }
			)
			service._dispatchRequest = function()
				return "snapshot"
			end
			expect(service:HandleRequest(f.player, Protocol.Actions.LeaveParty, {}).error).to.equal(
				Protocol.Errors.Busy
			)
			expect(service:HandleRequest(f.player, Protocol.Actions.GetSnapshot, {})).to.equal("snapshot")
			f.coordinator:Destroy()
		end)
		it("clears departure state and disconnects on shutdown", function()
			local f = fixture()
			f.consider()
			f.coordinator:Clear(f.player)
			expect(f.coordinator:IsGathering(f.player)).to.equal(false)
			f.coordinator:Destroy()
			expect(f.disconnected).to.equal(true)
			f.consider()
			expect(f.calls).to.equal(1)
		end)
		it("preserves departing membership during gathering and removes it after failure", function()
			local f = fixture()
			f.consider()
			local removing
			f.players.PlayerAdded = { Connect = function() end }
			f.players.PlayerRemoving = {
				Connect = function(_self, callback)
					removing = callback
				end,
			}
			f.players.GetPlayers = function()
				return {}
			end
			local removed, released = 0, 0
			local service = PartyService.new({}, {}, {}, {
				Release = function()
					released += 1
				end,
			}, {
				IsTeleporting = function()
					return false
				end,
				Clear = function() end,
			}, {}, { players = f.players, lobbyGatherCoordinator = f.coordinator })
			service._runLoop = function() end
			service._partyForPlayer = function()
				return f.party
			end
			service._removeMemberFromParty = function()
				removed += 1
			end
			service._localPartyByUser[20] = "party"
			service._localPlayersByParty.party = { [20] = f.player }
			service:Start()
			removing(f.player)
			expect(removed).to.equal(0)
			expect(released).to.equal(1)
			f.throw = true
			f.consider()
			removing(f.player)
			expect(removed).to.equal(1)
			f.coordinator:Destroy()
		end)
		it("keeps snapshots and MessagingService subscriptions active on fallback", function()
			local f = fixture()
			f.throw = true
			f.consider()
			local snapshots, ensured = 0, 0
			local service = PartyService.new(f.repository, {}, {}, {
				Ensure = function()
					ensured += 1
				end,
			}, {
				IsTeleporting = function()
					return false
				end,
			}, {}, { players = f.players, lobbyGatherCoordinator = f.coordinator })
			service._cache.party = f.party
			service._localPartyByUser[20] = "party"
			service._localPlayersByParty.party = { [20] = f.player }
			service._sendSnapshot = function()
				snapshots += 1
			end
			f.party = table.clone(f.party)
			f.party.revision = 2
			service:_reconcile()
			task.wait()
			expect(ensured).to.equal(1)
			expect(snapshots).to.equal(1)
			expect(f.calls).to.equal(1)
			f.coordinator:Destroy()
		end)
		it("waits for a pending lobby transfer before dispatching an arena teleport", function()
			local f = fixture()
			f.consider()
			f.party.phase = "Teleporting"
			f.party.matchId = "match"
			local arenaCalls = 0
			local service = PartyService.new({}, {}, {}, {}, {
				TeleportParty = function()
					arenaCalls += 1
				end,
			}, {}, { players = f.players, lobbyGatherCoordinator = f.coordinator })
			service._cache.party = f.party
			service._localPlayersByParty.party = { [20] = f.player }
			service._teleportPresentationReady[20] = true
			service._reportFunnel = function() end
			service:_maybeTeleport(f.party)
			task.wait()
			expect(arenaCalls).to.equal(0)
			f.fail(f.data.lobbyGatherToken)
			service:_maybeTeleport(f.party)
			task.wait()
			expect(arenaCalls).to.equal(1)
			f.coordinator:Destroy()
		end)
	end)
end
