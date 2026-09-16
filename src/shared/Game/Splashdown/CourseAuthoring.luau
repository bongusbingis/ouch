-- Name: CourseAuthoring.luau
-- Author: Jack C.
-- Description: Edit-time entry point for the declarative course pipeline (HANDOFF.md section 5.1.11-5.1.14): stages built courses into ServerStorage.SplashdownStaging under an owned BuildVersion marker, puts a single unregistered preview at the live MapOrigin for fixed-camera captures and restores exactly what it moved, and gates promotion behind verified hashes. Nothing here tags a ScriptableRoot, edits CourseOrder, or touches the live templates outside promote().
-- Created: 2026-09-15

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local CourseBuilder = require(script.Parent.CourseBuilder)

local CourseAuthoring = {}

local STAGING_NAME = "SplashdownStaging"
-- 5.1.12 has stage() print its JSON summary, but the Studio Command Bar is the
-- only place stage() can run and its Output cannot be read back reliably from an
-- assistant session. The FULL BuildReport for every staged course is therefore
-- also parked in this StringValue, where a plain instance read can collect it:
-- beat arclengths and ratios, bounds, route steps, guide/hairpin measurements.
local REPORT_NAME = "SplashdownStageReport"
local PREVIEW_NAME = "SplashdownPreview"
local OWNER_MARKER = "BuildVersion"
local TEMPLATES_PATH = { "Assets", "Maps", "Splashdown" }

-- Required lazily and never cached: Edit mode holds a require() cache that does
-- not invalidate when Rojo syncs a changed module, and promote() is the one call
-- that has to read the registry as it stands at the moment of the swap.
local function Splashdown()
	return require(ReplicatedStorage.Config.Gameplay.Splashdown) :: {
		CourseOrder: { string },
		Courses: { [string]: { [string]: any } },
	}
end

local function specFor(id: string)
	local specs = script.Parent:FindFirstChild("CourseSpecs")
	assert(specs, "[CourseAuthoring] CourseSpecs folder is missing")
	local module = specs:FindFirstChild(id)
	assert(module and module:IsA("ModuleScript"), `[CourseAuthoring] no CourseSpecs module named "{id}"`)
	return require(module) :: any
end

local function sources(): CourseBuilder.Sources
	local root = ServerStorage:FindFirstChild("SplashdownAuthoringSources")
	assert(
		root,
		"[CourseAuthoring] ServerStorage.SplashdownAuthoringSources is missing; run the section 4 export first"
	)
	local kit = root:FindFirstChild("Kit")
	local arena = root:FindFirstChild("ArenaSources")
	local wall = arena and arena:FindFirstChild("BoundaryWall")
	assert(kit, "[CourseAuthoring] SplashdownAuthoringSources.Kit is missing")
	assert(wall and wall:IsA("BasePart"), "[CourseAuthoring] ArenaSources.BoundaryWall is missing")
	-- The whole export root goes through as well, because HANDOFF 7.7's SourcePatch
	-- layout patches an AUTHORED COURSE that lives beside the kit (SummitSource) and
	-- has to be able to find it without reaching into ServerStorage itself.
	return { Kit = kit, BoundaryWall = wall :: BasePart, AuthoringRoot = root }
end

-- Parks a named StringValue in ServerStorage, reusing one that is already there.
-- Edit-mode results have to survive the Command Bar call that produced them so an
-- ordinary instance read can collect them afterwards.
local function parkedValue(name: string): StringValue
	local existing = ServerStorage:FindFirstChild(name)
	if existing and existing:IsA("StringValue") then
		return existing
	end
	local made = Instance.new("StringValue")
	made.Name = name
	made.Parent = ServerStorage
	return made
end

local function stagingFolder(): Folder
	local existing = ServerStorage:FindFirstChild(STAGING_NAME)
	if existing then
		assert(existing:IsA("Folder"), `[CourseAuthoring] ServerStorage.{STAGING_NAME} exists but is not a Folder`)
		return existing :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = STAGING_NAME
	folder.Parent = ServerStorage
	return folder
end

-- 5.1.11: only ever replace a staging model this pipeline owns. A model without
-- the BuildVersion marker belongs to someone else and is never destroyed.
local function claimStagingSlot(folder: Folder, id: string)
	local existing = folder:FindFirstChild(id)
	if not existing then
		return
	end
	assert(
		existing:GetAttribute(OWNER_MARKER) ~= nil,
		`[CourseAuthoring] ServerStorage.{STAGING_NAME}.{id} has no {OWNER_MARKER} marker: refusing to replace a foreign model`
	)
	existing:Destroy()
end

export type StageResult = {
	ok: boolean,
	ids: { string },
	partCounts: { [string]: number },
	buildSeconds: { [string]: number },
	routeLengths: { [string]: number },
	attributeErrors: { string },
	routeErrors: { string },
	boundsViolations: { string },
	specHashes: { [string]: string },
}

function CourseAuthoring.stage(ids: { string }): StageResult
	local folder = stagingFolder()
	local injected = sources()
	local result: StageResult = {
		ok = true,
		ids = {},
		partCounts = {},
		buildSeconds = {},
		routeLengths = {},
		attributeErrors = {},
		routeErrors = {},
		boundsViolations = {},
		specHashes = {},
	}

	local reports: { [string]: CourseBuilder.BuildReport } = {}
	for _, id in ids do
		local spec = specFor(id)
		local model, report = CourseBuilder.build(spec, injected)
		reports[id] = report
		claimStagingSlot(folder, id)
		model.Name = id
		model:SetAttribute(OWNER_MARKER, 1)
		model.Parent = folder

		table.insert(result.ids, id)
		result.partCounts[id] = report.PartCount
		result.buildSeconds[id] = report.BuildSeconds
		result.routeLengths[id] = report.RouteLength
		result.specHashes[id] = report.SpecHash
		for _, message in report.AttributeErrors do
			table.insert(result.attributeErrors, id .. ": " .. message)
		end
		for _, message in report.RouteErrors do
			table.insert(result.routeErrors, id .. ": " .. message)
		end
		for _, message in report.Bounds.Violations do
			table.insert(result.boundsViolations, id .. ": " .. message)
		end
		if not report.Ok then
			result.ok = false
		end
	end

	-- 5.1.12 prints the JSON summary; elapsed build time is deliberately outside
	-- the deterministic hash, so the hashes alone are what a rebuild compares.
	print(HttpService:JSONEncode(result))

	-- A StringValue caps at 200,000 characters and silently drops a longer
	-- assignment, so the route step list -- by far the largest field, and the one
	-- that grows with the course -- is written per course under its own name.
	local summary: { [string]: any } = {}
	for id, report in reports do
		summary[id] = {
			Ok = report.Ok,
			PartCount = report.PartCount,
			SpecHash = report.SpecHash,
			RouteLength = report.RouteLength,
			CheckpointCount = report.CheckpointCount,
			Beats = report.Beats,
			Bounds = report.Bounds,
			AttributeErrors = report.AttributeErrors,
			RouteErrors = report.RouteErrors,
			GuideDeviation = report.GuideDeviation,
			GuideLength = report.GuideLength,
			HairpinFraction = report.HairpinFraction,
			HairpinMidFraction = report.HairpinMidFraction,
			HairpinExitFraction = report.HairpinExitFraction,
			LoopClosureStuds = report.LoopClosureStuds,
			LoopTotalTurnDegrees = report.LoopTotalTurnDegrees,
			IslandLinks = report.IslandLinks,
			WorstIslandSeparation = report.WorstIslandSeparation,
			WorstIslandSeparationPair = report.WorstIslandSeparationPair,
			MaxLaunchReach = report.MaxLaunchReach,
			-- StackedSwitchback measurements: per-run climb, every measured guard
			-- wall, the tightest vertical clearance between two runs sharing a
			-- centreline, the tightest cross-run edge margin against the ordinary
			-- jump, and the rising-liquid flood line against the lowest checkpoint.
			Runs = report.Runs,
			GuardWalls = report.GuardWalls,
			WorstStackClearance = report.WorstStackClearance,
			WorstStackPair = report.WorstStackPair,
			WorstCrossRunMargin = report.WorstCrossRunMargin,
			WorstCrossRunPair = report.WorstCrossRunPair,
			WalledCrossRunPairs = report.WalledCrossRunPairs,
			FloodTopY = report.FloodTopY,
			LowestCheckpointY = report.LowestCheckpointY,
			FloodClearance = report.FloodClearance,
			-- SourcePatch measurements (HANDOFF 7.7): what the patch inherited,
			-- deleted and kept, every gate's measured worst unsealed strip, and when
			-- the preserved flood reaches each preserved checkpoint pad.
			SourceBaseParts = report.SourceBaseParts,
			Removed = report.Removed,
			Retained = report.Retained,
			GateSeals = report.GateSeals,
			CheckpointFloodTimes = report.CheckpointFloodTimes,
			RouteSteps = #report.Route,
		}
		parkedValue(string.format("%s_%s_Route", REPORT_NAME, id)).Value = HttpService:JSONEncode(report.Route)
	end
	parkedValue(REPORT_NAME).Value = HttpService:JSONEncode(summary)

	return result
end

local function previewFolder(): Folder?
	local existing = Workspace:FindFirstChild(PREVIEW_NAME)
	return if existing and existing:IsA("Folder") then existing :: Folder else nil
end

local function mapOrigin(): CFrame
	local assets = Workspace:FindFirstChild("Assets")
	local arena = assets and assets:FindFirstChild("Arena")
	local origin = arena and arena:FindFirstChild("MapOrigin")
	if origin and origin:IsA("BasePart") then
		return origin.CFrame
	end
	return CFrame.new()
end

-- 5.1.13: an UNREGISTERED clone at the live MapOrigin for Edit captures. The
-- preview owns only its own folder; it never parks or destroys a user model, so
-- clearPreview() has nothing to restore beyond removing what it created.
function CourseAuthoring.preview(id: string): Model
	CourseAuthoring.clearPreview()
	local staged = stagingFolder():FindFirstChild(id)
	assert(staged and staged:IsA("Model"), `[CourseAuthoring] {id} is not staged; run stage with it first`)

	local folder = Instance.new("Folder")
	folder.Name = PREVIEW_NAME
	folder:SetAttribute(OWNER_MARKER, 1)
	folder.Parent = Workspace

	local clone = (staged :: Model):Clone()
	clone:SetAttribute("PreviewOnly", true)
	clone.Parent = folder
	clone:PivotTo(mapOrigin())
	return clone
end

function CourseAuthoring.clearPreview()
	local folder = previewFolder()
	if not folder then
		return
	end
	assert(
		folder:GetAttribute(OWNER_MARKER) ~= nil,
		`[CourseAuthoring] Workspace.{PREVIEW_NAME} has no {OWNER_MARKER} marker: refusing to delete a foreign folder`
	)
	folder:Destroy()
end

local function templatesRoot(): Instance
	local current: Instance = ReplicatedStorage
	for _, segment in TEMPLATES_PATH do
		local child = current:FindFirstChild(segment)
		assert(child, `[CourseAuthoring] ReplicatedStorage.{table.concat(TEMPLATES_PATH, ".")} is missing`)
		current = child
	end
	return current
end

-- 5.1.14: promotion is the final validated replacement. Every candidate is
-- verified present and hash-matched BEFORE anything is mutated, so a missing or
-- drifted course aborts the whole transaction rather than half-applying it.
function CourseAuthoring.promote(ids: { string }, expectedHashes: { [string]: string }): { string }
	local folder = stagingFolder()
	local staged: { [string]: Model } = {}
	for _, id in ids do
		local model = folder:FindFirstChild(id)
		assert(model and model:IsA("Model"), `[CourseAuthoring] {id} is not staged; nothing was promoted`)
		local expected = expectedHashes[id]
		assert(expected ~= nil, `[CourseAuthoring] no verified hash supplied for {id}; nothing was promoted`)
		assert(
			model:GetAttribute("SpecHash") == expected,
			`[CourseAuthoring] {id} staging hash {tostring(model:GetAttribute("SpecHash"))} does not match the verified {expected}; nothing was promoted`
		)
		staged[id] = model :: Model
	end

	local root = templatesRoot()
	local promoted: { string } = {}
	for _, id in ids do
		local existing = root:FindFirstChild(id)
		if existing then
			existing:Destroy()
		end
		local clone = staged[id]:Clone()
		clone:SetAttribute("PreviewOnly", nil)
		clone.Parent = root
		table.insert(promoted, id)
	end

	-- 12.1.2: the promoted set must equal the registry exactly. A template with
	-- no CourseOrder entry never loads and a CourseOrder entry with no template
	-- boots into a missing-template error, so both directions are failures and
	-- both are reported by name rather than by count.
	local registered: { [string]: boolean } = {}
	local missing: { string } = {}
	for _, id in Splashdown().CourseOrder do
		registered[id] = true
		local model = root:FindFirstChild(id)
		if not (model and model:IsA("Model")) then
			table.insert(missing, id)
		end
	end
	local unregistered: { string } = {}
	for _, child in root:GetChildren() do
		if not registered[child.Name] then
			table.insert(unregistered, `{child.Name}[{child.ClassName}]`)
		end
	end
	assert(#missing == 0, `[CourseAuthoring] CourseOrder ids with no promoted template: {table.concat(missing, ", ")}`)
	assert(
		#unregistered == 0,
		`[CourseAuthoring] templates that are not in CourseOrder: {table.concat(unregistered, ", ")}`
	)
	return promoted
end

-- The user rejected preserving deprecated courses (HANDOFF section 0.6): the
-- superseded parked models are deleted outright at the validated swap, with no
-- Deprecated folder, archive or source export.
-- The exact six 12.1.3 authorises, and nothing else. SummitSplash is the
-- preserved original, CrossCurrent never had a parked model, and the ninety
-- Keyframes beside them are unrelated animation data (section 14.12).
local RETIREABLE: { [string]: boolean } = {
	WhirlPool = true,
	DiscJockey = true,
	KnockKnock = true,
	BumperBay = true,
	TiltTrip = true,
	Downpour = true,
}

function CourseAuthoring.retireLegacy(ids: { string }): { string }
	-- Every id is checked against the allow list BEFORE anything is resolved, so
	-- a typo that would otherwise hit SummitSplash aborts the whole call instead
	-- of destroying part of the set.
	for _, id in ids do
		assert(RETIREABLE[id], `[CourseAuthoring] {id} is not a retireable legacy course; nothing was destroyed`)
	end

	local legacy = Workspace:FindFirstChild("LegacyCourses")
	local removed: { string } = {}
	if not legacy then
		return removed
	end
	assert(legacy:IsA("Folder") or legacy:IsA("Model"), "[CourseAuthoring] Workspace.LegacyCourses is not a container")

	-- Resolve and class-check every target first; only then destroy. A parked
	-- course that is not a Model is not the thing 12.1.3 names, and guessing at
	-- it is how a Keyframe or the container itself gets deleted by accident.
	local targets: { Model } = {}
	for _, id in ids do
		local model = legacy:FindFirstChild(id)
		if model ~= nil then
			assert(
				model:IsA("Model"),
				`[CourseAuthoring] Workspace.LegacyCourses.{id} is a {model.ClassName}, not a Model; nothing was destroyed`
			)
			assert(
				model.Parent == legacy,
				`[CourseAuthoring] {id} did not resolve directly under Workspace.LegacyCourses; nothing was destroyed`
			)
			table.insert(targets, model :: Model)
		end
	end

	for _, model in targets do
		local id = model.Name
		model:Destroy()
		table.insert(removed, id)
	end
	return removed
end

return CourseAuthoring
