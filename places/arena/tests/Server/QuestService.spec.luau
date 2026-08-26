-- Name: QuestService.spec.luau
-- Author: Jack C.
-- Description: In-place spec for the quest service injection seam and the guard paths reachable without loaded profiles.
-- Created: 2026-07-16

--!nonstrict

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

			QuestService.start(fakeMatchService)
			expect(#listeners).to.equal(1)
		end)

		it("claim reports profile_not_ready for players without loaded data", function()
			local player = FakePlayer.new(500001)
			local ok, reason = QuestService.claim(player, "any_quest")
			expect(ok).to.equal(false)
			expect(reason).to.equal("profile_not_ready")
		end)

		it("match events for absent players are absorbed without error", function()
			local matchState = ReplicatedStorage:FindFirstChild("MatchState")
			local createdMatchState = matchState == nil
			if matchState == nil then
				matchState = Instance.new("Folder")
				matchState.Name = "MatchState"
				matchState.Parent = ReplicatedStorage
			end

			local ok, message = pcall(function()
				QuestService.handleMatchEvent({ kind = "MatchEnded", winnerId = "1" })
				QuestService.handleMatchEvent({ kind = "MatchStarted" })
			end)
			if createdMatchState then
				matchState:Destroy()
			end

			if not ok then
				error(message, 0)
			end
		end)

		it("combat events dedupe and ignore unknown sources without error", function()
			local event = { kind = "Elim", tick = 1, sourceId = "999999999", targetId = "888888888" }
			QuestService.handleCombatEvent(event)
			QuestService.handleCombatEvent(event)
			QuestService.handleCombatEvent({ kind = "Elim", tick = 2 })
		end)
	end)
end
