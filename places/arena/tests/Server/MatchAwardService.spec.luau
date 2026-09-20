--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(game:GetService("ServerScriptService").Server.Modules.PlayerData)
local WriteThroughProxy = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Data"):WaitForChild("WriteThroughProxy")
)

local PLAYER_ID = -779005
local player = { UserId = PLAYER_ID }

local function fixture(seasonId: string, amount: number): (any, any)
	local raw = {
		Season = { Id = "", XP = 0, ClaimedFree = {}, ClaimedPremium = {}, CosmeticClaims = {} },
		SeasonHistory = {},
		MatchAwards = {
			Version = 1,
			Pending = {
				award = {
					Ready = true,
					ProgressionApplied = true,
					SeasonApplied = false,
					SeasonId = seasonId,
					Awarded = { XP = amount },
				},
			},
			Completed = {},
		},
	}
	local replica = { calls = 0, fail = false }
	function replica:Set(_path: { string }, _value: any)
		self.calls += 1
		if self.fail then
			error("replica unavailable")
		end
	end
	local profile = { Data = raw }
	function profile:IsActive(): boolean
		return true
	end
	PlayerData._profiles[PLAYER_ID] = {
		Profile = profile,
		Data = WriteThroughProxy.wrap(raw, { Set = function() end }),
		Replica = replica,
	}
	PlayerData._writeLeaseCounts[PLAYER_ID] = 1
	return raw, replica
end

return function()
	describe("Match award season credit", function()
		afterEach(function()
			PlayerData._profiles[PLAYER_ID] = nil
			PlayerData._writeLeaseCounts[PLAYER_ID] = nil
		end)

		it("writes XP and marker together before retrying a failed Replica send", function()
			local raw, replica = fixture("S1", 40)
			replica.fail = true
			local credited, reason = PlayerData.creditMatchSeasonXp(player :: any, "award")
			expect(credited).to.equal(false)
			expect(string.find(reason, "Replica notification failed", 1, true)).to.be.ok()
			expect(raw.SeasonHistory.S1.XP).to.equal(40)
			expect(raw.MatchAwards.Pending.award.SeasonApplied).to.equal(true)

			replica.fail = false
			expect(PlayerData.creditMatchSeasonXp(player :: any, "award")).to.equal(true)
			expect(raw.SeasonHistory.S1.XP).to.equal(40)
			expect(replica.calls).to.equal(3)
		end)

		it("does not credit again after a saved partial record reload", function()
			local raw = fixture("S1", 40)
			expect(PlayerData.creditMatchSeasonXp(player :: any, "award")).to.equal(true)
			local saved = table.clone(raw)
			local reloaded = fixture("S1", 40)
			reloaded.SeasonHistory = saved.SeasonHistory
			reloaded.MatchAwards = saved.MatchAwards
			expect(PlayerData.creditMatchSeasonXp(player :: any, "award")).to.equal(true)
			expect(reloaded.SeasonHistory.S1.XP).to.equal(40)
		end)

		it("rejects an unknown season before touching XP or the journal", function()
			local raw = fixture("missing-season", 40)
			local credited, reason = PlayerData.creditMatchSeasonXp(player :: any, "award")
			expect(credited).to.equal(false)
			expect(string.find(reason, "unknown season", 1, true)).to.be.ok()
			expect(raw.SeasonHistory.S1).to.equal(nil)
			expect(raw.MatchAwards.Pending.award.SeasonApplied).to.equal(false)
		end)

		it("rejects archive exhaustion before touching XP or the journal", function()
			local raw = fixture("S1", 40)
			for index = 1, 64 do
				raw.SeasonHistory[`old-{index}`] = { Id = `old-{index}`, XP = 0 }
			end
			local credited, reason = PlayerData.creditMatchSeasonXp(player :: any, "award")
			expect(credited).to.equal(false)
			expect(string.find(reason, "archive capacity", 1, true)).to.be.ok()
			expect(raw.SeasonHistory.S1).to.equal(nil)
			expect(raw.MatchAwards.Pending.award.SeasonApplied).to.equal(false)
		end)

		it("marks a no-active-season award without banking XP", function()
			local raw = fixture("", 40)
			expect(PlayerData.creditMatchSeasonXp(player :: any, "award")).to.equal(true)
			expect(raw.Season.XP).to.equal(0)
			expect(next(raw.SeasonHistory)).to.equal(nil)
			expect(raw.MatchAwards.Pending.award.SeasonApplied).to.equal(true)
		end)
	end)
end
