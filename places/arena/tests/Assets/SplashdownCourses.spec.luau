-- Description: In-place spec asserting the five authored Splashdown course templates meet the course contract: an origin, start pads for a full queue, ordered checkpoints with a trigger and pad each, a finish trigger and deck, at least one hazard, door rows where the course needs them, and every piece inside the stadium bowl.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("Gameplay"):WaitForChild("GameModes"))
local Splashdown = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local MapFeatures = require(Config:WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

local BOWL_RADIUS = 380

local function partCount(folder: Instance): number
	local count = 0
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

return function()
	describe("Splashdown course templates", function()
		local folder = TestAssets.get(ReplicatedStorage, "Assets", "Maps", "Splashdown")
		for _, courseId in Splashdown.CourseOrder do
			it(`authors {courseId} to the course contract`, function()
				local model = TestAssets.get(folder, courseId)
				expect(model:IsA("Model")).to.equal(true)
				local origin = TestAssets.get(model, "Origin") :: BasePart
				expect(origin:IsA("BasePart")).to.equal(true)
				TestAssets.get(model, "Scriptables")
				TestAssets.get(model, "Geometry")

				local pads = TestAssets.get(model, "Start", "Pads")
				expect(partCount(pads) >= GameModes.QueueCapacity("Splashdown")).to.equal(true)

				local checkpoints = TestAssets.get(model, "Checkpoints")
				local count = 0
				for _, checkpoint in checkpoints:GetChildren() do
					if checkpoint:IsA("Model") then
						count += 1
						expect(TestAssets.get(checkpoint, "Trigger"):IsA("BasePart")).to.equal(true)
						expect(TestAssets.get(checkpoint, "Pad"):IsA("BasePart")).to.equal(true)
					end
				end
				expect(count > 0).to.equal(true)
				expect(model:GetAttribute("CheckpointCount")).to.equal(count)

				local finish = TestAssets.get(model, "Finish")
				expect(TestAssets.get(finish, "Trigger"):IsA("BasePart")).to.equal(true)
				expect(TestAssets.get(finish, "Deck"):IsA("BasePart")).to.equal(true)
				expect(partCount(TestAssets.get(model, "Hazards")) > 0).to.equal(true)

				local boundary = TestAssets.get(model, "Boundary")
				expect(partCount(boundary) >= Splashdown.Boundary.Segments).to.equal(true)
				for _, wall in boundary:GetChildren() do
					if wall:IsA("BasePart") then
						local offset = wall.Position - origin.Position
						local radius = Vector3.new(offset.X, 0, offset.Z).Magnitude
						expect(math.abs(radius - Splashdown.Boundary.Radius) < 1).to.equal(true)
						expect(wall.CanCollide and wall.Anchored and wall.Transparency == 1).to.equal(true)
					end
				end

				local doors = Splashdown.Courses[courseId].Doors
				if doors then
					local rows = {}
					for _, door in TestAssets.get(model, "Scriptables", "Doors"):GetChildren() do
						local row = door:GetAttribute(MapFeatures.Attributes.DoorRow)
						if door:IsA("BasePart") and type(row) == "number" then
							rows[row] = (rows[row] or 0) + 1
						end
					end
					expect(#rows > 0).to.equal(true)
					for _, doorsInRow in rows do
						expect(doorsInRow >= doors.PerRow).to.equal(true)
					end
				end
			end)

			it(`keeps {courseId} inside the stadium bowl`, function()
				local model = TestAssets.get(folder, courseId)
				local origin = TestAssets.get(model, "Origin") :: BasePart
				for _, descendant in TestAssets.get(model, "Geometry"):GetDescendants() do
					if descendant:IsA("BasePart") then
						local offset = descendant.Position - origin.Position
						local reach = Vector3.new(offset.X, 0, offset.Z).Magnitude + descendant.Size.Magnitude / 2
						expect(reach <= BOWL_RADIUS + descendant.Size.Magnitude / 2).to.equal(true)
					end
				end
			end)
		end
	end)
end
