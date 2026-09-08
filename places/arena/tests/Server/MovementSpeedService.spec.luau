-- Description: In-place spec that named walk-speed modifiers replace, compose, and clear correctly and are only applied during the synchronized adapter step.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local MovementSpeedService = require(Adapters:WaitForChild("MovementSpeedService"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local FakePlayer = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("FakePlayer"))

return function()
	describe("MovementSpeedService", function()
		local originalFromId
		local player
		local playerId
		local model
		local humanoid

		beforeEach(function()
			player = FakePlayer.new(300001)
			playerId = PlayerIds.toId(player)
			model = Instance.new("Model")
			humanoid = Instance.new("Humanoid")
			humanoid.WalkSpeed = 20
			humanoid.Parent = model

			originalFromId = PlayerIds.fromId
			PlayerIds.fromId = function(id)
				return if id == playerId then player else originalFromId(id)
			end
		end)

		afterEach(function()
			MovementSpeedService.forget(player)
			PlayerIds.fromId = originalFromId
			model:Destroy()
		end)

		it("applies queued modifier replacement, composition, and clearing during steps", function()
			local state = { players = {} }
			local characters = { [playerId] = model }

			MovementSpeedService.setModifier(player, "Foam", 0.5)
			expect(humanoid.WalkSpeed).to.be.near(20)
			MovementSpeedService.step(state, characters, {})
			expect(humanoid.WalkSpeed).to.be.near(10)

			MovementSpeedService.setModifier(player, "Foam", 0.25)
			MovementSpeedService.setModifier(player, "Boost", 3)
			MovementSpeedService.step(state, characters, {})
			expect(humanoid.WalkSpeed).to.be.near(15)

			MovementSpeedService.clearModifier(player, "Foam")
			MovementSpeedService.step(state, characters, {})
			expect(humanoid.WalkSpeed).to.be.near(60)

			MovementSpeedService.clearModifier(player, "Boost")
			MovementSpeedService.step(state, characters, {})
			expect(humanoid.WalkSpeed).to.be.near(20)
		end)
	end)
end
