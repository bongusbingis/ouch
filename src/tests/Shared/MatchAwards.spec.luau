--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(game:GetService("ServerScriptService").Server.Modules.PlayerData)
local MatchAwards = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("MatchAwards")
)
local WriteThroughProxy = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Data"):WaitForChild("WriteThroughProxy")
)

return function()
	describe("Persisted match awards", function()
		local function pending()
			return {
				Ready = true,
				ProgressionApplied = false,
				SeasonApplied = false,
				SeasonId = "",
				Progress = { XP = 0, Bonks = 0 },
			}
		end
		it("accepts sparse V1 deltas and valid false markers", function()
			local record = pending()
			record.Awarded = { XP = 40, Bonks = 20 }
			expect(MatchAwards.validatePending(record, "sparse")).to.equal(true)
			record.Ready = false
			record.Awarded = nil
			expect(MatchAwards.validatePending(record, "unfinished")).to.equal(true)
		end)
		it("rejects contradictory saved marker implications", function()
			local record = pending()
			record.SeasonApplied = true
			local valid, reason = MatchAwards.validatePending(record, "season")
			expect(valid).to.equal(false)
			expect(string.find(reason or "", "MatchAwards.Pending.season.SeasonApplied", 1, true)).to.be.ok()
			record = pending()
			record.Ready = false
			record.ProgressionApplied = true
			valid, reason = MatchAwards.validateMarkers(record, "career")
			expect(valid).to.equal(false)
			expect(string.find(reason or "", "MatchAwards.Pending.career.ProgressionApplied", 1, true)).to.be.ok()
			record = pending()
			record.Ready = false
			record.Awarded = { XP = 0, Bonks = 0 }
			valid, reason = MatchAwards.validateMarkers(record, "unready")
			expect(valid).to.equal(false)
			expect(string.find(reason or "", "MatchAwards.Pending.unready.Awarded", 1, true)).to.be.ok()
		end)
		it("rejects malformed saved fields with their exact paths", function()
			for _, field in { "XP", "Bonks" } do
				for _, bad in { "4", -1, 1.5, math.huge, 0 / 0 } do
					for _, section in { "Progress", "Awarded" } do
						local record = pending()
						record.Awarded = { XP = 0, Bonks = 0 }
						record[section][field] = bad
						local valid, reason = MatchAwards.validatePending(record, "bad")
						expect(valid).to.equal(false)
						expect(string.find(reason or "", `MatchAwards.Pending.bad.{section}.{field}`, 1, true)).to.be.ok()
					end
				end
				for _, section in { "Progress", "Awarded" } do
					local record = pending()
					record.Awarded = { XP = 0, Bonks = 0 }
					record[section][field] = nil
					local valid, reason = MatchAwards.validatePending(record, "missing")
					expect(valid).to.equal(false)
					expect(string.find(reason or "", `MatchAwards.Pending.missing.{section}.{field}`, 1, true)).to.be.ok()
				end
			end
			for _, field in { "Elims", "Deaths", "Catches", "Wins", "Losses", "MatchesPlayed" } do
				local record = pending()
				record.Awarded = { XP = 0, Bonks = 0 }
				record.Progress[field] = 1.5
				local valid, reason = MatchAwards.validatePending(record, "optional")
				expect(valid).to.equal(false)
				expect(string.find(reason or "", `MatchAwards.Pending.optional.Progress.{field}`, 1, true)).to.be.ok()
			end
		end)
		it("rejects malformed markers and an applied record without Awarded", function()
			for _, field in { "Ready", "ProgressionApplied", "SeasonApplied" } do
				local record = pending()
				record[field] = "false"
				local valid, reason = MatchAwards.validatePending(record, "marker")
				expect(valid).to.equal(false)
				expect(string.find(reason or "", `MatchAwards.Pending.marker.{field}`, 1, true)).to.be.ok()
			end
			local record = pending()
			record.ProgressionApplied = true
			local valid, reason = MatchAwards.validatePending(record, "applied")
			expect(valid).to.equal(false)
			expect(string.find(reason or "", "MatchAwards.Pending.applied.Awarded", 1, true)).to.be.ok()
		end)
		local player = {
			UserId = -779001,
			FindFirstChild = function()
				return nil
			end,
		}
		afterEach(function()
			PlayerData._profiles[player.UserId] = nil
		end)
		it("resumes a saved partial commit without awarding progression twice", function()
			local data = {
				Bonks = 0,
				Season = { Id = "S1", XP = 0, ClaimedFree = {}, ClaimedPremium = {}, CosmeticClaims = {} },
				SeasonHistory = {},
				Level = { Points = 0 },
				Progression = {
					Elims = 0,
					Deaths = 0,
					Catches = 0,
					Wins = 0,
					Losses = 0,
					MatchesPlayed = 0,
					KDR = 0,
				},
			}
			local writer = { Set = function() end }
			PlayerData._profiles[player.UserId] =
				{ Profile = { Data = data }, Data = WriteThroughProxy.wrap(data, writer) }
			PlayerData.beginMatchAward(player, "match-one", "S1")
			PlayerData.addMatchProgress(player, "match-one", { Elims = 1, XP = 20, Bonks = 10 })
			PlayerData.finishMatchAward(player, "match-one", "result-one", false)
			PlayerData.resolveMatchAward(player, "match-one", { Elims = 1, XP = 40, Bonks = 20 }, { Xp = 2, Bonks = 2 })
			expect(PlayerData.applyMatchAward(player, "match-one")).to.equal(true)
			PlayerData._profiles[player.UserId] =
				{ Profile = { Data = data }, Data = WriteThroughProxy.wrap(data, writer) }
			expect(PlayerData.applyMatchAward(player, "match-one")).to.equal(true)
			expect(data.Bonks).to.equal(20)
			expect(data.Level.Points).to.equal(40)
			expect(PlayerData.completeMatchAward(player, "match-one")).to.equal(false)
			PlayerData.markMatchSeasonApplied(player, "match-one")
			expect(PlayerData.completeMatchAward(player, "match-one")).to.equal(true)
			expect(PlayerData.beginMatchAward(player, "match-one", "S1")).to.equal(nil)
		end)
	end)

	describe("MatchAwards", function()
		it("migrates old profiles without replacing existing rewards", function()
			local data: any = { Bonks = 125 }
			local journal = MatchAwards.ensure(data)
			expect(journal.Version).to.equal(1)
			expect(data.Bonks).to.equal(125)
			MatchAwards.enqueue(journal, "one", { Ready = false }, 2)
			expect(MatchAwards.ensure(data).Pending.one.Ready).to.equal(false)
		end)

		it("rejects capacity overflow without evicting pending entries", function()
			local journal = MatchAwards.ensure({})
			MatchAwards.enqueue(journal, "one", { XP = 100 }, 1)
			expect(MatchAwards.enqueue(journal, "two", { XP = 200 }, 1)).to.equal(nil)
			expect(journal.Pending.one.XP).to.equal(100)
		end)

		it("deduplicates completed awards and bounds completion history", function()
			local journal = MatchAwards.ensure({})
			for index = 1, 5 do
				local id = tostring(index)
				MatchAwards.enqueue(journal, id, {}, 2)
				MatchAwards.complete(journal, id, index, 2)
			end
			expect(journal.Completed["3"]).to.equal(nil)
			expect(journal.Completed["4"]).to.equal(4)
			expect(MatchAwards.enqueue(journal, "5", {}, 2)).to.equal(nil)
			expect(next(journal.Pending)).to.equal(nil)
		end)
	end)
end
