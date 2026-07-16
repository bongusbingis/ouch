--!nonstrict
-- MovementSpeedService on real Humanoids: multiplicative modifier composition
-- over the captured base speed, restore-on-last-clear, and timed-modifier
-- generation counters cancelling stale restores.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local MovementSpeedService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("MovementSpeedService"))
local Helpers = ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers")
local CharacterFixture = require(Helpers:WaitForChild("CharacterFixture"))
local FakePlayer = require(Helpers:WaitForChild("FakePlayer"))

return function()
	describe("MovementSpeedService", function()
		local player
		local rig
		local humanoid
		local baseSpeed

		beforeEach(function()
			player = FakePlayer.new(300001)
			rig = CharacterFixture.create("SpeedRig")
			player.Character = rig
			humanoid = rig:FindFirstChildOfClass("Humanoid")
			baseSpeed = humanoid.WalkSpeed
		end)

		afterEach(function()
			MovementSpeedService.clearModifier(player, "Foam")
			MovementSpeedService.clearModifier(player, "Boost")
			MovementSpeedService.clearModifier(player, "Timed")
			CharacterFixture.destroy(rig)
		end)

		it("composes named modifiers multiplicatively over the base speed", function()
			MovementSpeedService.setModifier(player, "Foam", 0.5)
			expect(humanoid.WalkSpeed).to.be.near(baseSpeed * 0.5)

			MovementSpeedService.setModifier(player, "Boost", 2)
			expect(humanoid.WalkSpeed).to.be.near(baseSpeed * 0.5 * 2)

			MovementSpeedService.clearModifier(player, "Foam")
			expect(humanoid.WalkSpeed).to.be.near(baseSpeed * 2)
		end)

		it("restores the captured base speed when the last modifier clears", function()
			MovementSpeedService.setModifier(player, "Foam", 0.25)
			MovementSpeedService.clearModifier(player, "Foam")
			expect(humanoid.WalkSpeed).to.be.near(baseSpeed)
		end)

		it("re-setting the same name replaces rather than stacks", function()
			MovementSpeedService.setModifier(player, "Foam", 0.5)
			MovementSpeedService.setModifier(player, "Foam", 0.4)
			expect(humanoid.WalkSpeed).to.be.near(baseSpeed * 0.4)
		end)

		it("ignores modifiers for players without a humanoid", function()
			local ghost = FakePlayer.new(300002)
			MovementSpeedService.setModifier(ghost, "Foam", 0.5)
			MovementSpeedService.clearModifier(ghost, "Foam")
		end)

		it("timed modifiers expire on their own", function()
			MovementSpeedService.applyTimedModifier(player, "Timed", 0.5, 0.1)
			expect(humanoid.WalkSpeed).to.be.near(baseSpeed * 0.5)

			task.wait(0.3)
			expect(humanoid.WalkSpeed).to.be.near(baseSpeed)
		end)

		it("a newer timed application cancels the stale restore", function()
			MovementSpeedService.applyTimedModifier(player, "Timed", 0.5, 0.1)
			MovementSpeedService.applyTimedModifier(player, "Timed", 0.5, 5)

			task.wait(0.3)
			expect(humanoid.WalkSpeed).to.be.near(baseSpeed * 0.5)

			MovementSpeedService.clearModifier(player, "Timed")
			expect(humanoid.WalkSpeed).to.be.near(baseSpeed)
		end)
	end)
end
