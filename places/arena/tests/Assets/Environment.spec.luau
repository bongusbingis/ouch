-- Description: In-place spec pinning the assumptions the rest of the cloud suite relies on: a server context, no players, a sane world, and no running place simulation.

--!nonstrict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local LiveSession = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("LiveSession"))

return function()
	describe("Cloud execution environment", function()
		-- These two pin the headless cloud environment itself; a Studio Play session legitimately
		-- has a player and a running simulation, so they skip there and run in the cloud.
		local cloudOnlyIt = LiveSession.guardedIt(it, itSKIP)
		it("runs in a server context", function()
			expect(RunService:IsServer()).to.equal(true)
			expect(RunService:IsClient()).to.equal(false)
		end)

		cloudOnlyIt("has no players (player emulation is impossible here)", function()
			expect(#Players:GetPlayers()).to.equal(0)
		end)

		it("has a sane world", function()
			expect(Workspace.Gravity > 0).to.equal(true)
		end)

		cloudOnlyIt("does not run the place simulation", function()
			expect(RunService:IsRunning()).to.equal(false)
		end)

		it("records whether place scripts auto-ran (diagnostic)", function()
			local matchState = ReplicatedStorage:FindFirstChild("MatchState")
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			print(
				`[Environment] MatchState present: {matchState ~= nil}; Remotes present: {remotes ~= nil}`
					.. ` (true before any Server spec runs implies place scripts auto-ran)`
			)
		end)
	end)
end
