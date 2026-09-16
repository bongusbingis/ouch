-- Description: Engine-side acceptance spec for declaratively built Splashdown courses. It builds each selected CourseSpec through CourseBuilder into an isolated Workspace container, runs the real CourseQA audit against it with actual raycasts, and asserts the HANDOFF section 8 contracts that can be measured without a driven playtest. Selection comes from ServerStorage.SplashdownQASelection when the run-course-qa probe sets it, and defaults to the pilot otherwise.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Splashdown = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Splashdown")
local CourseBuilder = require(Splashdown:WaitForChild("CourseBuilder"))
local CourseQA = require(Splashdown:WaitForChild("CourseQA"))

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
		end)
	end
end
