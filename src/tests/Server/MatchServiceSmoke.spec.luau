--!nonstrict
-- MatchService smoke coverage: with zero players the match must stay Idle,
-- and the replicated MatchState surface must exist with its documented
-- attributes. Full match flow needs real players; the pure phase machine is
-- covered by the MatchSim spec.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModeRegistry = require(Shared:WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeRegistry"))
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
			expect(stateFolder:GetAttribute("mapId")).to.equal("")
			expect(stateFolder:GetAttribute("modeId")).to.equal(ModeRegistry.default().id)
			expect(typeof(stateFolder:GetAttribute("timeRemaining"))).to.equal("number")
			expect(stateFolder:GetAttribute("voteOpen")).to.equal(false)
			expect(typeof(stateFolder:GetAttribute("voteEndsAt"))).to.equal("number")

			expect(MatchService.phase()).to.equal("Idle")

			-- Guarded start: calling again must be a no-op.
			MatchService.start()
			expect(MatchService.phase()).to.equal("Idle")
		end)

		it("dispatches combat events to onEvent listeners", function()
			local seen = {}
			MatchService.onEvent(function(event)
				table.insert(seen, event)
			end)

			local caught = { kind = "BallCaught", tick = 5, playerId = "1" }
			expect(MatchService.handleCombatEvent(caught)).to.equal(false)
			expect(#seen).to.equal(1)
			expect(seen[1].kind).to.equal("BallCaught")
			expect(seen[1] == caught).to.equal(false)

			-- Elims for unknown victims are rejected before any scoring.
			expect(MatchService.handleCombatEvent({ kind = "Elim", tick = 6, sourceId = "1", targetId = "2" })).to.equal(
				false
			)
			expect(#seen).to.equal(1)
		end)
	end)
end
