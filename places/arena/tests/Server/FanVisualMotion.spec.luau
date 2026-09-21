--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RotatingPlatforms = require(ReplicatedStorage.Shared.Game.MapFeatures.RotatingPlatforms)

return function()
	describe("Fan blade motion ownership", function()
		local function part(name: string, parent: Instance, frame: CFrame): Part
			local result = Instance.new("Part")
			result.Name = name
			result.Anchored = true
			result.CFrame = frame
			result.Parent = parent
			return result
		end

		it("keeps Arena and Splashdown blades out of rotors while preserving other motion", function()
			local assembly = Instance.new("Model")
			local origin = part("Origin", assembly, CFrame.identity)
			origin:SetAttribute("RotationSpeed", 0)
			local arenaBase = part("propeller_trampoline_1_001.001", assembly, CFrame.identity)
			local arenaBlade = part("propeller_trampoline_2_001.001", arenaBase, CFrame.new(0, 4, 0))
			local courseBase = part("CourseFan", assembly, CFrame.new(20, 0, 0))
			courseBase:SetAttribute("Fan", true)
			local courseBlade = part("CourseBlade", courseBase, CFrame.new(20, 4, 0))
			courseBlade:SetAttribute("FanBlade", true)
			local spinner = part("obstacle_6_001.001", assembly, CFrame.new(40, 0, 0))
			local otherRotor = part("OtherRotor", assembly, CFrame.new(60, 0, 0))
			otherRotor:SetAttribute("Rotor", "spin")
			otherRotor:SetAttribute("RotorAxis", "Y")
			otherRotor:SetAttribute("RotorSpeed", 90)

			local platform = RotatingPlatforms.build(origin, assembly)
			local owned = {}
			for _, rotor in platform.localRotors do
				owned[rotor.part] = true
			end
			expect(owned[arenaBlade]).to.equal(nil)
			expect(owned[courseBlade]).to.equal(nil)
			expect(owned[spinner]).to.equal(true)
			expect(owned[otherRotor]).to.equal(true)

			local arenaRest = arenaBlade.CFrame
			local courseRest = courseBlade.CFrame
			RotatingPlatforms.applyAt(platform, 1)
			expect(arenaBlade.CFrame).to.equal(arenaRest)
			expect(courseBlade.CFrame).to.equal(courseRest)
			assembly:Destroy()
		end)
	end)
end
