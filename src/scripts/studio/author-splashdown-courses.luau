-- Name: author-splashdown-courses.luau
-- Author: Jack C.
-- Description: Studio Edit-mode authoring for Splashdown course templates: clones pieces from the Workspace.battle_stadium pack showcase at arena scale, lays each course out inside the stadium bowl through a small course DSL, writes the templates to ReplicatedStorage.Assets.Maps.Splashdown, and can preview one course in the bowl with the arena interior parked, restoring it afterwards.
-- Created: 2026-09-14

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

assert(not RunService:IsRunning(), "Run course authoring in Edit mode")

local Config = ReplicatedStorage:WaitForChild("Config")
local Splashdown = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local MapFeatures = require(Config:WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local A = MapFeatures.Attributes

local SCALE = 0.55
local DECK_Y = 0
local LAVA_Y = -50
local BOWL_RADIUS = 370
local CAPACITY = 30
local ARENA = workspace:WaitForChild("Assets"):WaitForChild("Arena")
local MAP_ORIGIN = ARENA:WaitForChild("MapOrigin")
assert(MAP_ORIGIN:IsA("BasePart"), "[SplashdownAuthor] MapOrigin must be a BasePart")
local SHOWCASE = workspace:WaitForChild("battle_stadium")
local MOAT = ARENA:WaitForChild("Scriptables"):WaitForChild("ElimZones"):WaitForChild("base_circle_water_001.001")
assert(MOAT:IsA("MeshPart"), "[SplashdownAuthor] moat must be a MeshPart")
local ARENA_BOUNDARY = ARENA:WaitForChild("Map"):WaitForChild("Boundary")
assert(ARENA_BOUNDARY:IsA("Folder"), "[SplashdownAuthor] Map.Boundary must be a Folder")
local INTERIOR = { "Level_1", "Level_2", "Level_3" }
local SIBLINGS = { "Scriptables", "PlayerSpawns", "TeamSpawns" }

local Author = {}

-- Piece library -------------------------------------------------------------

local templates: { [string]: Instance } = {}
local holders: { [BasePart]: Model } = {}

-- Families are named base_NNN in the showcase; a bare family name resolves to
-- its first member without ever matching a longer family (obstacle_2 must not
-- find obstacle_20).
local function template(base: string): Instance
	local cached = templates[base]
	if cached then
		return cached
	end
	local found = SHOWCASE:FindFirstChild(base) or SHOWCASE:FindFirstChild(base .. "_001")
	if found == nil then
		for _, child in SHOWCASE:GetChildren() do
			local boundary = child.Name:sub(#base + 1, #base + 1)
			if child.Name:find(base, 1, true) == 1 and (boundary == "_" or boundary == ".") then
				found = child
				break
			end
		end
	end
	assert(found, `[SplashdownAuthor] battle_stadium has no piece named {base}`)
	templates[base] = found
	return found
end

type PieceOptions = {
	name: string?,
	scale: number?,
	collide: boolean?,
	attributes: { [string]: any }?,
}

-- A piece is the showcase part with its children, scaled about its own frame,
-- anchored, with imported pivots discarded and re-based so the whole piece is
-- placed by the bottom centre of its bounds. Course pieces are renamed with an
-- sd_ prefix so the arena's name-based rotor and kit lists never match them;
-- the kits read attributes on course pieces instead.
local function piece(base: string, options: PieceOptions?): (BasePart, Vector3)
	local opts = options or {}
	local source = template(base)
	local holder = Instance.new("Model")
	local clone = source:Clone()
	clone.Parent = holder
	holder:ScaleTo(opts.scale or SCALE)
	local root: BasePart? = nil
	for _, descendant in holder:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = opts.collide ~= false
			descendant.CanTouch = false
			descendant.CanQuery = true
			descendant.Massless = false
			descendant.PivotOffset = CFrame.identity
			if descendant == clone then
				root = descendant
				descendant.Name = opts.name or ("sd_" .. base)
			elseif descendant.Name:find("sd_", 1, true) ~= 1 then
				descendant.Name = "sd_" .. descendant.Name:gsub("%.%d+$", "")
			end
		end
	end
	local part = assert(root, `[SplashdownAuthor] {base} did not clone as a BasePart`)
	local cf, size = holder:GetBoundingBox()
	holder.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
	holders[part] = holder
	if opts.attributes then
		for key, value in opts.attributes do
			part:SetAttribute(key, value)
		end
	end
	return part, size
end

-- A piece stays inside its scaling holder until it is placed, so the whole
-- hierarchy moves together; a BasePart's own PivotTo would leave children behind.
local function placePart(part: BasePart, position: Vector3, yaw: number, parent: Instance): BasePart
	local holder = holders[part]
	local target = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)
	if holder then
		holder:PivotTo(target)
		part.Parent = parent
		holders[part] = nil
		holder:Destroy()
	else
		part:PivotTo(target)
		part.Parent = parent
	end
	return part
end

local function marker(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

-- Course frame ------------------------------------------------------------------

-- Course space is the stadium frame with MapOrigin at (0, 0, 0): x east, z south,
-- so "north" is -Z. A heading is a yaw in degrees and forward(heading) is the
-- LookVector of CFrame.Angles(0, rad(heading), 0), so a marker rotated by a
-- heading faces the way the recipe says it does. Every recipe lays geometry in
-- this space and the template's Origin part pins it to MapOrigin.
local function forward(heading: number): Vector3
	local radians = math.rad(heading)
	return Vector3.new(-math.sin(radians), 0, -math.cos(radians))
end

local function right(heading: number): Vector3
	return forward(heading - 90)
end

type Course = {
	model: Model,
	geometry: Folder,
	hazards: Folder,
	start: Folder,
	checkpoints: Folder,
	finish: Folder,
	scriptables: Folder,
	assembly: Model,
	rotating: Folder,
	jumpPads: Folder,
	doors: Folder,
	checkpointCount: number,
	groupCount: number,
	floorFamily: string,
	counters: { [string]: number },
}

local function newCourse(courseId: string): Course
	local definition = Splashdown.Courses[courseId]
	assert(definition, `[SplashdownAuthor] no course config for {courseId}`)
	local model = Instance.new("Model")
	model.Name = courseId
	model:SetAttribute("DisplayName", definition.DisplayName)
	model:SetAttribute("ParSeconds", definition.ParSeconds)
	model:SetAttribute("Difficulty", definition.Difficulty)

	local origin = Instance.new("Part")
	origin.Name = "Origin"
	origin.Size = Vector3.one
	origin.Anchored = true
	origin.CanCollide = false
	origin.CanTouch = false
	origin.CanQuery = false
	origin.Transparency = 1
	origin.CFrame = CFrame.new(0, 0, 0)
	origin.Parent = model
	model.PrimaryPart = origin

	local function folder(name: string, parent: Instance): Folder
		local created = Instance.new("Folder")
		created.Name = name
		created.Parent = parent
		return created
	end
	local scriptables = folder("Scriptables", model)
	local rotating = folder("Rotating", scriptables)
	local group = folder("Static", rotating)
	local groupOrigin = Instance.new("Part")
	groupOrigin.Name = "Origin"
	groupOrigin.Size = Vector3.new(4, 1, 2)
	groupOrigin.Anchored = true
	groupOrigin.CanCollide = false
	groupOrigin.CanTouch = false
	groupOrigin.CanQuery = false
	groupOrigin.Transparency = 1
	groupOrigin.CFrame = CFrame.new(0, DECK_Y, 0)
	groupOrigin:SetAttribute("RotationSpeed", 0)
	groupOrigin.Parent = group
	local assembly = Instance.new("Model")
	assembly.Name = "Assembly"
	assembly.Parent = group

	return {
		model = model,
		geometry = folder("Geometry", model),
		hazards = folder("Hazards", model),
		start = folder("Start", model),
		checkpoints = folder("Checkpoints", model),
		finish = folder("Finish", model),
		scriptables = scriptables,
		assembly = assembly,
		rotating = rotating,
		jumpPads = folder("JumpPads", scriptables),
		doors = folder("Doors", scriptables),
		checkpointCount = 0,
		groupCount = 0,
		floorFamily = if courseId == "KnockKnock" or courseId == "Downpour"
			then "platform_002"
			elseif courseId == "TiltTrip" or courseId == "DiscJockey" then "platform_003"
			else "platform_001",
		counters = {},
	}
end

local function nextName(course: Course, base: string): string
	local count = (course.counters[base] or 0) + 1
	course.counters[base] = count
	return string.format("%s.%03d", base, count)
end

-- Lava across the whole bowl. The floor lava is a hazard like any other; the
-- void check below the course catches anything that somehow gets under it.
local function lavaFloor(course: Course, riseStuds: number?, riseDelay: number?, riseSeconds: number?)
	local lava = MOAT:Clone()
	lava.Name = "sd_lava"
	lava.Size = Vector3.new(BOWL_RADIUS * 2 + 20, 0.1, BOWL_RADIUS * 2 + 20)
	lava.CFrame = CFrame.new(0, LAVA_Y, 0)
	lava.Anchored = true
	lava.CanCollide = false
	lava.CanTouch = false
	lava.CanQuery = false
	if riseStuds then
		lava:SetAttribute("RiseStuds", riseStuds)
		lava:SetAttribute("RiseDelaySeconds", riseDelay or 0)
		lava:SetAttribute("RiseSeconds", riseSeconds or 120)
	end
	lava.Parent = course.hazards
	return lava
end

-- The arena's own boundary ring sits inside the reach of the outer decks, so
-- each course carries a wider ring of the same invisible wall piece, centred
-- on MapOrigin at the bowl's edge.
local function boundary(course: Course)
	local wallTemplate: BasePart? = nil
	for _, child in ARENA_BOUNDARY:GetChildren() do
		if child:IsA("BasePart") then
			wallTemplate = child
			break
		end
	end
	local wallSource = assert(wallTemplate, "[SplashdownAuthor] Map.Boundary has no wall part")
	local folder = Instance.new("Folder")
	folder.Name = "Boundary"
	local radius = Splashdown.Boundary.Radius
	local segments = Splashdown.Boundary.Segments
	local height = wallSource.Size.Y
	for index = 1, segments do
		local angle = (index - 1) / segments * 2 * math.pi
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local wall = wallSource:Clone()
		wall.Name = string.format("Wall%02d", index)
		wall.Anchored = true
		wall.CanCollide = true
		wall.CanTouch = false
		wall.CanQuery = true
		wall.Transparency = 1
		wall.CFrame = CFrame.lookAt(
			outward * radius + Vector3.new(0, LAVA_Y + height / 2, 0),
			Vector3.new(0, LAVA_Y + height / 2, 0)
		)
		wall.Parent = folder
	end
	folder.Parent = course.model
end

local PLAZA = "octagon_002"
local RAIL = "wall_004"
local POST = "tower_001"

-- Six inflatable platforms sit on a flat raft of showcase water tiles. The
-- raft supports the rounded lips and the imported cushions' collision seams.
local function floorDeck(
	course: Course,
	center: Vector3,
	heading: number,
	top: number,
	parent: Instance,
	narrow: boolean?
): (BasePart, Vector3)
	local root: BasePart? = nil
	local height = 0
	for _, along in { -37, 0, 37 } do
		for _, across in if narrow then { 0 } else { -17.3, 17.3 } do
			local part, size = piece(course.floorFamily)
			part.Name = nextName(course, "sd_" .. course.floorFamily)
			height = size.Y
			local position = center + forward(heading) * along + right(heading) * across
			placePart(part, Vector3.new(position.X, top - size.Y, position.Z), heading, root or parent)
			root = root or part
		end
	end
	local base = if course.floorFamily == "platform_002" then "water_platform_001" else "water_platform_003"
	for _, along in { -50, -30, -10, 10, 30, 50 } do
		for _, across in if narrow then { -9.5, 9.5 } else { -28.5, -9.5, 9.5, 28.5 } do
			local part, size = piece(base)
			part.Name = nextName(course, "sd_" .. base)
			local position = center + forward(heading) * along + right(heading) * across
			placePart(part, Vector3.new(position.X, top - 0.25 - size.Y, position.Z), heading, root or parent)
		end
	end
	return assert(root, "[SplashdownAuthor] floor deck needs a root"),
		Vector3.new(if narrow then 38.5 else 77.5, height, 123.4)
end

local function deck(course: Course, center: Vector3, heading: number, top: number?): (BasePart, Vector3)
	return floorDeck(course, center, heading, top or DECK_Y, course.geometry)
end

-- One intact cushion lane with matching support underneath, using the same
-- authored pieces at the same scale. Hazards span a real crossing instead of
-- sitting in the middle of a wide, bypassable floor.
local function narrowDeck(course: Course, center: Vector3, heading: number, top: number?): (BasePart, Vector3)
	return floorDeck(course, center, heading, top or DECK_Y, course.geometry, true)
end

local function wideTile(course: Course, center: Vector3, heading: number, top: number?): (BasePart, Vector3)
	return floorDeck(course, center, heading + 90, top or DECK_Y, course.geometry)
end

-- Plazas sit a hair under deck level so an overlapping deck never fights it.
local function plaza(course: Course, center: Vector3, top: number?): (BasePart, Vector3)
	local part, size = piece(PLAZA)
	part.Name = nextName(course, "sd_plaza")
	placePart(part, Vector3.new(center.X, (top or DECK_Y - 0.2) - size.Y, center.Z), 0, course.geometry)
	for x = -40, 40, 20 do
		for z = -40, 40, 20 do
			local tile, tileSize = piece("water_platform_003")
			tile.Name = nextName(course, "sd_island_support")
			placePart(tile, Vector3.new(center.X + x, (top or DECK_Y - 0.2) - 0.25 - tileSize.Y, center.Z + z), 0, part)
		end
	end
	return part, size
end

-- Runs one row of rails along a deck edge, posts between them.
local function rails(course: Course, from: Vector3, heading: number, length: number, offset: number, top: number?)
	local y = top or DECK_Y
	local step = 15.4
	local count = math.max(math.floor(length / step + 0.5), 1)
	local dir = forward(heading)
	local side = right(heading) * offset
	for index = 1, count do
		local along = dir * ((index - 0.5) * (length / count))
		local rail = piece(RAIL)
		rail.Name = nextName(course, "sd_rail")
		placePart(rail, from + along + side + Vector3.new(0, y, 0), heading + 90, course.geometry)
	end
	for index = 0, count do
		local post = piece(POST)
		post.Name = nextName(course, "sd_post")
		placePart(post, from + dir * (index * (length / count)) + side + Vector3.new(0, y, 0), heading, course.geometry)
	end
end

local function bothRails(
	course: Course,
	from: Vector3,
	heading: number,
	length: number,
	halfWidth: number,
	top: number?
)
	rails(course, from, heading, length, halfWidth, top)
	rails(course, from, heading, length, -halfWidth, top)
end

local function startPads(course: Course, center: Vector3, heading: number, top: number?)
	local pads = Instance.new("Folder")
	pads.Name = "Pads"
	pads.Parent = course.start
	local columns = 6
	local rows = math.ceil(CAPACITY / columns)
	local dir = forward(heading)
	local side = right(heading)
	local y = (top or DECK_Y) + 0.5
	local index = 0
	for row = 1, rows do
		for column = 1, columns do
			index += 1
			if index > CAPACITY then
				break
			end
			local across = (column - (columns + 1) / 2) * 6
			local back = (row - 1) * 5
			local position = center + side * across - dir * back + Vector3.new(0, y, 0)
			marker(
				string.format("Pad%02d", index),
				Vector3.new(3, 1, 3),
				CFrame.new(position) * CFrame.Angles(0, math.rad(heading), 0),
				pads
			)
		end
	end
	course.start:SetAttribute("Heading", heading)
end

local function checkpoint(course: Course, center: Vector3, heading: number, width: number, top: number?)
	course.checkpointCount += 1
	local y = top or DECK_Y
	local model = Instance.new("Model")
	model.Name = string.format("Checkpoint%02d", course.checkpointCount)
	local rotation = CFrame.Angles(0, math.rad(heading), 0)
	marker("Trigger", Vector3.new(width, 20, 6), CFrame.new(center + Vector3.new(0, y + 10, 0)) * rotation, model)
	marker(
		"Pad",
		Vector3.new(width - 4, 1, 10),
		CFrame.new(center - forward(heading) * 4 + Vector3.new(0, y + 0.5, 0)) * rotation,
		model
	)
	local arch = piece("checkpoint_001", { collide = false })
	arch.Name = "Arch"
	placePart(arch, center + Vector3.new(0, y, 0), heading, model)
	model.Parent = course.checkpoints
	return model
end

local function finishLine(course: Course, center: Vector3, heading: number, width: number, top: number?)
	local y = top or DECK_Y
	local rotation = CFrame.Angles(0, math.rad(heading), 0)
	marker(
		"Trigger",
		Vector3.new(width, 24, 8),
		CFrame.new(center + Vector3.new(0, y + 12, 0)) * rotation,
		course.finish
	)
	local line = piece("finish_001", { collide = false })
	line.Name = "Line"
	placePart(line, center + Vector3.new(0, y + 0.1, 0), heading, course.finish)
	local arch = piece("finish_002", { collide = false })
	arch.Name = "Arch"
	placePart(arch, center + Vector3.new(0, y, 0), heading, course.finish)
	marker(
		"Deck",
		Vector3.new(width, 1, 40),
		CFrame.new(center + forward(heading) * 24 + Vector3.new(0, y + 0.5, 0)) * rotation,
		course.finish
	)
end

-- Attribute rotors: the part and its descendants move as one rigid body about
-- the part's pivot, driven by RotatingPlatforms from the synchronized clock.
type RotorSpec = {
	mode: "spin" | "rock" | "slide",
	axis: ("X" | "Y" | "Z")?,
	speed: number?,
	amplitude: number?,
	period: number?,
	phase: number?,
	carries: boolean?,
	shove: boolean?,
	shoveSpeed: number?,
}

local function rotorAttributes(spec: RotorSpec): { [string]: any }
	local attributes: { [string]: any } = {
		[A.Rotor] = spec.mode,
		[A.RotorAxis] = spec.axis or "Y",
	}
	if spec.speed then
		attributes[A.RotorSpeed] = spec.speed
	end
	if spec.amplitude then
		attributes[A.RotorAmplitude] = spec.amplitude
	end
	if spec.period then
		attributes[A.RotorPeriod] = spec.period
	end
	if spec.phase then
		attributes[A.RotorPhase] = spec.phase
	end
	if spec.carries then
		attributes[A.RotorCarries] = true
	end
	if spec.shove then
		attributes[A.Shove] = true
		local response = Splashdown.HazardResponse.Rotor
		attributes[A.ShoveSpeed] = spec.shoveSpeed or response.Speed
		attributes[A.ShoveUpwardSpeed] = response.UpwardSpeed
		attributes[A.ShoveSeconds] = response.HoldSeconds
	end
	return attributes
end

local function setAttributes(part: BasePart, attributes: { [string]: any })
	for key, value in attributes do
		part:SetAttribute(key, value)
	end
end

local function child(part: BasePart, name: string, what: string): BasePart
	local found = part:FindFirstChild(name)
	assert(found and found:IsA("BasePart"), `[SplashdownAuthor] {part.Name} has no {what} ({name})`)
	return found
end

local function obstacle(
	course: Course,
	base: string,
	position: Vector3,
	yaw: number,
	options: PieceOptions?
): (BasePart, Vector3)
	local part, size = piece(base, options)
	part.Name = nextName(course, "sd_" .. base)
	placePart(part, position, yaw, course.assembly)
	return part, size
end

-- Spinner paddle: a striped bar spinning flat at hip height, a shove on contact.
local function spinner(course: Course, position: Vector3, speed: number, phase: number?)
	local part = obstacle(course, "obstacle_6", position, 0, {
		attributes = rotorAttributes({ mode = "spin", axis = "Y", speed = speed, shove = true }),
	})
	if phase then
		part:PivotTo(part:GetPivot() * CFrame.Angles(0, math.rad(phase), 0))
	end
	return part
end

-- Windmill bar: the bar sits 12 studs up its post, so the post sinks into the
-- deck until the bar sweeps at hip height.
local function windmill(course: Course, position: Vector3, speed: number)
	local post = obstacle(course, "obstacle_25", position - Vector3.new(0, 8.3, 0), 0)
	local bar = child(post, "sd_obstacle_25_002", "bar")
	setAttributes(bar, rotorAttributes({ mode = "spin", axis = "Y", speed = speed, shove = true }))
	return post
end

-- Paddle wheel: the lowest pad starts one stud above the deck, with the
-- axle across the path so its swept pads intersect standing runners.
local function paddleWheel(course: Course, position: Vector3, heading: number, speed: number)
	return obstacle(course, "obstacle_24", position + Vector3.new(0, 1, 0), heading, {
		attributes = rotorAttributes({ mode = "spin", axis = "X", speed = speed, shove = true }),
	})
end

-- Flap: a square panel hinged on an axle, rocking so its far edge lifts and
-- drops; laid flush with the deck across a lava gap and carrying whoever is on it.
local function flap(course: Course, position: Vector3, heading: number, phase: number)
	local axle = obstacle(course, "obstacle_8", position - Vector3.new(0, 2.7, 0), heading)
	local panel = child(axle, "sd_obstacle_8_002", "panel")
	panel.PivotOffset = panel.CFrame:ToObjectSpace(CFrame.new(axle.Position))
	setAttributes(
		panel,
		rotorAttributes({ mode = "rock", axis = "X", amplitude = 18, period = 2.8, phase = phase, carries = true })
	)
	return axle
end

-- Hammer: the assembly's bottom is the blade tip, not the mount. A two-stud
-- bottom clearance puts the blade through hip height at the foot of its swing.
local function hammer(course: Course, position: Vector3, heading: number, phase: number, amplitude: number?)
	local pivot, size = obstacle(course, "obstacle_3", position + Vector3.new(0, 2, 0), heading)
	local blade = child(pivot, "sd_obstacle_3_002", "blade")
	blade.PivotOffset = blade.CFrame:ToObjectSpace(CFrame.new(pivot.Position))
	setAttributes(
		blade,
		rotorAttributes({
			mode = "rock",
			axis = "Z",
			amplitude = amplitude or 55,
			period = 2.4,
			phase = phase,
			shove = true,
			shoveSpeed = Splashdown.HazardResponse.HammerSpeed,
		})
	)
	return pivot, size
end

-- Chain mace: the piece's bottom is the ball. One stud of bottom clearance
-- leaves the ball at hip height while the whole chain swings from its top link.
local function mace(course: Course, position: Vector3, heading: number, phase: number)
	return obstacle(course, "obstacle_5_001", position + Vector3.new(0, 1, 0), heading, {
		attributes = rotorAttributes({
			mode = "rock",
			axis = "Z",
			amplitude = 50,
			period = 2.6,
			phase = phase,
			shove = true,
			shoveSpeed = Splashdown.HazardResponse.MaceSpeed,
		}),
	})
end

-- Spiked roller: the drum turns about its long axis across the path and shoves.
local function roller(course: Course, position: Vector3, heading: number, speed: number)
	local frame = obstacle(course, "obstacle_2", position, heading)
	local drum = child(frame, "sd_obstacle_2_002", "drum")
	setAttributes(
		drum,
		rotorAttributes({
			mode = "spin",
			axis = "X",
			speed = speed,
			shove = true,
			shoveSpeed = Splashdown.HazardResponse.RollerSpeed,
		})
	)
	return frame
end

-- Sliding wall: a panel sweeping side to side along its rail.
local function slidingWall(
	course: Course,
	position: Vector3,
	heading: number,
	amplitude: number,
	period: number,
	phase: number
)
	local rail = obstacle(course, "obstacle_7", position, heading)
	local panel = child(rail, "sd_obstacle_7_002", "panel")
	setAttributes(
		panel,
		rotorAttributes({
			mode = "slide",
			axis = "X",
			amplitude = amplitude,
			period = period,
			phase = phase,
			shove = true,
			shoveSpeed = Splashdown.HazardResponse.SlidingWallSpeed,
		})
	)
	return rail
end

-- Rocking plank: a bridge rolling about its long axis under the riders it carries.
local function rockingPlank(course: Course, position: Vector3, heading: number, phase: number)
	return obstacle(course, "bridge_001", position, heading, {
		attributes = rotorAttributes({
			mode = "rock",
			axis = "X",
			amplitude = 22,
			period = 3.2,
			phase = phase,
			carries = true,
		}),
	})
end

-- Spinning disc platform: a whole rotating group so riders are carried by the
-- platform code that already moves the arena rings.
local function spinningDisc(
	course: Course,
	base: string,
	position: Vector3,
	degreesPerSecond: number,
	top: number?
): BasePart
	course.groupCount += 1
	local group = Instance.new("Folder")
	group.Name = string.format("Disc%02d", course.groupCount)
	local origin = Instance.new("Part")
	origin.Name = "Origin"
	origin.Size = Vector3.new(4, 1, 2)
	origin.Anchored = true
	origin.CanCollide = false
	origin.CanTouch = false
	origin.CanQuery = false
	origin.Transparency = 1
	origin.CFrame = CFrame.new(position.X, top or DECK_Y, position.Z)
	origin:SetAttribute("RotationSpeed", degreesPerSecond)
	origin.Parent = group
	local assembly = Instance.new("Model")
	assembly.Name = "Assembly"
	assembly.Parent = group
	local plate, size = piece(base)
	plate.Name = "sd_disc"
	placePart(plate, Vector3.new(position.X, (top or DECK_Y) - size.Y, position.Z), 0, assembly)
	group.Parent = course.rotating
	return plate
end

local function bumper(course: Course, base: string, position: Vector3)
	local response = Splashdown.HazardResponse.Bumper
	return obstacle(
		course,
		base,
		position,
		0,
		{
			attributes = {
				[A.Bumper] = true,
				[A.ShoveSpeed] = response.Speed,
				[A.ShoveUpwardSpeed] = response.UpwardSpeed,
				[A.ShoveSeconds] = response.HoldSeconds,
			},
		}
	)
end

-- Fan: the caged propeller sinks into the deck so only its grate stands proud,
-- one step up and inside the launch column.
local function fan(course: Course, position: Vector3)
	local base = obstacle(course, "propeller_trampoline_1", position - Vector3.new(0, 11, 0), 0, {
		attributes = { [A.Fan] = true },
	})
	local blade = child(base, "sd_propeller_trampoline_2_001", "blade")
	blade:SetAttribute(A.FanBlade, true)
	return base
end

local function jumpPad(course: Course, position: Vector3)
	local pad = Instance.new("Model")
	pad.Name = "Pad"
	local outer = piece("trampoline_3_001")
	outer.Name = "Outer"
	local inner = outer:FindFirstChild("sd_trampoline_3_002")
	if inner then
		inner.Name = "Inner"
	end
	placePart(outer, position, 0, pad)
	pad.Parent = course.jumpPads
	return pad
end

local function beachBall(course: Course, position: Vector3)
	local ball = piece("ball_001")
	ball.Name = nextName(course, "ball_001")
	placePart(ball, position, 0, course.assembly)
	return ball
end

local function hump(course: Course, position: Vector3, yaw: number)
	local count = (course.counters.hump or 0) + 1
	course.counters.hump = count
	return obstacle(course, if count % 2 == 0 then "obstacle_21" else "obstacle_20", position, yaw)
end

local function steps(course: Course, from: Vector3, heading: number, count: number, rise: number)
	local dir = forward(heading)
	for index = 1, count do
		local box = piece("color_box_00" .. ((index - 1) % 8 + 1))
		box.Name = nextName(course, "sd_step")
		placePart(
			box,
			from + dir * ((index - 1) * 15.4) + Vector3.new(0, DECK_Y + (index - 1) * rise, 0),
			heading,
			course.geometry
		)
	end
end

local function door(course: Course, row: number, index: number, position: Vector3, heading: number)
	local part = piece("door_00" .. ((row + index) % 6 + 2))
	part.Name = string.format("sd_door_%d_%d", row, index)
	part:SetAttribute(A.DoorRow, row)
	part:SetAttribute(A.DoorIndex, index)
	placePart(part, position, heading, course.doors)
	return part
end

local function flags(course: Course, positions: { Vector3 })
	for _, position in positions do
		local flag = piece("flag_002", { collide = false })
		flag.Name = nextName(course, "sd_flag")
		placePart(flag, position, 0, course.geometry)
	end
end

-- Recipes -----------------------------------------------------------------------

-- The rectangular platform raft rolls around its long Z axis. The six meshes
-- share one pivot and carry riders together, with a stable central crossing.
local function tiltDeck(course: Course, center: Vector3, heading: number, phase: number, amplitude: number?)
	local part, size = floorDeck(course, center, heading, center.Y, course.assembly, true)
	part.Name = nextName(course, "sd_tilt_deck")
	part.PivotOffset = part.CFrame:ToObjectSpace(
		CFrame.new(center - Vector3.yAxis * size.Y / 2) * CFrame.Angles(0, math.rad(heading), 0)
	)
	setAttributes(
		part,
		rotorAttributes({
			mode = "rock",
			axis = "Z",
			amplitude = amplitude or 12,
			period = 4.8,
			phase = phase,
			carries = true,
		})
	)
	for index, along in { -26, 26 } do
		local offset = forward(heading) * along + right(heading) * (if index == 1 then -4 else 4)
		local pad = bumper(course, "obstacle_19_001", center + offset)
		-- A raft follower: the bumper never floats above a rocking surface.
		pad.Parent = part
	end
	return part
end

-- Pendulum log: the 19-stud assembly hangs from its top axle. Its bottom is
-- two studs above the floor at rest, crossing a runner's hips on each swing.
local function pendulum(course: Course, position: Vector3, heading: number, phase: number)
	local axle = obstacle(course, "obstacle_4", position + Vector3.new(0, 2, 0), heading)
	local log = child(axle, "sd_obstacle_4_002", "log")
	local pivot = CFrame.new(axle.Position) * CFrame.Angles(0, math.rad(heading), 0)
	log.PivotOffset = log.CFrame:ToObjectSpace(pivot)
	setAttributes(
		log,
		rotorAttributes({ mode = "rock", axis = "Z", amplitude = 48, period = 3.4, phase = phase, shove = true })
	)
	return axle
end

-- Straight platform runs overlap at their ends, including diagonal crossings.
local function deckRun(course: Course, from: Vector3, to: Vector3, top: number, narrow: boolean?): number
	local delta = to - from
	local heading = math.deg(math.atan2(-delta.X, -delta.Z))
	local intervals = math.max(math.ceil(delta.Magnitude / 100), 1)
	for index = 0, intervals do
		floorDeck(course, from:Lerp(to, index / intervals), heading, top, course.geometry, narrow)
	end
	return heading
end

-- Three 49-stud slides have their upper tread 23.8 studs above the bounds'
-- bottom and their low lip 3.8 studs above it. The chute descends along heading.
local function slideChutes(course: Course, center: Vector3, heading: number, bottom: number)
	for _, offset in { -21, 0, 21 } do
		local slide = piece("slide_001")
		slide.Name = nextName(course, "sd_slide")
		placePart(slide, center + right(heading) * offset + Vector3.new(0, bottom, 0), heading, course.geometry)
	end
end

-- Flat showcase mats bridge curved deck seams and form narrow exposed paths.
-- Their walking surface is 15.4 wide by 30.8 long, with no raised end lips.
local function mat(course: Course, center: Vector3, heading: number, top: number?): BasePart
	local part, size = piece("obstacle_9_001")
	part.Name = nextName(course, "sd_mat")
	placePart(part, Vector3.new(center.X, (top or DECK_Y) - size.Y, center.Z), heading, course.geometry)
	return part
end

local recipes: { [string]: (Course) -> () } = {}

-- Whirl Pool: a straight sprint north through spinner rows and windmill bars,
-- a fan-assisted hop over a lava gap, paddle wheels, then loose beach balls
-- and humps on the plaza before the line.
recipes.WhirlPool = function(course: Course)
	lavaFloor(course)
	local heading = 0
	deck(course, Vector3.new(0, 0, 260), heading)
	startPads(course, Vector3.new(0, 0, 282), heading)
	bothRails(course, Vector3.new(0, 0, 322), heading, 124, 37)

	deck(course, Vector3.new(0, 0, 136), heading)
	deck(course, Vector3.new(0, 0, 12), heading)
	mat(course, Vector3.new(0, 0, 198), heading)
	mat(course, Vector3.new(0, 0, 74), heading)
	for index, x in { -24, 0, 24 } do
		spinner(course, Vector3.new(x, DECK_Y, 170), if index % 2 == 0 then -95 else 95, index * 45)
		spinner(course, Vector3.new(x, DECK_Y, 120), if index % 2 == 0 then 105 else -105, index * 60)
	end
	-- Close the straight outer shoulder between the two spinner rows.
	for _, x in { -33, 33 } do
		bumper(course, "obstacle_19_001", Vector3.new(x, DECK_Y, 145))
	end
	checkpoint(course, Vector3.new(0, 0, 84), heading, 76)
	for index, x in { -24, 0, 24 } do
		windmill(course, Vector3.new(x, DECK_Y, 35), if index % 2 == 0 then -85 else 85)
		windmill(course, Vector3.new(x, DECK_Y, -14), if index % 2 == 0 then 95 else -95)
	end

	fan(course, Vector3.new(-16, DECK_Y, -42))
	fan(course, Vector3.new(16, DECK_Y, -42))
	deck(course, Vector3.new(0, 0, -132), heading)
	checkpoint(course, Vector3.new(0, 0, -94), heading, 70)
	paddleWheel(course, Vector3.new(-18, DECK_Y, -120), heading, 65)
	paddleWheel(course, Vector3.new(18, DECK_Y, -145), heading, -75)
	bumper(course, "obstacle_18_001", Vector3.new(29, DECK_Y, -120))
	bumper(course, "obstacle_19_001", Vector3.new(-29, DECK_Y, -145))
	checkpoint(course, Vector3.new(0, 0, -174), heading, 70)
	mat(course, Vector3.new(0, 0, -195), heading)

	plaza(course, Vector3.new(0, 0, -278))
	for index, x in { -30, -10, 10, 30 } do
		beachBall(course, Vector3.new(x, DECK_Y + 6, -215 - (index % 2) * 12))
	end
	hump(course, Vector3.new(-40, DECK_Y, -235), 0)
	hump(course, Vector3.new(40, DECK_Y, -235), 0)
	finishLine(course, Vector3.new(0, 0, -262), heading, 124)
	flags(course, { Vector3.new(-70, DECK_Y, -300), Vector3.new(70, DECK_Y, -300) })
end

-- Disc Jockey: spinning discs over lava up the west side, a long run of
-- pinwheel stepping stones across the north, bigger discs down the east side
-- and a jump-pad hop onto a raised finish.
recipes.DiscJockey = function(course: Course)
	lavaFloor(course)
	local west, east = -200, 200
	deck(course, Vector3.new(west, 0, 190), 0)
	startPads(course, Vector3.new(west, 0, 210), 0)
	bothRails(course, Vector3.new(west, 0, 252), 0, 124, 37)

	for index, z in { 118, 82, 46, 10, -26, -62 } do
		spinningDisc(course, "obstacle_16_001", Vector3.new(west, 0, z), if index % 2 == 0 then -32 else 32)
	end
	deck(course, Vector3.new(west, 0, -122), 0)
	checkpoint(course, Vector3.new(west, 0, -90), 0, 76)

	for index = 0, 10 do
		spinningDisc(
			course,
			"obstacle_14_001",
			Vector3.new(-147.1 + index * 29.4, 0, -160),
			if index % 2 == 0 then 95 else -95
		)
	end
	deck(course, Vector3.new(east, 0, -122), 180)
	checkpoint(course, Vector3.new(east, 0, -130), 180, 76)

	for index, z in { -45, -3, 39, 81 } do
		spinningDisc(course, "obstacle_15_001", Vector3.new(east, 0, z), if index % 2 == 0 then 40 else -40)
	end
	deck(course, Vector3.new(east, 0, 134.5), 180)
	bothRails(course, Vector3.new(east, 0, 72.7), 180, 124, 37)
	checkpoint(course, Vector3.new(east, 0, 95), 180, 76)
	jumpPad(course, Vector3.new(east - 14, DECK_Y, 168))
	jumpPad(course, Vector3.new(east + 14, DECK_Y, 168))
	wideTile(course, Vector3.new(east, 0, 222), 180, 12)
	deck(course, Vector3.new(east, 0, 230), 180, 12)
	finishLine(course, Vector3.new(east, 0, 215), 180, 70, 12)
	flags(course, { Vector3.new(east - 50, 12, 250), Vector3.new(east + 50, 12, 250) })
end

-- Knock Knock: four rows of doors where two per row give way, sliding walls,
-- then rocking flaps across a lava gap before the finish.
recipes.KnockKnock = function(course: Course)
	lavaFloor(course)
	local heading = 0
	deck(course, Vector3.new(0, 0, 260), heading)
	startPads(course, Vector3.new(0, 0, 282), heading)
	bothRails(course, Vector3.new(0, 0, 322), heading, 124, 37)

	local perRow = Splashdown.Courses.KnockKnock.Doors.PerRow
	for row, z in { 174, 98, 22, -54 } do
		-- Endcaps extend past the floor edge, leaving no walkable outer lip.
		wideTile(course, Vector3.new(-50, 0, z), heading)
		wideTile(course, Vector3.new(50, 0, z), heading)
		deck(course, Vector3.new(0, 0, z), heading)
		bothRails(course, Vector3.new(0, 0, z + 38), heading, 76, 112)
		for _, x in { -107, 107 } do
			local cap = piece("wall_001")
			cap.Name = nextName(course, "sd_door_endcap")
			placePart(cap, Vector3.new(x, DECK_Y, z + 18), 0, course.geometry)
		end
		for index = 1, perRow do
			local across = (index - (perRow + 1) / 2) * 40.5
			door(course, row, index, Vector3.new(across, DECK_Y, z + 18), heading)
		end
	end
	checkpoint(course, Vector3.new(0, 0, -74), heading, 70)
	mat(course, Vector3.new(0, 0, -92), heading)

	deck(course, Vector3.new(0, 0, -154), heading)
	for index, z in { -120, -154, -188 } do
		slidingWall(course, Vector3.new(-19, DECK_Y, z), 0, 11, 3.2, (index - 1) * 0.9)
		slidingWall(course, Vector3.new(19, DECK_Y, z), 0, 11, 3.2, (index - 1) * 0.9 + 1.6)
	end
	checkpoint(course, Vector3.new(0, 0, -205), heading, 76)

	for index, x in { -25, 0, 25 } do
		flap(course, Vector3.new(x, DECK_Y, -216), heading, (index - 1) * 0.9)
		mat(course, Vector3.new(x, 0, -243), heading)
	end
	deck(course, Vector3.new(0, 0, -302), heading)
	bothRails(course, Vector3.new(0, 0, -240), heading, 124, 37)
	checkpoint(course, Vector3.new(0, 0, -268), heading, 70)
	wideTile(course, Vector3.new(0, 0, -320), heading)
	finishLine(course, Vector3.new(0, 0, -300), heading, 70)
	flags(course, { Vector3.new(-50, DECK_Y, -345), Vector3.new(50, DECK_Y, -345) })
end

-- Bumper Bay: bumper-lined bridges over lava, loose beach balls, swinging
-- hammers over a crossing, a spiked roller run and rocking planks up steps to
-- a raised finish.
recipes.BumperBay = function(course: Course)
	lavaFloor(course)
	local east, west = 190, -190
	deck(course, Vector3.new(east, 0, 240), 0)
	startPads(course, Vector3.new(east, 0, 260), 0)
	bothRails(course, Vector3.new(east, 0, 296), 0, 118, 37)

	for index, z in { 156, 92, 28 } do
		local plank = piece("bridge_001")
		plank.Name = nextName(course, "sd_bridge")
		placePart(plank, Vector3.new(east, DECK_Y - 13, z), 90, course.geometry)
		bumper(
			course,
			if index % 2 == 0 then "obstacle_19_001" else "obstacle_18_001",
			Vector3.new(east + (if index % 2 == 0 then 9 else -9), DECK_Y, z + 8)
		)
	end
	deck(course, Vector3.new(east, 0, -60), 0)
	mat(course, Vector3.new(east, 0, -4), 0, -4)
	checkpoint(course, Vector3.new(east, 0, -30), 0, 70)
	for index, offset in { -24, -8, 8, 24 } do
		beachBall(course, Vector3.new(east + offset, DECK_Y + 6, -60 - (index % 2) * 16))
	end
	bumper(course, "obstacle_18_001", Vector3.new(east - 26, DECK_Y, -96))
	bumper(course, "obstacle_18_001", Vector3.new(east + 26, DECK_Y, -96))
	deck(course, Vector3.new(east, 0, -160), 90)
	mat(course, Vector3.new(east, 0, -118), 0)
	checkpoint(course, Vector3.new(east - 30, 0, -160), 90, 76)

	for _, x in { 96, 32, -32, -96 } do
		local plank = piece("bridge_001")
		plank.Name = nextName(course, "sd_bridge")
		placePart(plank, Vector3.new(x, DECK_Y - 13, -160), 0, course.geometry)
	end
	for index, x in { 96, 32, -32, -96 } do
		hammer(course, Vector3.new(x, DECK_Y, -160), 90, (index - 1) * 0.6, 45)
	end
	deck(course, Vector3.new(west, 0, -160), 90)
	mat(course, Vector3.new(136, 0, -160), 90, -4)
	mat(course, Vector3.new(-136, 0, -160), 90, -4)
	checkpoint(course, Vector3.new(west, 0, -135), 180, 70)

	narrowDeck(course, Vector3.new(west, 0, -60), 180)
	mat(course, Vector3.new(west, 0, -118), 180)
	roller(course, Vector3.new(west, DECK_Y, -95), 0, 90)
	roller(course, Vector3.new(west, DECK_Y, -35), 0, -110)
	for _, z in { -95, -35 } do
		for _, offset in { -17, 17 } do
			bumper(course, "obstacle_18_001", Vector3.new(west + offset, DECK_Y, z))
		end
	end
	checkpoint(course, Vector3.new(west, 0, -5), 180, 76)
	mat(course, Vector3.new(west, 0, -2), 180, -4)
	rockingPlank(course, Vector3.new(west, DECK_Y - 13, 34), 90, 0)
	rockingPlank(course, Vector3.new(west, DECK_Y - 13, 98), 90, 1.6)
	steps(course, Vector3.new(west, 0, 140), 180, 4, 2.5)
	wideTile(course, Vector3.new(west, 0, 232), 180, 13)
	finishLine(course, Vector3.new(west, 0, 215), 180, 70, 13)
	flags(course, { Vector3.new(west - 50, 13, 258), Vector3.new(west + 50, 13, 258) })
end

-- Arc families share a 200-stud outer radius and a 160-stud inner radius.
-- Their bounding centres differ with sector angle; the outer midpoint pins
-- each original mesh to the same circle without stretching or patching it.
recipes.SummitSplash = function(course: Course)
	local rise = Splashdown.Courses.SummitSplash.LavaRise
	lavaFloor(course, rise.Studs, rise.DelaySeconds, rise.Seconds)
	local function polar(angle: number, radius: number): Vector3
		local radians = math.rad(angle)
		return Vector3.new(math.sin(radians) * radius, 0, math.cos(radians) * radius)
	end
	local sectors = {
		{ "arc_001", 90 },
		{ "arc_004", 45 },
		{ "arc_002", 56 },
		{ "arc_003", 56 },
		{ "arc_001", 90 },
		{ "arc_004", 45 },
		{ "arc_002", 56 },
		{ "arc_004", 45 },
	}
	local angle = 180
	for index, sector in sectors do
		local span = sector[2] :: number
		local midpoint = angle + span / 2
		local top = -25 + index * 5
		local arc, size = piece(sector[1] :: string)
		arc.Name = nextName(course, "sd_arc")
		placePart(arc, polar(midpoint, 200 - size.Z / 2) + Vector3.new(0, top - size.Y, 0), midpoint, course.geometry)
		if index == 1 then
			startPads(course, polar(angle + 15, 180), angle + 15 - 90, top)
		end
		local encounters = math.ceil(span / 26)
		for beat = 1, encounters do
			local at = angle + (beat - 0.5) * span / encounters
			if index == 1 and at < angle + 34 then
				continue -- clear launch area for the full starting pack
			end
			if index % 2 == 0 and at > angle + span - 20 then
				continue -- the checkpoint needs a clear approach and respawn pad
			end
			local y = Vector3.new(0, top, 0)
			if (index + beat) % 2 == 0 then
				windmill(course, polar(at, 180) + y, if beat % 2 == 0 then -80 else 80)
				for _, radius in { 165, 195 } do
					bumper(course, "obstacle_19_001", polar(at, radius) + y)
				end
			else
				-- A visible chicane pushes the racing line across the arc, with a
				-- clear 11-stud passage rather than an unbroken inside shortcut.
				local wall = piece("wall_003")
				wall.Name = nextName(course, "sd_arc_chicane")
				local radius = if index % 2 == 0 then 173 else 187
				placePart(wall, polar(at, radius) + y, at + 90, course.geometry)
				mace(course, polar(at + 8, 180) + y, at - 82, beat * 0.65)
			end
		end
		angle += span
		if index % 2 == 0 then
			checkpoint(course, polar(angle - 9, 180), angle - 99, 36, top)
		end
	end
	local inwardHeading = angle - 8
	for _, radius in { 145, 115, 85 } do
		for _, across in { -15, 0, 15 } do
			local road, size = piece("road_001")
			road.Name = nextName(course, "sd_road")
			placePart(
				road,
				polar(angle - 8, radius) + right(inwardHeading) * across + Vector3.new(0, 17.5 - size.Y, 0),
				inwardHeading,
				course.geometry
			)
		end
	end
	plaza(course, Vector3.zero, 20)
	finishLine(course, Vector3.zero, inwardHeading, 70, 20)
	flags(course, { Vector3.new(-45, 20, -35), Vector3.new(45, 20, 35) })
end

recipes.TiltTrip = function(course: Course)
	lavaFloor(course)
	deck(course, Vector3.new(-190, 0, 235), 0)
	startPads(course, Vector3.new(-190, 0, 255), 0)
	bothRails(course, Vector3.new(-190, 0, 297), 0, 90, 37)
	for index, center in
		{
			Vector3.new(-190, 0, 120),
			Vector3.new(-160, 0, 10),
			Vector3.new(-190, 0, -100),
		}
	do
		tiltDeck(course, center, 0, (index - 1) * 1.6)
	end
	deck(course, Vector3.new(-175, 0, -210), 0)
	checkpoint(course, Vector3.new(-175, 0, -190), 0, 70)

	deckRun(course, Vector3.new(-165, 0, -230), Vector3.new(185, 0, -230), 0, true)
	for index, x in { -110, -45, 20, 85, 150 } do
		pendulum(course, Vector3.new(x, 0, -230), 270, (index - 1) * 0.85)
		bumper(course, "obstacle_1_001", Vector3.new(x, 0, -230 + (if index % 2 == 0 then 13 else -13)))
	end
	deck(course, Vector3.new(190, 0, -195), 180)
	checkpoint(course, Vector3.new(190, 0, -172), 180, 70)

	for index, center in
		{
			Vector3.new(190, 0, -80),
			Vector3.new(215, 0, 30),
			Vector3.new(185, 0, 140),
		}
	do
		tiltDeck(course, center, 180, (index - 1) * 1.6, 14)
	end
	deck(course, Vector3.new(175, 0, 235), 90)
	checkpoint(course, Vector3.new(170, 0, 235), 90, 70)
	tiltDeck(course, Vector3.new(60, 0, 235), 90, 0.8)
	plaza(course, Vector3.new(-40, 0, 235), 0)
	finishLine(course, Vector3.new(-44, 0, 235), 90, 70)
	flags(course, { Vector3.new(-90, 0, 205), Vector3.new(-90, 0, 265) })
end

recipes.CrossCurrent = function(course: Course)
	lavaFloor(course)
	local start = Vector3.new(-200, 0, 200)
	local northEast = Vector3.new(200, 0, -200)
	local southEast = Vector3.new(200, 0, 200)
	local northWest = Vector3.new(-200, 0, -200)
	local upperHeading = deckRun(course, start, northEast, 36)
	startPads(course, start, upperHeading, 36)
	bothRails(course, start - forward(upperHeading) * 25, upperHeading, 70, 37, 36)
	for index, distance in { 100, 190, 280, 370, 460 } do
		local center = start + forward(upperHeading) * distance + Vector3.new(0, 36, 0)
		slidingWall(course, center + right(upperHeading) * 18, upperHeading, 14, 3.8, index * 0.8)
		slidingWall(course, center - right(upperHeading) * 18, upperHeading, 14, 3.8, index * 0.8 + 1.9)
	end
	deck(course, northEast, 180, 36)
	checkpoint(course, Vector3.new(200, 0, -170), 180, 70, 36)

	for index, z in { -85, 30, 145 } do
		local top = 36 - index * 8
		narrowDeck(course, Vector3.new(200, 0, z), 180, top)
		spinner(course, Vector3.new(194, top, z - 18), 90 + index * 10)
		spinner(course, Vector3.new(206, top, z + 18), -90 - index * 10)
	end
	deck(course, southEast, 45, 0)
	checkpoint(course, Vector3.new(145, 0, 145), 45, 70)

	course.floorFamily = "platform_002"
	local lowerHeading = deckRun(course, southEast, northWest, 0, true)
	for index, distance in { 110, 170, 230, 345, 415, 495 } do
		local center = southEast + forward(lowerHeading) * distance
		pendulum(course, center, lowerHeading, index * 0.85)
		bumper(course, "obstacle_1_001", center + right(lowerHeading) * (if index % 2 == 0 then 13 else -13))
	end
	deck(course, northWest, 180)
	checkpoint(course, Vector3.new(-200, 0, -170), 180, 70)
	narrowDeck(course, Vector3.new(-200, 0, -85), 180)
	windmill(course, Vector3.new(-200, 0, -125), 90)
	windmill(course, Vector3.new(-200, 0, -65), -90)
	plaza(course, Vector3.new(-200, 0, 20), 0)
	finishLine(course, Vector3.new(-200, 0, 0), 180, 70)
	flags(course, { Vector3.new(-230, 0, 65), Vector3.new(-170, 0, 65) })
end

recipes.Downpour = function(course: Course)
	lavaFloor(course)
	for index, z in { 200, 80, -40, -160 } do
		local top = 44 - index * 4
		(if index == 1 then deck else narrowDeck)(course, Vector3.new(-190, 0, z), 0, top)
		if index == 1 then
			startPads(course, Vector3.new(-190, 0, 220), 0, top)
		else
			mat(course, Vector3.new(-190, 0, z + 60), 0, top)
			-- Alternating sweeps reach each shoulder in turn. The clear lane
			-- switches sides, with room between rows to read the next paddle.
			windmill(course, Vector3.new(-196, top, z + 24), 75 + index * 5)
			windmill(course, Vector3.new(-184, top, z - 24), -75 - index * 5)
		end
	end
	checkpoint(course, Vector3.new(-190, 0, -150), 0, 70, 28)
	deck(course, Vector3.new(-190, 0, -200), 270, 28)

	for index, x in { -70, 50, 170 } do
		local top = 28 - index * 4
		narrowDeck(course, Vector3.new(x, 0, -200), 270, top)
		mat(course, Vector3.new(x - 60, 0, -200), 270, top)
		paddleWheel(course, Vector3.new(x - 24, top, -200), 270, 55 + index * 10)
		paddleWheel(course, Vector3.new(x + 24, top, -200), 270, -55 - index * 10)
	end
	deck(course, Vector3.new(190, 0, -160), 180, 16)
	checkpoint(course, Vector3.new(190, 0, -126), 180, 70, 16)

	for index, z in { -40, 80, 200 } do
		local top = 16 - index * 4
		narrowDeck(course, Vector3.new(190, 0, z), 180, top)
		mat(course, Vector3.new(190, 0, z - 60), 180, top)
		bumper(course, "obstacle_18_001", Vector3.new(186, top, z - 25))
		bumper(course, "obstacle_19_001", Vector3.new(194, top, z + 15))
	end
	checkpoint(course, Vector3.new(190, 0, 170), 180, 70, 4)
	deck(course, Vector3.new(190, 0, 220), 90, 4)
	narrowDeck(course, Vector3.new(70, 0, 220), 90, 0)
	mat(course, Vector3.new(130, 0, 220), 90)
	deck(course, Vector3.new(0, 0, 220), 90)
	pendulum(course, Vector3.new(95, 0, 220), 90, 0)
	deck(course, Vector3.new(0, 0, 156), 0)
	slideChutes(course, Vector3.new(0, 0, 91), 0, -23.8)
	deck(course, Vector3.new(0, 0, 16), 0, -20)
	plaza(course, Vector3.new(0, 0, -44), -20)
	finishLine(course, Vector3.new(0, 0, -15), 0, 70, -20)
	flags(course, { Vector3.new(-45, -20, -60), Vector3.new(45, -20, -60) })
end

-- Building and previewing --------------------------------------------------------

local function templatesFolder(): Folder
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local maps = assets:WaitForChild("Maps")
	local existing = maps:FindFirstChild("Splashdown")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Splashdown"
	created.Parent = maps
	return created
end

function Author.build(courseIds: { string }?): { string }
	local folder = templatesFolder()
	local built = {}
	for _, courseId in courseIds or Splashdown.CourseOrder do
		local recipe = assert(recipes[courseId], `[SplashdownAuthor] no recipe for {courseId}`)
		local previous = folder:FindFirstChild(courseId)
		if previous then
			previous:Destroy()
		end
		local course = newCourse(courseId)
		recipe(course)
		boundary(course)
		course.model:SetAttribute("CheckpointCount", course.checkpointCount)
		course.model.Parent = folder
		table.insert(
			built,
			`{courseId}: {#course.model:GetDescendants()} instances, {course.checkpointCount} checkpoints`
		)
	end
	return built
end

local PARK_NAME = "SplashdownAuthorParkedInterior"

function Author.preview(courseId: string): string
	Author.restore()
	local folder = templatesFolder()
	local courseTemplate = folder:FindFirstChild(courseId)
	assert(courseTemplate and courseTemplate:IsA("Model"), `[SplashdownAuthor] build {courseId} first`)
	local park = Instance.new("Folder")
	park.Name = PARK_NAME
	park.Parent = ServerStorage
	local map = ARENA:WaitForChild("Map"):WaitForChild("Model")
	for _, name in INTERIOR do
		local level = map:FindFirstChild(name)
		if level then
			level.Parent = park
		end
	end
	for _, name in SIBLINGS do
		local sibling = ARENA:FindFirstChild(name)
		if sibling then
			sibling.Parent = park
		end
	end
	local live = courseTemplate:Clone()
	live.Name = Splashdown.ActiveCourseName
	live:PivotTo(MAP_ORIGIN.CFrame)
	live.Parent = ARENA
	return `previewing {courseId} in the bowl; run restore() before saving`
end

function Author.restore(): string
	local live = ARENA:FindFirstChild(Splashdown.ActiveCourseName)
	if live then
		live:Destroy()
	end
	local park = ServerStorage:FindFirstChild(PARK_NAME)
	if park == nil then
		return "nothing to restore"
	end
	local map = ARENA:WaitForChild("Map"):WaitForChild("Model")
	for _, name in INTERIOR do
		local level = park:FindFirstChild(name)
		if level then
			level.Parent = map
		end
	end
	for _, name in SIBLINGS do
		local sibling = park:FindFirstChild(name)
		if sibling then
			sibling.Parent = ARENA
		end
	end
	park:Destroy()
	return "arena interior restored"
end

return Author
