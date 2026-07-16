--!nonstrict
-- Pins the cloud execution environment assumptions the rest of the suite
-- relies on, and logs diagnostics (whether place scripts auto-ran, scheduler
-- behavior) so environment changes fail loudly here instead of corrupting
-- other specs.

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

		it("resumes yielded threads (task scheduler is live)", function()
			local resumed = false
			task.defer(function()
				resumed = true
			end)
			task.wait()
			expect(resumed).to.equal(true)
		end)

		it("fires Heartbeat (services and timed specs depend on it)", function()
			local dt = RunService.Heartbeat:Wait()
			expect(typeof(dt)).to.equal("number")
			expect(dt > 0).to.equal(true)
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
