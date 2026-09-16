-- Install as a normal temporary Script under ServerScriptService.Server.Scripts
-- (Rojo syncs places/arena/server/Scripts) and press Play. HANDOFF.md section 10
-- step 6. It builds each selected course from its declarative spec through the
-- same CourseBuilder.build call CourseAuthoring.stage makes, runs the real
-- CourseQA audit against it with actual raycasts, publishes the full report to
-- docs/splashdown/evidence/courses/<Id>/qa.json, and then bootstraps the real
-- TestEZ runner over SplashdownQA.spec so the section 8 assertions run too.
-- Results also land in ServerStorage.SplashdownCourseQAResults. Delete this
-- script before committing.
assert(game:GetService("RunService"):IsStudio(), "Studio only")

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local SELECTED_IDS = { "WhirlpoolWaltz", "BallBarrage" }
-- Cross-course checks (HANDOFF 8.4 override 2) are scored over every staged
-- spec, not just the selected one, so a violation fails the set rather than one
-- course. These are the specs that exist.
local ALL_IDS = { "BallBarrage", "WhirlpoolWaltz" }

-- See run-course-routes.server.luau for why this sink exists: a Script in Play
-- has the Network capability the Assistant's execute_luau VM does not, so it can
-- hand a large measured report straight to the repository.
local SINK = "http://127.0.0.1:34875/"
local function publish(path: string, data: any): string
	local ok, response = pcall(function()
		return HttpService:PostAsync(
			SINK,
			HttpService:JSONEncode({ path = path, data = data }),
			Enum.HttpContentType.ApplicationJson
		)
	end)
	return if ok then tostring(response) else "sink unavailable: " .. tostring(response)
end

local Splashdown = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Splashdown")
local CourseBuilder = require(Splashdown:WaitForChild("CourseBuilder")) :: any
local CourseQA = require(Splashdown:WaitForChild("CourseQA")) :: any

local existingSelection = ServerStorage:FindFirstChild("SplashdownQASelection")
local selection: StringValue
if existingSelection and existingSelection:IsA("StringValue") then
	selection = existingSelection
else
	selection = Instance.new("StringValue")
	selection.Name = "SplashdownQASelection"
	selection.Parent = ServerStorage
end
selection.Value = table.concat(SELECTED_IDS, ",")

local result = Instance.new("StringValue")
result.Name = "SplashdownCourseQAResults"
result.Value = "running"
result.Parent = ServerStorage

local function sources()
	local root = ServerStorage:FindFirstChild("SplashdownAuthoringSources")
	assert(root, "[run-course-qa] ServerStorage.SplashdownAuthoringSources is missing")
	local kit = root:FindFirstChild("Kit")
	local arena = root:FindFirstChild("ArenaSources")
	local wall = arena and arena:FindFirstChild("BoundaryWall")
	assert(kit and wall, "[run-course-qa] SplashdownAuthoringSources is incomplete")
	return { Kit = kit, BoundaryWall = wall }
end

local function specFor(id: string)
	local module = Splashdown:WaitForChild("CourseSpecs"):FindFirstChild(id)
	assert(module and module:IsA("ModuleScript"), `[run-course-qa] no CourseSpecs module named "{id}"`)
	return require(module) :: any
end

local published: { string } = {}

local ok, answer = xpcall(function()
	local injected = sources()
	local allSpecs = {}
	for _, id in ALL_IDS do
		allSpecs[id] = specFor(id)
	end

	local summaries = {}
	for _, courseId in SELECTED_IDS do
		local spec = specFor(courseId)
		local model, report = CourseBuilder.build(spec, injected)
		local container = Instance.new("Folder")
		container.Name = "SplashdownQAIsolation_" .. courseId
		container.Parent = Workspace
		model.Parent = container

		local qa = CourseQA.check(model, spec, CourseQA.DefaultCalibration, {
			Route = report.Route,
			SpecHash = report.SpecHash,
			AllSpecs = allSpecs,
		})
		container:Destroy()

		published[#published + 1] = publish("courses/" .. courseId .. "/qa.json", {
			courseId = qa.CourseId,
			specHash = qa.SpecHash,
			sourceHash = qa.SourceHash,
			placeId = qa.PlaceId,
			calibration = qa.Calibration,
			sampleResolution = qa.SampleResolution,
			testTime = qa.TestTime,
			status = qa.Status,
			errors = qa.Errors,
			warnings = qa.Warnings,
			notRun = qa.NotRun,
			counts = qa.Counts,
			findings = qa.Findings,
			encounters = qa.Encounters,
			crossCourseSpecs = ALL_IDS,
			buildSummary = {
				partCount = report.PartCount,
				routeLength = report.RouteLength,
				checkpointCount = report.CheckpointCount,
				guideDeviation = report.GuideDeviation,
				guideLength = report.GuideLength,
				attributeErrors = report.AttributeErrors,
				routeErrors = report.RouteErrors,
				boundsViolations = report.Bounds.Violations,
			},
			method = "CourseQA.check against a real Workspace clone built from the declarative spec in a Studio Play session, by run-course-qa.server.luau",
		})

		table.insert(summaries, {
			courseId = courseId,
			status = qa.Status,
			errors = #qa.Errors,
			warnings = #qa.Warnings,
			notRun = #qa.NotRun,
			counts = qa.Counts,
			errorList = qa.Errors,
		})
	end

	local folder = Instance.new("Folder")
	folder.Name = "SplashdownIsolatedCourseQA"
	folder.Parent = ServerStorage
	ServerStorage.Tests.Assets:WaitForChild("SplashdownQA.spec"):Clone().Parent = folder
	local TestEZ = require(ReplicatedStorage.Packages.testEZ) :: any
	local run = TestEZ.TestBootstrap:run({ folder }, TestEZ.Reporters.TextReporter)
	folder:Destroy()

	return {
		selected = SELECTED_IDS,
		crossCourseSpecs = ALL_IDS,
		summaries = summaries,
		passed = run.successCount,
		failed = run.failureCount,
		skipped = run.skippedCount,
		errors = run.errors,
	}
end, debug.traceback)

result.Value = HttpService:JSONEncode({ ok = ok, result = answer })
print("[run-course-qa] ok=" .. tostring(ok) .. " published=" .. table.concat(published, " ; "))
