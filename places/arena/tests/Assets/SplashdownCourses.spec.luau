-- Description: In-place spec asserting the authored Splashdown course templates in CourseOrder meet the course contract: an origin, start pads for a full queue, ordered checkpoints with a trigger and pad each, a finish trigger and deck, at least one hazard, door rows where the course needs them, and every piece inside the stadium bowl.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("Gameplay"):WaitForChild("GameModes"))
local Queues = require(Config:WaitForChild("Gameplay"):WaitForChild("Queues"))
local Splashdown = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local MapFeatures = require(Config:WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local AttributeAudit = require(ReplicatedStorage.Shared.Game.MapFeatures.AttributeAudit)
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
		local queueId = GameModes.Modes.Splashdown.Queue
		local queue = Queues.Queues[queueId]
		it("maps Splashdown to an authored full-queue pad capacity", function()
			expect(queue ~= nil).to.equal(true)
			expect(queue.ModeSelection.Strategy).to.equal("Fixed")
			expect(queue.ModeSelection.ModeId).to.equal("Splashdown")
			expect(typeof(queue.MatchCapacity) == "number" and queue.MatchCapacity > 0 and queue.MatchCapacity % 1 == 0).to.equal(
				true
			)
		end)
		for _, courseId in Splashdown.CourseOrder do
			it(`accepts {courseId} authored attributes`, function()
				local model = TestAssets.get(folder, courseId)
				local errors, warnings = AttributeAudit.checkSplashdownCourse(model, Splashdown.Courses[courseId])
				expect(#errors).to.equal(0)
				expect(#warnings).to.equal(0)
			end)
			it(`authors {courseId} to the course contract`, function()
				local model = TestAssets.get(folder, courseId)
				expect(model:IsA("Model")).to.equal(true)
				local origin = TestAssets.get(model, "Origin") :: BasePart
				expect(origin:IsA("BasePart")).to.equal(true)
				TestAssets.get(model, "Scriptables")
				TestAssets.get(model, "Geometry")

				local pads = TestAssets.get(model, "Start", "Pads")
				expect(partCount(pads) >= queue.MatchCapacity).to.equal(true)

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
		it("keeps both seesaw asset variants builder-ready for native activation", function()
			local counts = { obstacle_25_001 = 0, obstacle_11_001 = 0 }
			for _, model in folder:GetChildren() do
				local errors = AttributeAudit.checkSplashdownCourse(model, Splashdown.Courses[model.Name] or {})
				for _, message in errors do
					expect(string.find(string.lower(message), "seesaw", 1, true)).to.equal(nil)
				end
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") and part:GetAttribute("Seesaw") == true then
						local source = part:GetAttribute("SourceAsset")
						counts[source] = (counts[source] or 0) + 1
						expect(part.Anchored).to.equal(true)
						expect(part.Parent:IsA("BasePart") and part.Parent.Anchored).to.equal(true)
						expect(part:GetAttribute("SeesawAxis")).to.equal("X")
					end
				end
			end
			expect(counts.obstacle_25_001 > 0).to.equal(true)
			expect(counts.obstacle_11_001 > 0).to.equal(true)
		end)
		it("accepts profile-specific rotor fields and rejects malformed periods", function()
			local course = Instance.new("Model")
			course.Name = "ProfileContract"
			local scriptables = Instance.new("Folder")
			scriptables.Name = "Scriptables"
			scriptables.Parent = course
			local motion = Instance.new("Folder")
			motion.Name = "Motion"
			motion.Parent = scriptables
			local spin = Instance.new("Part")
			spin.Name = "Spin"
			spin.Anchored = true
			spin:SetAttribute("Rotor", "spin")
			spin:SetAttribute("RotorAxis", "Y")
			spin:SetAttribute("RotorSpeed", 90)
			spin.Parent = motion
			local piston = Instance.new("Part")
			piston.Name = "Piston"
			piston.Anchored = true
			piston:SetAttribute("Rotor", "slide")
			piston:SetAttribute("RotorAxis", "Z")
			piston:SetAttribute("RotorProfile", "piston")
			piston:SetAttribute("PistonPeriod", 2)
			piston:SetAttribute("PistonExtendStuds", 5)
			piston.Parent = motion
			local errors = AttributeAudit.checkSplashdownCourse(course, {})
			expect(#errors).to.equal(0)
			spin:SetAttribute("RotorPeriod", 0.04)
			errors = AttributeAudit.checkSplashdownCourse(course, {})
			expect(table.concat(errors, "\n"):find("RotorPeriod", 1, true) ~= nil).to.equal(true)
			spin:SetAttribute("RotorPeriod", nil)
			piston:SetAttribute("PistonPeriod", 0.09)
			errors = AttributeAudit.checkSplashdownCourse(course, {})
			expect(table.concat(errors, "\n"):find("PistonPeriod", 1, true) ~= nil).to.equal(true)
			course:Destroy()
		end)
	end)
end
