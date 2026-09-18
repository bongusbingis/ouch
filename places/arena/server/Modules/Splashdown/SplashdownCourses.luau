-- Description: Validates the authored Splashdown course templates at boot with the same fail-fast style as the arena, and stands one in the bowl on request, resolving every marker the race reads so the race itself never searches the course.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("Gameplay"):WaitForChild("GameModes"))
local Splashdown = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local MapFeatures = require(Config:WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local ScriptableRoots = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("ScriptableRoots")
)

local SplashdownCourses = {}
local RisingLiquid = require(ReplicatedStorage.Shared.Game.MapFeatures.RisingLiquid)
local DoorRows = require(script.Parent.DoorRows)

export type Checkpoint = {
	index: number,
	trigger: BasePart,
	pad: BasePart,
}

export type LavaRise = {
	studs: number,
	delaySeconds: number,
	seconds: number,
	pauses: { RisingLiquid.Pause }?,
}

export type LiveCourse = {
	id: string,
	displayName: string,
	model: Model,
	origin: BasePart,
	scriptables: Folder,
	pads: { BasePart },
	checkpoints: { Checkpoint },
	finishTrigger: BasePart,
	finishDeck: BasePart,
	hazards: { BasePart },
	boundary: { BasePart },
	lava: BasePart?,
	lavaBase: CFrame?,
	lavaRise: LavaRise?,
	doorRows: { { BasePart } },
}

local templates: { [string]: Model } = {}
local started = false

local function requireChild(parent: Instance, name: string, path: string, className: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child ~= nil, `[SplashdownCourses] {path} is missing`)
	assert(child:IsA(className), `[SplashdownCourses] {path} must be a {className}`)
	return child
end

local function sortedParts(folder: Instance): { BasePart }
	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)
	return parts
end

local function sortedCheckpoints(folder: Instance, path: string): { Checkpoint }
	local models = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(models, child)
		end
	end
	table.sort(models, function(a, b)
		return a.Name < b.Name
	end)
	local checkpoints = {}
	for index, model in models do
		table.insert(checkpoints, {
			index = index,
			trigger = requireChild(model, "Trigger", `{path}.{model.Name}.Trigger`, "BasePart") :: BasePart,
			pad = requireChild(model, "Pad", `{path}.{model.Name}.Pad`, "BasePart") :: BasePart,
		})
	end
	return checkpoints
end

local function doorRows(folder: Instance?): { { BasePart } }
	return DoorRows.resolve(folder)
end

-- Resolves a course model's markers; the same walk validates a template at
-- boot and binds the live clone, so nothing the race depends on can differ.
local function resolve(courseId: string, model: Model, path: string): LiveCourse
	local definition = Splashdown.Courses[courseId]
	print(Splashdown.Courses, courseId, definition)
	assert(definition, `[SplashdownCourses] no course config for {courseId}`)
	local origin = requireChild(model, "Origin", `{path}.Origin`, "BasePart") :: BasePart
	local scriptables = requireChild(model, "Scriptables", `{path}.Scriptables`, "Folder") :: Folder
	local start = requireChild(model, "Start", `{path}.Start`, "Folder")
	local padsFolder = requireChild(start, "Pads", `{path}.Start.Pads`, "Folder")
	local pads = sortedParts(padsFolder)
	local capacity = GameModes.QueueCapacity(GameModes.ModeQueue("Splashdown") or "Splashdown")
	assert(#pads >= capacity, `[SplashdownCourses] {path}.Start.Pads must hold at least {capacity} pads`)
	local checkpointsFolder = requireChild(model, "Checkpoints", `{path}.Checkpoints`, "Folder")
	local checkpoints = sortedCheckpoints(checkpointsFolder, `{path}.Checkpoints`)
	assert(#checkpoints > 0, `[SplashdownCourses] {path}.Checkpoints must hold at least one checkpoint`)
	local declared = model:GetAttribute("CheckpointCount")
	assert(
		declared == #checkpoints,
		`[SplashdownCourses] {path} declares {tostring(declared)} checkpoints, has {#checkpoints}`
	)
	local finish = requireChild(model, "Finish", `{path}.Finish`, "Folder")
	local finishTrigger = requireChild(finish, "Trigger", `{path}.Finish.Trigger`, "BasePart") :: BasePart
	local finishDeck = requireChild(finish, "Deck", `{path}.Finish.Deck`, "BasePart") :: BasePart
	local hazardsFolder = requireChild(model, "Hazards", `{path}.Hazards`, "Folder")
	local hazards = sortedParts(hazardsFolder)
	assert(#hazards > 0, `[SplashdownCourses] {path}.Hazards must hold at least one hazard`)
	local boundaryFolder = requireChild(model, "Boundary", `{path}.Boundary`, "Folder")
	local boundary = sortedParts(boundaryFolder)
	assert(#boundary > 0, `[SplashdownCourses] {path}.Boundary must hold the course's wall ring`)

	local lava: BasePart? = nil
	local lavaRise: LavaRise? = nil
	for _, hazard in hazards do
		local rise = RisingLiquid.resolve(hazard:GetAttributes())
		if rise then
			lava = hazard
			lavaRise = rise
			break
		end
	end
	if lava == nil then
		lava = hazards[1]
	end

	local doorsFolder = scriptables:FindFirstChild("Doors")
	local rows = doorRows(doorsFolder)
	local doorConfig = definition.Doors
	if doorConfig then
		assert(
			doorConfig.PerRow >= 3 and doorConfig.PerRow <= 5 and doorConfig.PerRow % 1 == 0,
			"[SplashdownCourses] Door rows need 3–5 doors"
		)
		assert(
			doorConfig.BreakablePerRow >= 1
				and doorConfig.BreakablePerRow <= doorConfig.PerRow
				and doorConfig.BreakablePerRow % 1 == 0,
			"[SplashdownCourses] invalid breakable door count"
		)
		assert(#rows > 0, `[SplashdownCourses] {path}.Scriptables.Doors must hold door rows`)
		for row, doors in rows do
			assert(
				#doors == doorConfig.PerRow,
				`[SplashdownCourses] {path} door row {row} needs {doorConfig.PerRow} doors`
			)
		end
	end

	return {
		id = courseId,
		displayName = if typeof(definition.DisplayName) == "string" then definition.DisplayName else courseId,
		model = model,
		origin = origin,
		scriptables = scriptables,
		pads = pads,
		checkpoints = checkpoints,
		finishTrigger = finishTrigger,
		finishDeck = finishDeck,
		hazards = hazards,
		boundary = boundary,
		lava = lava,
		lavaBase = if lava then lava.CFrame else nil,
		lavaRise = lavaRise,
		doorRows = rows,
	}
end

function SplashdownCourses.templatesFolder(): Folder
	local current: Instance = ReplicatedStorage
	local path = "ReplicatedStorage"
	for _, name in Splashdown.TemplatesPath do
		path ..= `.{name}`
		current = requireChild(current, name, path, "Folder")
	end
	return current :: Folder
end

function SplashdownCourses.start()
	if started then
		return
	end
	started = true
	local folder = SplashdownCourses.templatesFolder()
	local path = folder:GetFullName()
	for _, courseId in Splashdown.CourseOrder do
		local template = requireChild(folder, courseId, `{path}.{courseId}`, "Model") :: Model
		resolve(courseId, template, `{path}.{courseId}`)
		templates[courseId] = template
	end
end

function SplashdownCourses.template(courseId: string): Model
	SplashdownCourses.start()
	return assert(templates[courseId], `[SplashdownCourses] unknown course {courseId}`)
end

function SplashdownCourses.checkpointCount(courseId: string): number
	local template = SplashdownCourses.template(courseId)
	return (template:GetAttribute("CheckpointCount") :: number?) or 0
end

-- Clones the template into the bowl, pinned to the arena's MapOrigin, and
-- tags its Scriptables so the kits and rotors pick the course up.
function SplashdownCourses.instantiate(courseId: string, parent: Instance, origin: CFrame): LiveCourse
	local template = SplashdownCourses.template(courseId)
	local clone = template:Clone()
	clone.Name = Splashdown.ActiveCourseName
	clone:PivotTo(origin)
	local live = resolve(courseId, clone, `{parent:GetFullName()}.{Splashdown.ActiveCourseName}`)
	ScriptableRoots.tag(live.scriptables)
	clone.Parent = parent
	return live
end

function SplashdownCourses.destroy(live: LiveCourse)
	ScriptableRoots.untag(live.scriptables)
	live.model:Destroy()
end

return SplashdownCourses
