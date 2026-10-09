-- Description: In-place smoke spec that the match service publishes its replicated match state surface, stays idle with no players, and rejects combat events from outside the playable roster.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MatchService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("MatchService"))

return function()
	describe("MatchService smoke", function()
		it("start exposes the replicated MatchState surface and stays Idle", function()
			MatchService.start()

			local stateFolder = ReplicatedStorage:FindFirstChild("MatchState")
			expect(stateFolder).to.be.ok()
			expect(stateFolder:GetAttribute("phase")).to.equal("Idle")
			expect(stateFolder:GetAttribute("winnerId")).to.equal("")
			expect(stateFolder:GetAttribute("modeId")).to.equal("")
			expect(typeof(stateFolder:GetAttribute("timeRemaining"))).to.equal("number")

			expect(MatchService.phase()).to.equal("Idle")

			MatchService.start()
			expect(MatchService.phase()).to.equal("Idle")
		end)

		it("rejects combat events for players outside the playable roster", function()
			local seen = {}
			MatchService.onEvent(function(event)
				table.insert(seen, event)
			end)

			local caught = { kind = "BallCaught", tick = 5, playerId = "1" }
			expect(MatchService.handleCombatEvent(caught)).to.equal(false)
			expect(#seen).to.equal(0)

			expect(MatchService.handleCombatEvent({ kind = "Elim", tick = 6, sourceId = "1", targetId = "2" })).to.equal(
				false
			)
			expect(#seen).to.equal(0)
		end)
	end)
end
