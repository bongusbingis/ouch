-- Description: Engine-side acceptance spec for declaratively built Splashdown courses. It builds each selected CourseSpec through CourseBuilder into an isolated Workspace container, runs the real CourseQA audit against it with actual raycasts, and asserts the HANDOFF section 8 contracts that can be measured without a driven playtest. Selection comes from ServerStorage.SplashdownQASelection when the run-course-qa probe sets it, and defaults to the pilot otherwise.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Splashdown = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Splashdown")
local CourseBuilder = require(Splashdown:WaitForChild("CourseBuilder"))
local CourseQA = require(Splashdown:WaitForChild("CourseQA"))
local SplashdownConfig = require(ReplicatedStorage:WaitForChild("Config").Gameplay.Splashdown)
local DoorRows = require(game:GetService("ServerScriptService").Server.Modules.Splashdown.DoorRows)
local BeachBalls = require(game:GetService("ServerScriptService").Server.Modules.MapFeatures.BeachBalls)
local MapFeatures = require(ReplicatedStorage:WaitForChild("Config").Gameplay.MapFeatures)

local function selectedIds(): { string }
	local selection = ServerStorage:FindFirstChild("SplashdownQASelection")
	if selection and selection:IsA("StringValue") and selection.Value ~= "" then
		local ids = {}
		for id in selection.Value:gmatch("[^,]+") do
			table.insert(ids, (id:gsub("^%s*(.-)%s*$", "%1")))
		end
		return ids
	end
	return { "BallBarrage" }
end

local function authoringSources()
	local root = ServerStorage:FindFirstChild("SplashdownAuthoringSources")
	if not root then
		return nil
	end
	local kit = root:FindFirstChild("Kit")
	local arena = root:FindFirstChild("ArenaSources")
	local wall = arena and arena:FindFirstChild("BoundaryWall")
	if not kit or not wall then
		return nil
	end
	return { Kit = kit, BoundaryWall = wall }
end

return function()
	for _, courseId in selectedIds() do
		describe(courseId, function()
			local container, model, report, qa

			beforeAll(function()
				local sources = authoringSources()
				-- Without the section 4 source export there is nothing to build
				-- from. Fail loudly rather than reporting an empty pass.
				assert(sources, "ServerStorage.SplashdownAuthoringSources is missing; run the section 4 export first")
				local spec = require(Splashdown:WaitForChild("CourseSpecs"):WaitForChild(courseId))
				model, report = CourseBuilder.build(spec, sources)
				container = Instance.new("Folder")
				container.Name = "SplashdownQAIsolation_" .. courseId
				container.Parent = Workspace
				model.Parent = container
				qa = CourseQA.check(model, spec, CourseQA.DefaultCalibration, {
					Route = report.Route,
					SpecHash = report.SpecHash,
				})
			end)

			afterAll(function()
				if container then
					container:Destroy()
				end
			end)

			it("builds with no attribute, route or bounds errors", function()
				expect(#report.AttributeErrors).to.equal(0)
				expect(#report.RouteErrors).to.equal(0)
				expect(#report.Bounds.Violations).to.equal(0)
				expect(report.Ok).to.equal(true)
			end)

			it("keeps every part corner within 600 studs of Origin", function()
				expect(report.Bounds.MaxCornerDistance <= 600).to.equal(true)
			end)

			it("keeps geometry centres within 380 and the route within its BoundsRadius", function()
				expect(report.Bounds.MaxGeometryCenterRadius <= 380).to.equal(true)
				expect(report.Bounds.MaxRouteRadius <= 300).to.equal(true)
			end)

			it("keeps the static route envelope inside the -30..90 band", function()
				expect(report.Bounds.RouteMinY >= -30).to.equal(true)
				expect(report.Bounds.RouteMaxY <= 90).to.equal(true)
			end)

			it("fits every beat between 0.85 and 1.15 of its length target", function()
				for _, beat in report.Beats do
					expect(beat.Ratio >= 0.85).to.equal(true)
					expect(beat.Ratio <= 1.15).to.equal(true)
				end
			end)

			it("holds the total route arclength inside the 800-1000 stud window", function()
				expect(report.RouteLength >= 800).to.equal(true)
				expect(report.RouteLength <= 1000).to.equal(true)
			end)

			it("rebuilds deterministically to the same spec hash", function()
				local spec = require(Splashdown:WaitForChild("CourseSpecs"):WaitForChild(courseId))
				local second, secondReport = CourseBuilder.build(spec, authoringSources())
				expect(secondReport.SpecHash).to.equal(report.SpecHash)
				second:Destroy()
			end)

			it("exposes exactly 30 start pads, ordered checkpoints and one finish", function()
				expect(qa.Counts.StartPads).to.equal(30)
				expect(qa.Counts.Checkpoints >= 1).to.equal(true)
				expect(model:GetAttribute("CheckpointCount")).to.equal(qa.Counts.Checkpoints)
			end)

			it("carries the 24-wall boundary ring at radius 390", function()
				expect(qa.Counts.BoundaryWalls).to.equal(24)
			end)

			it("samples a real walkable surface graph rather than trusting the spec", function()
				expect(qa.Counts.SurfaceCells > 0).to.equal(true)
				expect(qa.Counts.GraphNodes > 0).to.equal(true)
				expect(qa.Counts.GraphEdges > 0).to.equal(true)
			end)

			it("reports no QA errors", function()
				if #qa.Errors > 0 then
					error(table.concat(qa.Errors, " | "), 0)
				end
				expect(#qa.Errors).to.equal(0)
			end)

			it("never reports an overall PASS while live-playtest checks are outstanding", function()
				expect(#qa.NotRun > 0).to.equal(true)
				expect(qa.Status).never.to.equal("PASS")
			end)

			-- Regression for two CoursePresets defects the Door Dash build exposed.
			it("leaves no original source name on any part", function()
				local leaked = {}
				for _, instance in model:GetDescendants() do
					if instance:IsA("BasePart") then
						local name = instance.Name
						for _, prefix in
							{
								"obstacle_",
								"platform_",
								"door_",
								"trampoline_",
								"box_",
								"slide_",
								"arch_",
								"propeller_",
								"water_platform_",
								"octagon_",
								"ball_",
							}
						do
							if string.sub(name, 1, #prefix) == prefix then
								table.insert(leaked, instance:GetFullName())
							end
						end
					end
				end
				if #leaked > 0 then
					error(`{#leaked} parts kept a source name, e.g. {leaked[1]}`, 0)
				end
				expect(#leaked).to.equal(0)
			end)

			it("clones each declared sub-part once instead of doubling a nested assembly", function()
				-- A duplicated sub-part lands exactly on top of the original, so two
				-- parts of one piece sharing a position is the signature to catch.
				local seen: { [string]: string } = {}
				local doubled = {}
				for _, instance in model:GetDescendants() do
					if instance:IsA("BasePart") and instance:GetAttribute("PieceId") then
						local key = string.format(
							"%s|%d|%d|%d",
							tostring(instance:GetAttribute("PieceId")),
							math.round(instance.Position.X * 100),
							math.round(instance.Position.Y * 100),
							math.round(instance.Position.Z * 100)
						)
						if seen[key] then
							table.insert(doubled, `{instance.Name} over {seen[key]}`)
						end
						seen[key] = instance.Name
					end
				end
				if #doubled > 0 then
					error(`{#doubled} coincident sub-parts, e.g. {doubled[1]}`, 0)
				end
				expect(#doubled).to.equal(0)
			end)

			it("puts door slabs where the door kit can actually see them", function()
				-- DoorRows.resolve and MapFeatureService both walk the folder's
				-- IMMEDIATE BasePart children: a slab inside a holder Model resolves as
				-- no rows at all, and every door would stay permanently solid.
				local doors = model:FindFirstChild("Scriptables") and model.Scriptables:FindFirstChild("Doors")
				local slabs = 0
				local nested = 0
				for _, child in (doors and doors:GetChildren() or {}) do
					if child:IsA("BasePart") then
						slabs += 1
						expect(typeof(child:GetAttribute("DoorRow"))).to.equal("number")
						expect(typeof(child:GetAttribute("DoorIndex"))).to.equal("number")
					else
						nested += 1
					end
				end
				expect(nested).to.equal(0)
				local rows = DoorRows.resolve(doors)
				local configured = SplashdownConfig.Courses[courseId] and SplashdownConfig.Courses[courseId].Doors
				if configured then
					expect(#rows > 0).to.equal(true)
					for _, row in rows do
						expect(#row).to.equal(configured.PerRow)
					end
				else
					expect(#rows).to.equal(if slabs > 0 then #rows else 0)
				end
			end)

			-- The door defect above was silent: the build succeeded, the audit passed,
			-- and the kit still could not see a single slab. Beach balls have exactly the
			-- same failure mode, so this drives the REAL BeachBalls kit over the built
			-- model and checks what the kit ends up owning, rather than trusting that a
			-- ball looks present in a preview.
			it("hands its beach balls to the kit as real unanchored server-owned physics", function()
				local scriptables = model:FindFirstChild("Scriptables")
				local rotating = scriptables and scriptables:FindFirstChild("Rotating")
				local groups = {}
				for _, group in (rotating and rotating:GetChildren() or {}) do
					table.insert(groups, group)
				end

				local authored = {}
				for _, instance in model:GetDescendants() do
					if instance:IsA("BasePart") and instance:GetAttribute(MapFeatures.Attributes.BeachBall) == true then
						table.insert(authored, instance)
						-- HANDOFF 8.1: no unanchored template asset; the live ball is the
						-- runtime exception, so the authored one must still be anchored.
						expect(instance.Anchored).to.equal(true)
						-- 02-kits.md: "do not also give them a kinematic motion owner."
						expect(instance:GetAttribute(MapFeatures.Attributes.Rotor)).to.equal(nil)
						-- The kit walks Rotating/<group>/Assembly descendants, so a ball
						-- parked anywhere else is invisible to it however present it looks.
						local assembly = instance:FindFirstAncestor("Assembly")
						expect(assembly ~= nil and assembly:IsA("Model")).to.equal(true)
						expect(assembly.Parent ~= nil and assembly.Parent.Parent == rotating).to.equal(true)
					end
				end

				BeachBalls.forget(nil)
				BeachBalls.tickWorld({ instances = groups, now = os.clock(), deltaTime = 1 / 60 })
				local live = BeachBalls.active()
				expect(#live).to.equal(#authored)
				for _, ball in live do
					expect(ball.Anchored).to.equal(false)
					expect(ball.CanCollide).to.equal(true)
					-- SetNetworkOwner(nil) is server ownership; GetNetworkOwner returns nil
					-- for it AND for an anchored part, so the unanchored assertion above is
					-- what makes this one mean something.
					expect(ball:GetNetworkOwner()).to.equal(nil)
					expect(ball.Parent ~= nil and ball.Parent.Name).to.equal("BeachBalls")
					expect(ball:IsDescendantOf(model)).to.equal(true)
				end
				BeachBalls.forget(nil)
			end)
		end)
	end
end
