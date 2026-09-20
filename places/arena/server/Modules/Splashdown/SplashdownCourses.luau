-- Description: Validates the authored Splashdown course templates at boot,
-- blocking invalid feature configuration while allowing harmless stale
-- attributes to warn, and stands one in the bowl on request, resolving every
-- marker the race reads so the race itself never searches the course.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("Gameplay"):WaitForChild("GameModes"))
local Queues = require(Config:WaitForChild("Gameplay"):WaitForChild("Queues"))
local Splashdown = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local ScriptableRoots = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("ScriptableRoots")
)
local AttributeAudit = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("AttributeAudit")
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

type LavaDefinition = {
	MaxHeight: number,
	RiseStudsPerSecond: number,
	StartDelaySeconds: number?,
	PauseWaypoints: string?,
}

export type LiveCourse = {
	id: string,
	displayName: string,
	model: Model,
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
local templateCapacity: number? = nil
local started = false

local function requiredCapacity(): number
	local modes: any = GameModes.Modes
	local mode: any = if typeof(modes) == "table" then modes.Splashdown else nil
	local queueId = if mode then mode.Queue else nil
	local modePath = "Config.Gameplay.GameModes.Modes.Splashdown.Queue"
	assert(
		typeof(queueId) == "string" and queueId ~= "",
		`[SplashdownCourses] {modePath} received {tostring(queueId)} ({typeof(queueId)}); expected a nonempty queue ID; set the Splashdown mode's queue`
	)
	local queuePath = `Config.Gameplay.Queues.Queues.{queueId}`
	local queueDefinitions: any = Queues.Queues
	local queue: any = if typeof(queueDefinitions) == "table" then queueDefinitions[queueId] else nil
	assert(
		typeof(queue) == "table",
		`[SplashdownCourses] {queuePath} is missing or malformed; define the queue selected by {modePath}`
	)
	local selection = queue.ModeSelection
	local strategy = if typeof(selection) == "table" then selection.Strategy else nil
	local fixedModeId = if typeof(selection) == "table" then selection.ModeId else nil
	assert(
		strategy == "Fixed" and fixedModeId == "Splashdown",
		`[SplashdownCourses] {queuePath}.ModeSelection received Strategy={tostring(strategy)}, ModeId={tostring(fixedModeId)}; expected Fixed mode Splashdown; correct the selected queue's ModeSelection`
	)
	local capacity = queue.MatchCapacity
	assert(
		typeof(capacity) == "number"
			and capacity == capacity
			and capacity ~= math.huge
			and capacity > 0
			and capacity % 1 == 0,
		`[SplashdownCourses] {queuePath}.MatchCapacity received {tostring(capacity)} ({typeof(capacity)}); expected a positive integer; set the selected queue's MatchCapacity`
	)
	return capacity
end

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
local function resolve(courseId: string, model: Model, path: string, capacity: number): LiveCourse
	local definition = Splashdown.Courses[courseId]
	assert(definition, `[SplashdownCourses] no course config for {courseId}`)
	local scriptables = requireChild(model, "Scriptables", `{path}.Scriptables`, "Folder") :: Folder
	local start = requireChild(model, "Start", `{path}.Start`, "Folder")
	local padsFolder = requireChild(start, "Pads", `{path}.Start.Pads`, "Folder")
	local pads = sortedParts(padsFolder)
	assert(#pads >= capacity, `[SplashdownCourses] {path}.Start.Pads must hold at least {capacity} pads`)
	local checkpointsFolder = requireChild(model, "Checkpoints", `{path}.Checkpoints`, "Folder")
	local checkpoints = sortedCheckpoints(checkpointsFolder, `{path}.Checkpoints`)
	assert(#checkpoints > 0, `[SplashdownCourses] {path}.Checkpoints must hold at least one checkpoint`)
	local declared = model:GetAttribute("CheckpointCount")
	assert(declared == #checkpoints, `[SplashdownCourses] {path}.CheckpointCount must equal {#checkpoints}`)
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
	local lavaDefinition = definition.LavaRise :: LavaDefinition?
	local configuredLiquid = {}
	for _, hazard in hazards do
		if hazard:GetAttribute("RisingLiquid") == true then
			table.insert(configuredLiquid, hazard)
		end
	end
	if lavaDefinition then
		assert(
			#configuredLiquid == 1,
			`[SplashdownCourses] {path}.Hazards must contain exactly one RisingLiquid=true part for configured LavaRise`
		)
		lava = configuredLiquid[1]
		local authored = assert(RisingLiquid.resolve(lava:GetAttributes()))
		local configured = assert(
			RisingLiquid.resolve({
				RisingLiquid = true,
				MaxHeight = lavaDefinition.MaxHeight,
				RiseStudsPerSecond = lavaDefinition.RiseStudsPerSecond,
				StartDelaySeconds = lavaDefinition.StartDelaySeconds,
				PauseWaypoints = lavaDefinition.PauseWaypoints or "",
			})
		)
		assert(
			math.abs(authored.studs - configured.studs) < 1e-6
				and math.abs(authored.seconds - configured.seconds) < 1e-6
				and math.abs(authored.delaySeconds - configured.delaySeconds) < 1e-6,
			`[SplashdownCourses] {path}.Hazards liquid schedule disagrees with course LavaRise configuration`
		)
		lavaRise = configured
	else
		assert(
			#configuredLiquid == 0,
			`[SplashdownCourses] {path} has RisingLiquid=true but no LavaRise configuration`
		)
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
	local capacity = requiredCapacity()
	local folder = SplashdownCourses.templatesFolder()
	local path = folder:GetFullName()
	local candidates: { [string]: Model } = {}
	for _, courseId in Splashdown.CourseOrder do
		local template = requireChild(folder, courseId, `{path}.{courseId}`, "Model") :: Model
		local errors = AttributeAudit.checkSplashdownCourse(template, Splashdown.Courses[courseId])
		assert(#errors == 0, `[SplashdownCourses] rejected {template:GetFullName()}:\n{table.concat(errors, "\n")}`)
		resolve(courseId, template, `{path}.{courseId}`, capacity)
		candidates[courseId] = template
	end
	templates = candidates
	templateCapacity = capacity
	started = true
end

function SplashdownCourses.template(courseId: string): Model
	SplashdownCourses.start()
	return assert(templates[courseId], `[SplashdownCourses] unknown course {courseId}`)
end

function SplashdownCourses.checkpointCount(courseId: string): number
	local template = SplashdownCourses.template(courseId)
	local count = template:GetAttribute("CheckpointCount")
	assert(
		typeof(count) == "number" and count > 0 and count % 1 == 0,
		`[SplashdownCourses] {template:GetFullName()}.CheckpointCount received {tostring(count)}; restore its positive authored checkpoint count`
	)
	return count
end

-- Clones the template into the bowl, pinned to the arena's MapOrigin, and
-- tags its Scriptables so the kits and rotors pick the course up.
function SplashdownCourses.instantiate(courseId: string, parent: Instance, origin: CFrame): LiveCourse
	local template = SplashdownCourses.template(courseId)
	local capacity = assert(templateCapacity, "[SplashdownCourses] no committed queue capacity after template start")
	local clone = template:Clone()
	clone.Name = Splashdown.ActiveCourseName
	local taggedRoot: Folder? = nil
	-- Resolve and tag while staged; cleanup always rethrows the original failure.
	local ok, result = pcall(function(): LiveCourse
		clone:PivotTo(origin)
		local live = resolve(
			courseId,
			clone,
			`{parent:GetFullName()}.{Splashdown.ActiveCourseName}`,
			capacity
		)
		local tagged, reason = ScriptableRoots.tag(live.scriptables)
		assert(
			tagged,
			`[SplashdownCourses] rejected staged {parent:GetFullName()}.{Splashdown.ActiveCourseName}.Scriptables:\n{reason}`
		)
		taggedRoot = live.scriptables
		clone.Parent = parent
		return live
	end)
	if not ok then
		if taggedRoot then
			ScriptableRoots.untag(taggedRoot)
		end
		clone:Destroy()
		error(result, 0)
	end
	return result :: LiveCourse
end

function SplashdownCourses.destroy(live: LiveCourse)
	ScriptableRoots.untag(live.scriptables)
	live.model:Destroy()
end

return SplashdownCourses
