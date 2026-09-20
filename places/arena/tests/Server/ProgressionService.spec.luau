--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Data"))
local Boosts = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("Boosts")
)
local serviceScript =
	ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("ProgressionService")
local ProgressionService = require(serviceScript)

local function withReward(category: string, key: string, value: any, check: () -> ())
	local amounts = DataConfig[category]
	local original = amounts[key]
	amounts[key] = value
	local ok, message = pcall(check)
	amounts[key] = original
	if not ok then
		error(message, 0)
	end
end

return function()
	describe("ProgressionService reward configuration", function()
		it("accepts all configured payouts", function()
			local valid, reason = ProgressionService.validateRewardConfig()
			expect(valid).to.equal(true)
			expect(reason).to.equal(nil)
		end)

		it("allows explicit zero for Elim and Catch", function()
			for _, category in { "ProgressionXP", "ProgressionBonks" } do
				for _, key in { "Elim", "Catch" } do
					withReward(category, key, 0, function()
						local valid = ProgressionService.validateRewardConfig()
						expect(valid).to.equal(true)
					end)
				end
			end
		end)

		it("rejects every missing reward with its exact config path", function()
			for _, category in { "ProgressionXP", "ProgressionBonks" } do
				for _, key in { "MatchComplete", "Win", "Elim", "Catch" } do
					withReward(category, key, nil, function()
						local valid, reason = ProgressionService.validateRewardConfig()
						expect(valid).to.equal(false)
						expect(string.find(reason :: string, `Config.Progression.Data.{category}.{key}`, 1, true)).to.be.ok()
					end)
				end
			end
		end)

		it("rejects wrong-type, nonfinite, and negative rewards", function()
			for _, case in
				{
					{ category = "ProgressionXP", key = "Win", value = "100" },
					{ category = "ProgressionBonks", key = "MatchComplete", value = 0 },
					{ category = "ProgressionXP", key = "Elim", value = -1 },
					{ category = "ProgressionBonks", key = "Catch", value = math.huge },
					{ category = "ProgressionXP", key = "Catch", value = 0 / 0 },
				}
			do
				withReward(case.category, case.key, case.value, function()
					local valid, reason = ProgressionService.validateRewardConfig()
					expect(valid).to.equal(false)
					expect(string.find(reason :: string, `Config.Progression.Data.{case.category}.{case.key}`, 1, true)).to.be.ok()
				end)
			end
		end)

		it("rejects a fraction in each XP and Bonks match reward leaf", function()
			for _, category in { "ProgressionXP", "ProgressionBonks" } do
				for _, key in { "MatchComplete", "Win", "Elim", "Catch" } do
					withReward(category, key, 1.5, function()
						local valid, reason = ProgressionService.validateRewardConfig()
						expect(valid).to.equal(false)
						expect(string.find(reason :: string, `Config.Progression.Data.{category}.{key}`, 1, true)).to.be.ok()
						expect(string.find(reason :: string, "integer", 1, true)).to.be.ok()
					end)
				end
			end
		end)

		it("keeps valid integer payouts integral with a 1.5 multiplier", function()
			withReward("ProgressionXP", "MatchComplete", 3, function()
				withReward("ProgressionBonks", "MatchComplete", 3, function()
					local valid = ProgressionService.validateRewardConfig()
					expect(valid).to.equal(true)
					expect(Boosts.apply(DataConfig.ProgressionXP.MatchComplete, 1.5)).to.equal(4)
					expect(Boosts.apply(DataConfig.ProgressionBonks.MatchComplete, 1.5)).to.equal(4)
				end)
			end)
		end)

		it("does not subscribe after an invalid startup", function()
			local clone = serviceScript:Clone()
			clone.Parent = serviceScript.Parent
			local clonedService = require(clone)
			local subscriptions = 0
			withReward("ProgressionXP", "MatchComplete", nil, function()
				local ok, message = pcall(function()
					clonedService.start({
						onEvent = function()
							subscriptions += 1
						end,
					})
				end)
				expect(ok).to.equal(false)
				expect(string.find(message :: string, "Config.Progression.Data.ProgressionXP.MatchComplete", 1, true)).to.be.ok()
				expect(subscriptions).to.equal(0)
			end)
			clone:Destroy()
		end)
	end)
end
