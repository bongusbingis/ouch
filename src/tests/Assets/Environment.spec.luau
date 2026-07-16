--!nonstrict
-- Pins the cloud execution context assumptions used by the rest of the suite.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

return function()
	describe("Cloud execution environment", function()
		it("runs in a server context", function()
			expect(RunService:IsServer()).to.equal(true)
			expect(RunService:IsClient()).to.equal(false)
		end)

		it("has no players (player emulation is impossible here)", function()
			expect(#Players:GetPlayers()).to.equal(0)
		end)

		it("has a sane world", function()
			expect(Workspace.Gravity > 0).to.equal(true)
		end)

		it("does not run the place simulation", function()
			expect(RunService:IsRunning()).to.equal(false)
		end)

		it("records whether place scripts auto-ran (diagnostic)", function()
			-- SimulationServer creates these when it starts; the suite also
			-- creates them via requires, so this is informative, not asserted.
			local matchState = ReplicatedStorage:FindFirstChild("MatchState")
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			print(
				`[Environment] MatchState present: {matchState ~= nil}; Remotes present: {remotes ~= nil}`
					.. ` (true before any Server spec runs implies place scripts auto-ran)`
			)
		end)
	end)
end
