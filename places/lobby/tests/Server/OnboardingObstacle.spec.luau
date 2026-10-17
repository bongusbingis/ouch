--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Onboarding = ServerScriptService.Server.Modules.Onboarding
local Arena = require(Onboarding.OnboardingArena)
local Obstacle = require(Onboarding.OnboardingObstacle)
local RotatingPlatforms = require(ReplicatedStorage.Shared.Game.MapFeatures.RotatingPlatforms)

return function()
	describe("Lobby onboarding obstacle", function()
		local arena: Arena.Arena? = nil
		local obstacle: Obstacle.Obstacle? = nil

		afterEach(function()
			Obstacle.destroy(obstacle)
			Arena.destroy(arena)
			obstacle = nil
			arena = nil
		end)

		it("builds the authored sweeper as one valid shared motion and shove source", function()
			local built = Arena.build(999)
			arena = built
			local placed = Obstacle.build(built)
			obstacle = placed
			expect(placed).to.be.ok()
			local motion = (placed :: Obstacle.Obstacle).root:FindFirstChild("Motion")
			expect(motion).to.be.ok()
			local assembly = (motion :: Instance):FindFirstChild("Assembly")
			expect(assembly and assembly:IsA("Model")).to.equal(true)

			local platform = RotatingPlatforms.build(assembly :: Model, nil)
			local spinCount = 0
			for _, rotor in platform.localRotors do
				if rotor.mode == "spin" then
					spinCount += 1
					expect(rotor.period).to.equal(1)
				end
				expect(rotor.shove).to.equal(true)
			end
			expect(spinCount).to.equal(1)
			expect((placed :: Obstacle.Obstacle).bar:GetAttribute("Shove")).to.equal(true)
		end)

		it("leaves the bridge clear once the lesson is over", function()
			local built = Arena.build(998)
			arena = built
			local placed = Obstacle.build(built)
			expect(placed).to.be.ok()
			Obstacle.destroy(placed)
			expect(built.model:FindFirstChild("TrainingHazards")).to.equal(nil)
		end)
	end)
end
