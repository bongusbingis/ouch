--!nonstrict

-- Teleport preflight failures remain recoverable without crossing a place boundary.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Coordinator = require(ReplicatedStorage.Shared.Game.Matchmaking.TeleportRetryCoordinator)

local function signal()
	return {
		Connect = function()
			return { Disconnect = function() end }
		end,
	}
end

local function fixture(preflight)
	local players = { PlayerRemoving = signal() }
	local player = { UserId = 10, Parent = players }
	function players:GetPlayerByUserId(userId)
		return if userId == 10 then player else nil
	end
	local transfers = 0
	local statuses = {}
	local coordinator = Coordinator.new("Lobby", {
		players = players,
		teleportService = {
			TeleportInitFailed = signal(),
			TeleportAsync = function()
				transfers += 1
			end,
		},
		network = {
			fire = function(_name, _player, packet)
				table.insert(statuses, packet)
			end,
		},
	})
	local prepared = coordinator:Prepare(1, { player }, function()
		return Instance.new("TeleportOptions")
	end, preflight)
	return coordinator, player, prepared, statuses, function()
		return transfers
	end
end

return function()
	describe("Teleport preflight", function()
		it("exposes Retry after a rejected reward preflight and rechecks before transferring", function()
			local ready = false
			local checks = 0
			local coordinator, player, prepared, statuses, transfers = fixture(function()
				checks += 1
				return ready, "rewards_pending"
			end)
			local ok, reason = coordinator:StartPrepared(prepared)
			expect(ok).to.equal(false)
			expect(reason).to.equal("rewards_pending")
			expect(transfers()).to.equal(0)
			expect(statuses[#statuses].state).to.equal("Failed")
			expect(coordinator:CanRetry(player)).to.equal(true)
			ready = true
			expect(coordinator:Retry(player)).to.equal(true)
			expect(checks).to.equal(2)
			expect(transfers()).to.equal(1)
			coordinator:Destroy()
		end)
		it("allows Stay after a preflight exception without making a teleport", function()
			local coordinator, player, prepared, _statuses, transfers = fixture(function()
				error("fixture failure")
			end)
			local ok, reason = coordinator:StartPrepared(prepared)
			expect(ok).to.equal(false)
			expect(reason).to.equal("preflight_failed")
			expect(coordinator:Stay(player)).to.equal(true)
			expect(coordinator:IsTracked(player)).to.equal(false)
			expect(transfers()).to.equal(0)
			coordinator:Destroy()
		end)
		it("honors cancellation while preflight yields or clears its batch", function()
			local coordinator, player, prepared, _statuses, transfers = fixture(nil)
			coordinator._states[player.UserId].preflight = function()
				coordinator:Clear(player)
				return true
			end
			local ok, reason = coordinator:StartPrepared(prepared)
			expect(ok).to.equal(false)
			expect(reason).to.equal("cancelled")
			expect(transfers()).to.equal(0)
			coordinator:Destroy()
		end)
	end)
end
