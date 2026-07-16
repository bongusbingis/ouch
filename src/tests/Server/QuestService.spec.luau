--!nonstrict
-- QuestService through its injection seam: start(matchService) wiring and the
-- guard paths reachable without profiles. Real profile flows (ProfileStore →
-- DataStores, PlayerAdded) need real players and stay covered by the pure
-- QuestLogic specs; the cloud environment cannot emulate them.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local QuestService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("QuestService"))
local FakePlayer = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("FakePlayer"))

return function()
	describe("QuestService", function()
		it("start wires exactly one match-event listener into the injected seam", function()
			local listeners = {}
			local fakeMatchService = {
				onEvent = function(listener)
					table.insert(listeners, listener)
				end,
			}

			QuestService.start(fakeMatchService)

			expect(#listeners).to.equal(1)
			expect(listeners[1]).to.equal(QuestService.handleMatchEvent)

			-- start is guarded: a second start must not double-register.
			QuestService.start(fakeMatchService)
			expect(#listeners).to.equal(1)
		end)

		it("claim reports profile_not_ready for players without loaded data", function()
			-- FakePlayer.Parent is nil, so the profile wait exits immediately.
			local player = FakePlayer.new(500001)
			local ok, reason = QuestService.claim(player, "any_quest")
			expect(ok).to.equal(false)
			expect(reason).to.equal("profile_not_ready")
		end)

		it("match events for absent players are absorbed without error", function()
			QuestService.handleMatchEvent({ kind = "MatchEnded", winnerId = "1" })
			QuestService.handleMatchEvent({ kind = "MatchStarted" })
		end)

		it("combat events dedupe and ignore unknown sources without error", function()
			local event = { kind = "Elim", tick = 1, sourceId = "999999999", targetId = "888888888" }
			QuestService.handleCombatEvent(event)
			QuestService.handleCombatEvent(event)
			QuestService.handleCombatEvent({ kind = "Elim", tick = 2 })
		end)
	end)
end
