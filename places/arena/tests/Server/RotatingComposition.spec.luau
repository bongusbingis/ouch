-- Engine contract tests: parent-local transforms, unique ownership and derivatives.
--!nonstrict
local R = require(game.ReplicatedStorage.Shared.Game.MapFeatures.RotatingPlatforms)
return function()
	describe("Rotating composition", function()
		local model, origin
		local function part(name, cf, parent, mode, axis, value)
			local p = Instance.new("Part")
			p.Name = name
			p.CFrame = cf
			p.Anchored = true
			p.Parent = parent
			if mode then
				p:SetAttribute("Rotor", mode)
				p:SetAttribute("RotorAxis", axis)
				p:SetAttribute(if mode == "spin" then "RotorSpeed" else "RotorAmplitude", value)
				p:SetAttribute("RotorPeriod", 4)
			end
			return p
		end
		beforeEach(function()
			model = Instance.new("Model")
			model.Name = "Assembly"
			origin = Instance.new("Part")
			origin:SetAttribute("RotationSpeed", 0)
		end)
		afterEach(function()
			model:Destroy()
			origin:Destroy()
		end)
		it("moves a spinning child with its sliding parent", function()
			local parent = part("Mover", CFrame.identity, model, "slide", "X", 10)
			local child = part("Sweeper", CFrame.new(0, 3, 0), parent, "spin", "Y", 90)
			local tip = part("Tip", CFrame.new(4, 3, 0), child)
			local platform = R.build(origin, model)
			R.applyAt(platform, 1)
			expect((parent.Position - Vector3.new(10, 0, 0)).Magnitude < 1e-4).to.equal(true)
			expect((child.Position - Vector3.new(10, 3, 0)).Magnitude < 1e-4).to.equal(true)
			expect((tip.Position - Vector3.new(10, 3, -4)).Magnitude < 1e-4).to.equal(true)
		end)
		it("turns a hammer axle with its rotating hub", function()
			local hub = part("Hub", CFrame.identity, model, "spin", "Y", 90)
			local hammer = part("Hammer", CFrame.new(8, 2, 0), hub, "rock", "Z", 45)
			local tip = part("Tip", CFrame.new(8, -4, 0), hammer)
			local platform = R.build(origin, model)
			R.applyAt(platform, 1)
			local expected = CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(8, 2, 0) * CFrame.Angles(0, 0, math.pi / 4)
			expect((hammer.Position - expected.Position).Magnitude < 1e-4).to.equal(true)
			expect((tip.Position - expected:PointToWorldSpace(Vector3.new(0, -6, 0))).Magnitude < 1e-4).to.equal(true)
		end)
		it("assigns each moving descendant to only its nearest rotor", function()
			local parent = part("Parent", CFrame.identity, model, "slide", "X", 10)
			local child = part("Child", CFrame.new(0, 3, 0), parent, "spin", "Y", 90)
			local tip = part("Tip", CFrame.new(4, 3, 0), child)
			local platform = R.build(origin, model)
			local owners = {}
			for _, rotor in platform.localRotors do
				owners[rotor.part] = (owners[rotor.part] or 0) + 1
				for _, f in rotor.followers do
					owners[f.part] = (owners[f.part] or 0) + 1
				end
			end
			expect(owners[parent]).to.equal(1)
			expect(owners[child]).to.equal(1)
			expect(owners[tip]).to.equal(1)
		end)
		it("includes ancestor translation and angular velocity in contact speed", function()
			local parent = part("Parent", CFrame.identity, model, "slide", "X", 10)
			part("Child", CFrame.new(0, 3, 0), parent, "spin", "Y", 90)
			local platform = R.build(origin, model)
			local childRotor
			for _, r in platform.localRotors do
				if r.part.Name == "Child" then
					childRotor = r
				end
			end
			local t, h = 0.4, 1e-3
			local localPoint = Vector3.new(4, 0, 0)
			local function point(at)
				return R.rotorPoseAt(platform, childRotor, at):PointToWorldSpace(localPoint)
			end
			local numeric = (point(t + h) - point(t - h)) / (2 * h)
			expect((numeric - R.surfaceVelocityAt(platform, childRotor, point(t), t)).Magnitude < 0.02).to.equal(true)
		end)
		it("keeps an ordinary non-nested rotor's pose unchanged", function()
			local p = part("Simple", CFrame.new(5, 6, 7), model, "rock", "X", 30)
			local platform = R.build(origin, model)
			R.applyAt(platform, 1)
			local expected = CFrame.new(5, 6, 7) * CFrame.Angles(math.pi / 6, 0, 0)
			expect((p.CFrame.Position - expected.Position).Magnitude < 1e-5).to.equal(true)
			expect((p.CFrame.UpVector - expected.UpVector).Magnitude < 1e-5).to.equal(true)
		end)
		it("compiles asymmetric hammer and piston profiles from attributes", function()
			local hammer = part("Hammer", CFrame.identity, model, "rock", "Z", 45)
			hammer:SetAttribute("RotorProfile", "hammer")
			hammer:SetAttribute("WindupSeconds", 2)
			hammer:SetAttribute("StrikeSeconds", 0.25)
			local piston = part("Piston", CFrame.new(20, 0, 0), model, "slide", "X", 0)
			piston:SetAttribute("RotorProfile", "piston")
			piston:SetAttribute("PistonPeriod", 4)
			piston:SetAttribute("PistonExtendStuds", 12)
			piston:SetAttribute("HoldSeconds", 1)
			local platform = R.build(origin, model)
			R.applyAt(platform, 0.8)
			expect(math.abs(piston.Position.X - 32) < 1e-4).to.equal(true)
			R.applyAt(platform, 2)
			expect((hammer.CFrame.UpVector - CFrame.Angles(0, 0, math.pi / 4).UpVector).Magnitude < 1e-4).to.equal(true)
		end)
		it("does not move a runtime physics ball after it leaves an assembly", function()
			local parent = part("Parent", CFrame.identity, model, "spin", "Y", 90)
			local ball = part("Ball", CFrame.new(5, 0, 0), parent)
			local platform = R.build(origin, model)
			ball.Parent = origin
			ball.CFrame = CFrame.new(50, 20, 30)
			R.applyAt(platform, 1)
			expect(ball.Position).to.equal(Vector3.new(50, 20, 30))
		end)
	end)
end
