--!nonstrict
local PhysicsService = game:GetService("PhysicsService")
local Collision = require(game.ServerScriptService.Server.Modules.MapFeatures.SeesawCollision)

return function()
	describe("Seesaw character collision", function()
		local models = {}
		afterEach(function()
			Collision.stop()
			for _, model in models do
				model:Destroy()
			end
			table.clear(models)
		end)

		local function character(name)
			local model = Instance.new("Model")
			model.Name = name
			model.Parent = workspace
			table.insert(models, model)
			local body = Instance.new("Part")
			body.Name = "Body"
			body.Parent = model
			return model, body
		end

		it("collides only with character groups and preserves ordinary map contact", function()
			Collision.start()
			local model, body = character("FirstCharacter")
			Collision.configureCharacter(model)
			expect(body.CollisionGroup).to.equal("SeesawCharacter_Default")
			expect(PhysicsService:CollisionGroupsAreCollidable(Collision.PLANK_GROUP, body.CollisionGroup)).to.equal(
				true
			)
			expect(PhysicsService:CollisionGroupsAreCollidable(Collision.PLANK_GROUP, "Default")).to.equal(false)
			expect(PhysicsService:CollisionGroupsAreCollidable(Collision.PLANK_GROUP, Collision.PLANK_GROUP)).to.equal(
				false
			)
			for _, group in PhysicsService:GetRegisteredCollisionGroups() do
				local isCharacter = string.sub(group.name, 1, #"SeesawCharacter_") == "SeesawCharacter_"
				expect(PhysicsService:CollisionGroupsAreCollidable(Collision.PLANK_GROUP, group.name)).to.equal(
					isCharacter
				)
			end
			expect(PhysicsService:CollisionGroupsAreCollidable(body.CollisionGroup, "Default")).to.equal(true)
		end)

		it("configures accessories added later and cleans up successive characters", function()
			Collision.start()
			local first, body = character("FirstCharacter")
			Collision.configureCharacter(first)
			local accessory = Instance.new("Accessory")
			accessory.Parent = first
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Parent = accessory
			expect(handle.CollisionGroup).to.equal("SeesawCharacter_Default")
			local second, replacement = character("RespawnedCharacter")
			Collision.configureCharacter(second)
			expect(replacement.CollisionGroup).to.equal("SeesawCharacter_Default")
			Collision.stop()
			expect(body.CollisionGroup).to.equal("Default")
			expect(handle.CollisionGroup).to.equal("Default")
			expect(replacement.CollisionGroup).to.equal("Default")
		end)
		it("lets support rays see a plank without enabling Default contact", function()
			Collision.start()
			local model, root = character("RayCharacter")
			Collision.configureCharacter(model)
			root.Position = Vector3.new(0, 1006, 0)
			local plank = Instance.new("Part")
			plank.Size = Vector3.new(10, 1, 10)
			plank.Position = Vector3.new(0, 1000, 0)
			plank.Anchored = true
			plank.CollisionGroup = Collision.PLANK_GROUP
			plank.Parent = workspace
			local ray = RaycastParams.new()
			ray.FilterType = Enum.RaycastFilterType.Exclude
			ray.FilterDescendantsInstances = { model }
			ray.RespectCanCollide = true
			ray.CollisionGroup = root.CollisionGroup
			expect(workspace:Raycast(root.Position, -Vector3.yAxis * 10, ray).Instance).to.equal(plank)
			ray.CollisionGroup = "Default"
			expect(workspace:Raycast(root.Position, -Vector3.yAxis * 10, ray)).to.equal(nil)
			plank:Destroy()
		end)
	end)
end
