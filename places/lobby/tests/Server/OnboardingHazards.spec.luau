--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Course = require(ServerScriptService.Server.Modules.Onboarding.OnboardingCourse)
local RotatingPlatforms = require(ReplicatedStorage.Shared.Game.MapFeatures.RotatingPlatforms)

return function()
	describe("Lobby onboarding hazards", function()
		local arena: Course.Course?

		afterEach(function()
			Course.destroy(arena)
			arena = nil
		end)

		it("builds the authored hazards as valid shared motion and shove sources", function()
			local built = Course.build(999)
			arena = built
			local scriptables = built.model:FindFirstChild("TrainingScriptables")
			expect(scriptables).to.be.ok()
			local motion = (scriptables :: Instance):FindFirstChild("Motion")
			expect(motion).to.be.ok()

			local assembly = built.group:FindFirstChild("Assembly")
			expect(assembly and assembly:IsA("Model")).to.equal(true)
			local platform = RotatingPlatforms.build(assembly :: Model, nil)
			local spinCount = 0
			local rockCount = 0
			for _, rotor in platform.localRotors do
				if rotor.mode == "spin" then
					spinCount += 1
					expect(rotor.period).to.equal(1)
				elseif rotor.mode == "rock" then
					rockCount += 1
				end
				expect(rotor.shove).to.equal(true)
			end
			expect(spinCount).to.equal(1)
			expect(rockCount).to.equal(1)
			expect(#built.hazards).to.equal(4)
			local bumperCount = 0
			for _, hazard in built.hazards do
				if hazard:GetAttribute("Bumper") == true then
					bumperCount += 1
				end
			end
			expect(bumperCount).to.equal(2)
		end)
	end)
end
