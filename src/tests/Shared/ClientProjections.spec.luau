--!nonstrict

local Game = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Game")
local SeasonStore = require(Game.Progression.SeasonStore)
local QuestStore = require(Game.Quests.QuestStore)
local DailyRewardStore = require(Game.DailyReward.DailyRewardStore)

local function network(fetch)
	local push
	return {
		on = function(_name, callback)
			push = callback
			return {
				Disconnect = function()
					push = nil
				end,
			}
		end,
		call = fetch,
		push = function(value)
			if push then
				push(value)
			end
		end,
	}
end

return function()
	describe("Client progression projections", function()
		afterEach(function()
			SeasonStore.stop()
			QuestStore.stop()
			DailyRewardStore.stop()
		end)
		it("retries season hydration after an unavailable profile", function()
			local calls = 0
			local expected = { active = true, tier = 2 }
			SeasonStore.start({
				network = network(function()
					calls += 1
					return if calls == 1 then nil else expected
				end),
			})
			local deadline = os.clock() + 2
			repeat
				task.wait()
			until SeasonStore.snapshot() ~= nil or os.clock() >= deadline
			expect(SeasonStore.snapshot()).to.equal(expected)
			expect(calls).to.equal(2)
		end)
		it("does not overwrite a rollover push with an older quest response", function()
			local released = false
			local adapter = network(function()
				repeat
					task.wait()
				until released
				return { dailyKey = "old", quests = {} }
			end)
			QuestStore.start({ network = adapter })
			task.wait()
			adapter.push({ dailyKey = "new", quests = {} })
			released = true
			task.wait()
			expect(QuestStore.snapshot().dailyKey).to.equal("new")
		end)
		it("cancels deferred initial callbacks when stopped", function()
			local adapter = network(function()
				return nil
			end)
			DailyRewardStore.start({ network = adapter })
			adapter.push({ canClaim = true })
			local called = false
			DailyRewardStore.subscribe(function()
				called = true
			end)
			DailyRewardStore.stop()
			task.wait()
			expect(called).to.equal(false)
		end)
		it("reports failed claims without changing the authoritative projection", function()
			local adapter = network(function()
				error("disconnected")
			end)
			DailyRewardStore.start({ network = adapter })
			local expected = { canClaim = true }
			adapter.push(expected)
			local result, reason = DailyRewardStore.claim()
			expect(result).to.equal(nil)
			expect(reason).to.equal("connection_failed")
			expect(DailyRewardStore.snapshot()).to.equal(expected)
		end)
	end)
end
