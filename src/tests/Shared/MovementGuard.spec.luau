-- Server movement rejection restores the accepted pose without refreshing exploitable movement credit.
--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Shared.Game.Adapters.MovementGuard)
return function()
	describe("Movement acceptance", function()
		local model, root, wall
		beforeEach(function()
			model = Instance.new("Model")
			root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Size = Vector3.new(2, 2, 1)
			root.Anchored = true
			root.CanCollide = false
			root.Parent = model
			model.PrimaryPart = root
			root.CFrame = CFrame.new(20000, 10000, 0)
			model.Parent = workspace
			Guard.reset(root)
		end)
		afterEach(function()
			model:Destroy()
			if wall then
				wall:Destroy()
				wall = nil
			end
		end)
		it("rejects a remote teleport and restores the model to its accepted position", function()
			local original = root.CFrame
			root.CFrame += Vector3.new(100, 0, 0)
			expect(Guard.check(root, { model })).to.equal(false)
			expect((root.Position - original.Position).Magnitude < 0.01).to.equal(true)
			root.CFrame += Vector3.new(100, 0, 0)
			expect(Guard.check(root, { model })).to.equal(false)
			expect((root.Position - original.Position).Magnitude < 0.01).to.equal(true)
		end)
		it("accepts an explicit server teleport as a new movement origin", function()
			root.CFrame += Vector3.new(100, 0, 0)
			Guard.reset(root)
			expect(Guard.check(root, { model })).to.equal(true)
		end)
		it("rejects crossing solid walls even inside the replication burst allowance", function()
			wall = Instance.new("Part")
			wall.Size = Vector3.new(2, 20, 20)
			wall.Anchored = true
			wall.CFrame = root.CFrame + Vector3.new(5, 0, 0)
			wall.Parent = workspace
			local original = root.Position
			task.wait(0.12)
			root.CFrame += Vector3.new(15, 0, 0)
			expect(Guard.check(root, { model })).to.equal(false)
			expect((root.Position - original).Magnitude < 0.01).to.equal(true)
		end)
		it("allows motion granted by a server dash", function()
			Guard.allow(root, "Hammer", 1, 250, 0)
			task.wait(0.12)
			root.CFrame += Vector3.new(24, 0, 0)
			expect(Guard.check(root, { model })).to.equal(true)
		end)
	end)
end
