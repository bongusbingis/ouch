--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(game:GetService("ServerScriptService").Server.Modules.PlayerData)
local WriteThroughProxy = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Data"):WaitForChild("WriteThroughProxy")
)

local PLAYER_ID = -779005
local player = {
	UserId = PLAYER_ID,
	FindFirstChild = function()
		return nil
	end,
}

local function fixture(seasonId: string, amount: number): (any, any)
	local raw = {
		Bonks = 0,
		Level = { Points = 0 },
		Progression = { Elims = 0, Deaths = 0, Catches = 0, Wins = 0, Losses = 0, MatchesPlayed = 0, KDR = 0 },
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
	local replica = { calls = 0, fail = false, paths = {} }
	function replica:Set(path: { string }, _value: any)
		self.calls += 1
		table.insert(self.paths, table.concat(path, "."))
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
		it("rejects malformed saved career payout before any mutation, then replays once after repair", function()
			local raw, replica = fixture("S1", 25)
			local record = raw.MatchAwards.Pending.award
			record.Progress = { XP = 25, Bonks = 1 }
			record.Awarded = { XP = 25.5, Bonks = 1 }
			record.ProgressionApplied = false
			local applied, reason = PlayerData.applyMatchAward(player :: any, "award")
			expect(applied).to.equal(false)
			expect(string.find(reason or "", "MatchAwards.Pending.award.Awarded.XP", 1, true)).to.be.ok()
			expect(raw.Level.Points).to.equal(0)
			expect(raw.Bonks).to.equal(0)
			expect(record.ProgressionApplied).to.equal(false)
			expect(replica.calls).to.equal(0)

			record.Awarded = { XP = 25, Bonks = 1 }
			local resolved = PlayerData.resolveMatchAward(player :: any, "award", { XP = 100, Bonks = 100 }, {})
			expect(resolved.Awarded.XP).to.equal(25)
			expect(PlayerData.applyMatchAward(player :: any, "award")).to.equal(true)
			expect(PlayerData.applyMatchAward(player :: any, "award")).to.equal(true)
			expect(raw.Level.Points).to.equal(25)
			expect(raw.Bonks).to.equal(1)
		end)

		it("does not store an invalid candidate or accept a corrupt already-applied record", function()
			local raw = fixture("S1", 0)
			local record = raw.MatchAwards.Pending.award
			record.Progress = { XP = 0, Bonks = 0 }
			record.Awarded = nil
			record.ProgressionApplied = false
			local resolved, reason = PlayerData.resolveMatchAward(player :: any, "award", { XP = 1.5, Bonks = 0 }, {})
			expect(resolved).to.equal(nil)
			expect(string.find(reason or "", "MatchAwards.Pending.award.Awarded.XP", 1, true)).to.be.ok()
			expect(record.Awarded).to.equal(nil)
			expect(record.Multipliers).to.equal(nil)
			expect(record.FirstMatch).to.equal(nil)
			record.Awarded = { XP = 1.5, Bonks = 0 }
			record.ProgressionApplied = true
			local applied, applyReason = PlayerData.applyMatchAward(player :: any, "award")
			expect(applied).to.equal(false)
			expect(string.find(applyReason or "", "MatchAwards.Pending.award.Awarded.XP", 1, true)).to.be.ok()
			expect(raw.Level.Points).to.equal(0)
		end)

		it("holds career payout for unsupported journal version or unknown season", function()
			for _, failure in { "version", "season" } do
				local raw = fixture("S1", 40)
				local record = raw.MatchAwards.Pending.award
				record.Progress = { XP = 40, Bonks = 1 }
				record.Awarded = { XP = 40, Bonks = 1 }
				record.ProgressionApplied = false
				if failure == "version" then
					raw.MatchAwards.Version = 2
				else
					record.SeasonId = "unknown-season"
				end
				local applied, reason = PlayerData.applyMatchAward(player :: any, "award")
				expect(applied).to.equal(false)
				expect(
					string.find(
						reason or "",
						if failure == "version" then "MatchAwards.Version" else "MatchAwards.Pending.award.SeasonId",
						1,
						true
					)
				).to.be.ok()
				expect(raw.Level.Points).to.equal(0)
				expect(raw.Bonks).to.equal(0)
				expect(record.ProgressionApplied).to.equal(false)
			end
		end)

		it("writes XP and marker together before retrying a failed Replica send", function()
			local raw, replica = fixture("S1", 40)
			replica.fail = true
			local credited, reason = PlayerData.creditMatchSeasonXp(player :: any, "award")
			expect(credited).to.equal(false)
			expect(string.find(reason or "", "Replica notification failed", 1, true)).to.be.ok()
			expect(raw.SeasonHistory.S1.XP).to.equal(40)
			expect(raw.MatchAwards.Pending.award.SeasonApplied).to.equal(true)

			replica.fail = false
			expect(PlayerData.creditMatchSeasonXp(player :: any, "award")).to.equal(true)
			expect(raw.SeasonHistory.S1.XP).to.equal(40)
			expect(replica.calls).to.equal(3)
			expect(replica.paths[2]).to.equal("SeasonHistory.S1")
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
			expect(string.find(reason or "", "unknown season", 1, true)).to.be.ok()
			expect(raw.SeasonHistory.S1).to.equal(nil)
			expect(raw.MatchAwards.Pending.award.SeasonApplied).to.equal(false)
		end)

		it("rejects an archive with an empty or mismatched stored Id", function()
			for _, storedId in { "", "other" } do
				local raw, replica = fixture("S1", 40)
				raw.SeasonHistory.S1 = {
					Id = storedId,
					XP = 10,
					ClaimedFree = {},
					ClaimedPremium = {},
					CosmeticClaims = {},
				}
				local credited, reason = PlayerData.creditMatchSeasonXp(player :: any, "award")
				expect(credited).to.equal(false)
				expect(string.find(reason or "", "SeasonHistory.S1.Id", 1, true)).to.be.ok()
				expect(raw.SeasonHistory.S1.XP).to.equal(10)
				expect(raw.MatchAwards.Pending.award.SeasonApplied).to.equal(false)
				expect(replica.calls).to.equal(0)
			end
		end)

		it("rejects malformed active and archived XP before credit or marker", function()
			for _, badXp in { 0 / 0, math.huge, -math.huge, 1.5, "20" } do
				for _, active in { true, false } do
					local raw, replica = fixture("S1", 40)
					local target = if active
						then raw.Season
						else {
							Id = "S1",
							XP = 0,
							ClaimedFree = {},
							ClaimedPremium = {},
							CosmeticClaims = {},
						}
					if active then
						raw.Season.Id = "S1"
					else
						raw.SeasonHistory.S1 = target
					end
					target.XP = badXp
					local credited, reason = PlayerData.creditMatchSeasonXp(player :: any, "award")
					expect(credited).to.equal(false)
					expect(string.find(reason or "", if active then "Season.XP" else "SeasonHistory.S1.XP", 1, true)).to.be.ok()
					expect(raw.MatchAwards.Pending.award.SeasonApplied).to.equal(false)
					expect(replica.calls).to.equal(0)
				end
			end
		end)

		it("checks a zero-XP award's existing archive before marking it applied", function()
			local raw = fixture("S1", 0)
			raw.SeasonHistory.S1 = { Id = "S1", XP = 10, ClaimedFree = { ["1"] = "yes" }, ClaimedPremium = {} }
			local credited, reason = PlayerData.creditMatchSeasonXp(player :: any, "award")
			expect(credited).to.equal(false)
			expect(string.find(reason or "", "SeasonHistory.S1.ClaimedFree.1", 1, true)).to.be.ok()
			expect(raw.MatchAwards.Pending.award.SeasonApplied).to.equal(false)
		end)

		it("marks archived zero-XP credit without creating an empty archive", function()
			local raw, replica = fixture("S1", 0)
			expect(PlayerData.creditMatchSeasonXp(player :: any, "award")).to.equal(true)
			expect(raw.MatchAwards.Pending.award.SeasonApplied).to.equal(true)
			expect(raw.SeasonHistory.S1).to.equal(nil)
			expect(replica.calls).to.equal(1)
			expect(PlayerData.creditMatchSeasonXp(player :: any, "award")).to.equal(true)
			expect(raw.SeasonHistory.S1).to.equal(nil)
			expect(replica.calls).to.equal(1)
		end)

		it("accepts old archived numeric and false claim markers without a CosmeticClaims field", function()
			local raw = fixture("S1", 40)
			raw.SeasonHistory.S1 =
				{ Id = "S1", XP = 10, ClaimedFree = { [1] = true, ["2"] = false }, ClaimedPremium = {} }
			expect(PlayerData.creditMatchSeasonXp(player :: any, "award")).to.equal(true)
			expect(raw.SeasonHistory.S1.XP).to.equal(50)
			expect(raw.MatchAwards.Pending.award.SeasonApplied).to.equal(true)
		end)

		it("rejects archive exhaustion before touching XP or the journal", function()
			local raw = fixture("S1", 40)
			for index = 1, 64 do
				raw.SeasonHistory[`old-{index}`] = {
					Id = `old-{index}`,
					XP = 0,
					ClaimedFree = {},
					ClaimedPremium = {},
					CosmeticClaims = {},
				}
			end
			local credited, reason = PlayerData.creditMatchSeasonXp(player :: any, "award")
			expect(credited).to.equal(false)
			expect(string.find(reason or "", "archive capacity", 1, true)).to.be.ok()
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
