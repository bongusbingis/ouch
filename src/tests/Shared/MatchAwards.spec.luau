--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(game:GetService("ServerScriptService").Server.Modules.PlayerData)
local WriteThroughProxy = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Data"):WaitForChild("WriteThroughProxy")
)

return function()
	describe("Persisted match awards", function()
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
			PlayerData._profiles[player.UserId] = { Data = WriteThroughProxy.wrap(data, writer) }
			PlayerData.beginMatchAward(player, "match-one", "S1")
			PlayerData.addMatchProgress(player, "match-one", { Elims = 1, XP = 20, Bonks = 10 })
			PlayerData.finishMatchAward(player, "match-one", "result-one", false)
			PlayerData.resolveMatchAward(player, "match-one", { Elims = 1, XP = 40, Bonks = 20 }, { Xp = 2, Bonks = 2 })
			expect(PlayerData.applyMatchAward(player, "match-one")).to.equal(true)
			PlayerData._profiles[player.UserId] = { Data = WriteThroughProxy.wrap(data, writer) }
			expect(PlayerData.applyMatchAward(player, "match-one")).to.equal(true)
			expect(data.Bonks).to.equal(20)
			expect(data.Level.Points).to.equal(40)
			expect(PlayerData.completeMatchAward(player, "match-one")).to.equal(false)
			PlayerData.markMatchSeasonApplied(player, "match-one")
			expect(PlayerData.completeMatchAward(player, "match-one")).to.equal(true)
			expect(PlayerData.beginMatchAward(player, "match-one", "S1")).to.equal(nil)
		end)
	end)
end
