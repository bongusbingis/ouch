-- Name: author-splashdown-courses.luau
-- Author: Jack C.
-- Description: Studio Edit-mode authoring for the five Splashdown course templates: clones pieces from the Workspace.battle_stadium pack showcase at arena scale, lays each course out inside the stadium bowl through a small course DSL, writes the templates to ReplicatedStorage.Assets.Maps.Splashdown, and can preview one course in the bowl with the arena interior parked, restoring it afterwards.
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

local DECK = "bridge_003"
local PLAZA = "octagon_002"
local RAIL = "wall_004"
local POST = "tower_001"

-- A deck tile is 124 long and 76 wide at arena scale. deck() runs its long
-- axis along the heading; wideTile() runs it across the heading.
local function deck(course: Course, center: Vector3, heading: number, top: number?): (BasePart, Vector3)
	local part, size = piece(DECK)
	part.Name = nextName(course, "sd_deck")
	placePart(part, Vector3.new(center.X, (top or DECK_Y) - size.Y, center.Z), heading + 90, course.geometry)
	return part, size
end

local function wideTile(course: Course, center: Vector3, heading: number, top: number?): (BasePart, Vector3)
	local part, size = piece(DECK)
	part.Name = nextName(course, "sd_deck")
	placePart(part, Vector3.new(center.X, (top or DECK_Y) - size.Y, center.Z), heading, course.geometry)
	return part, size
end

-- Plazas sit a hair under deck level so an overlapping deck never fights it.
local function plaza(course: Course, center: Vector3, top: number?): (BasePart, Vector3)
	local part, size = piece(PLAZA)
	part.Name = nextName(course, "sd_plaza")
	placePart(part, Vector3.new(center.X, (top or DECK_Y - 0.2) - size.Y, center.Z), 0, course.geometry)
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
	end
	if spec.shoveSpeed then
		attributes[A.ShoveSpeed] = spec.shoveSpeed
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

-- Paddle wheel: four pads turning about a horizontal axle across the path,
-- raised so the lowest pad skims the deck instead of passing through it.
local function paddleWheel(course: Course, position: Vector3, heading: number, speed: number)
	return obstacle(course, "obstacle_24", position + Vector3.new(0, 3, 0), heading, {
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

-- Hammer: a blade swinging from a mount 19 studs up, so the blade's lowest
-- reach passes through hip height and clears the deck.
local function hammer(course: Course, position: Vector3, heading: number, phase: number, amplitude: number?)
	local pivot, size = obstacle(course, "obstacle_3", position + Vector3.new(0, 19, 0), heading)
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
			shoveSpeed = 38,
		})
	)
	return pivot, size
end

-- Chain mace: the whole chain swings as one body from its top link, hung 16
-- studs up so the ball passes through hip height.
local function mace(course: Course, position: Vector3, heading: number, phase: number)
	return obstacle(course, "obstacle_5_001", position + Vector3.new(0, 16, 0), heading, {
		attributes = rotorAttributes({
			mode = "rock",
			axis = "Z",
			amplitude = 50,
			period = 2.6,
			phase = phase,
			shove = true,
			shoveSpeed = 40,
		}),
	})
end

-- Spiked roller: the drum turns about its long axis across the path and shoves.
local function roller(course: Course, position: Vector3, heading: number, speed: number)
	local frame = obstacle(course, "obstacle_2", position, heading)
	local drum = child(frame, "sd_obstacle_2_002", "drum")
	setAttributes(drum, rotorAttributes({ mode = "spin", axis = "X", speed = speed, shove = true, shoveSpeed = 34 }))
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
		rotorAttributes({ mode = "slide", axis = "X", amplitude = amplitude, period = period, phase = phase })
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
	return obstacle(course, base, position, 0, { attributes = { [A.Bumper] = true } })
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
	local part = piece("door_00" .. ((row + index) % 6 + 2), { scale = 0.35 })
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

local recipes: { [string]: (Course) -> () } = {}

-- Whirl Pool: a straight sprint north through spinner rows and windmill bars,
-- a fan-assisted hop over a lava gap, paddle wheels, then loose beach balls
-- and humps on the plaza before the line.
recipes.WhirlPool = function(course: Course)
	lavaFloor(course)
	local heading = 0
	deck(course, Vector3.new(0, 0, 260), heading)
	startPads(course, Vector3.new(0, 0, 300), heading)
	bothRails(course, Vector3.new(0, 0, 322), heading, 124, 37)

	deck(course, Vector3.new(0, 0, 136), heading)
	deck(course, Vector3.new(0, 0, 12), heading)
	bothRails(course, Vector3.new(0, 0, 198), heading, 248, 37)
	spinner(course, Vector3.new(-18, DECK_Y, 170), 110, 0)
	spinner(course, Vector3.new(18, DECK_Y, 170), -110, 90)
	spinner(course, Vector3.new(0, DECK_Y, 125), 130, 45)
	checkpoint(course, Vector3.new(0, 0, 84), heading, 76)
	windmill(course, Vector3.new(0, DECK_Y, 40), 110)
	windmill(course, Vector3.new(0, DECK_Y, -14), -130)

	fan(course, Vector3.new(-16, DECK_Y, -42))
	fan(course, Vector3.new(16, DECK_Y, -42))
	deck(course, Vector3.new(0, 0, -132), heading)
	bothRails(course, Vector3.new(0, 0, -70), heading, 124, 37)
	checkpoint(course, Vector3.new(0, 0, -76), heading, 76)
	paddleWheel(course, Vector3.new(0, DECK_Y, -110), heading, 70)
	paddleWheel(course, Vector3.new(12, DECK_Y, -160), heading, -85)
	checkpoint(course, Vector3.new(0, 0, -192), heading, 76)

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
	startPads(course, Vector3.new(west, 0, 226), 0)
	bothRails(course, Vector3.new(west, 0, 252), 0, 124, 37)

	for index, z in { 102.6, 56.6, 10.6, -35.4 } do
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

	for index, z in { -37.7, 6.3, 50.3 } do
		spinningDisc(course, "obstacle_15_001", Vector3.new(east, 0, z), if index % 2 == 0 then 40 else -40)
	end
	deck(course, Vector3.new(east, 0, 134.5), 180)
	bothRails(course, Vector3.new(east, 0, 72.7), 180, 124, 37)
	checkpoint(course, Vector3.new(east, 0, 95), 180, 76)
	jumpPad(course, Vector3.new(east - 14, DECK_Y, 168))
	jumpPad(course, Vector3.new(east + 14, DECK_Y, 168))
	wideTile(course, Vector3.new(east, 0, 222), 180, 12)
	finishLine(course, Vector3.new(east, 0, 215), 180, 124, 12)
	flags(course, { Vector3.new(east - 50, 12, 250), Vector3.new(east + 50, 12, 250) })
end

-- Knock Knock: four rows of doors where two per row give way, sliding walls,
-- then rocking flaps across a lava gap before the finish.
recipes.KnockKnock = function(course: Course)
	lavaFloor(course)
	local heading = 0
	deck(course, Vector3.new(0, 0, 260), heading)
	startPads(course, Vector3.new(0, 0, 300), heading)
	bothRails(course, Vector3.new(0, 0, 322), heading, 124, 37)

	local perRow = Splashdown.Courses.KnockKnock.Doors.PerRow
	for row, z in { 174, 98, 22, -54 } do
		wideTile(course, Vector3.new(0, 0, z), heading)
		bothRails(course, Vector3.new(0, 0, z + 38), heading, 76, 62)
		for index = 1, perRow do
			local across = (index - (perRow + 1) / 2) * 24.6
			door(course, row, index, Vector3.new(across, DECK_Y, z + 18), heading)
		end
	end
	checkpoint(course, Vector3.new(0, 0, -80), heading, 124)

	deck(course, Vector3.new(0, 0, -154), heading)
	bothRails(course, Vector3.new(0, 0, -92), heading, 124, 37)
	for index, z in { -120, -154, -188 } do
		slidingWall(course, Vector3.new(-19, DECK_Y, z), 0, 11, 3.2, (index - 1) * 0.9)
		slidingWall(course, Vector3.new(19, DECK_Y, z), 0, 11, 3.2, (index - 1) * 0.9 + 1.6)
	end
	checkpoint(course, Vector3.new(0, 0, -205), heading, 76)

	for index, x in { -25, 0, 25 } do
		flap(course, Vector3.new(x, DECK_Y, -216), heading, (index - 1) * 0.9)
	end
	deck(course, Vector3.new(0, 0, -302), heading)
	bothRails(course, Vector3.new(0, 0, -240), heading, 124, 37)
	checkpoint(course, Vector3.new(0, 0, -252), heading, 76)
	finishLine(course, Vector3.new(0, 0, -300), heading, 124)
	flags(course, { Vector3.new(-50, DECK_Y, -345), Vector3.new(50, DECK_Y, -345) })
end

-- Bumper Bay: bumper-lined bridges over lava, loose beach balls, swinging
-- hammers over a crossing, a spiked roller run and rocking planks up steps to
-- a raised finish.
recipes.BumperBay = function(course: Course)
	lavaFloor(course)
	local east, west = 190, -190
	deck(course, Vector3.new(east, 0, 240), 0)
	startPads(course, Vector3.new(east, 0, 276), 0)
	bothRails(course, Vector3.new(east, 0, 302), 0, 124, 37)

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
	checkpoint(course, Vector3.new(east, 0, -10), 0, 76)
	for index, offset in { -24, -8, 8, 24 } do
		beachBall(course, Vector3.new(east + offset, DECK_Y + 6, -60 - (index % 2) * 16))
	end
	bumper(course, "obstacle_18_001", Vector3.new(east - 26, DECK_Y, -96))
	bumper(course, "obstacle_18_001", Vector3.new(east + 26, DECK_Y, -96))
	deck(course, Vector3.new(east, 0, -160), 90)
	checkpoint(course, Vector3.new(east - 30, 0, -160), 90, 76)

	for _, x in { 96, 32, -32, -96 } do
		local plank = piece("bridge_001")
		plank.Name = nextName(course, "sd_bridge")
		placePart(plank, Vector3.new(x, DECK_Y - 13, -160), 0, course.geometry)
	end
	hammer(course, Vector3.new(80, DECK_Y, -160), 90, 0)
	hammer(course, Vector3.new(0, DECK_Y, -160), 90, 0.8)
	hammer(course, Vector3.new(-80, DECK_Y, -160), 90, 1.6)
	deck(course, Vector3.new(west, 0, -160), 90)
	checkpoint(course, Vector3.new(west, 0, -135), 0, 76)

	deck(course, Vector3.new(west, 0, -60), 180)
	bothRails(course, Vector3.new(west, 0, -122), 180, 124, 37)
	roller(course, Vector3.new(west, DECK_Y, -95), 0, 90)
	roller(course, Vector3.new(west, DECK_Y, -35), 0, -110)
	checkpoint(course, Vector3.new(west, 0, -5), 180, 76)
	rockingPlank(course, Vector3.new(west, DECK_Y - 13, 34), 90, 0)
	rockingPlank(course, Vector3.new(west, DECK_Y - 13, 98), 90, 1.6)
	steps(course, Vector3.new(west, 0, 140), 180, 4, 2.5)
	wideTile(course, Vector3.new(west, 0, 232), 180, 13)
	finishLine(course, Vector3.new(west, 0, 215), 180, 124, 13)
	flags(course, { Vector3.new(west - 50, 13, 258), Vector3.new(west + 50, 13, 258) })
end

-- Summit Splash: a rising spiral of decks around the bowl with windmill bars,
-- maces and humps over the climb, fans between tiers and a summit finish; the
-- lava climbs through the round and floods the lower tiers.
recipes.SummitSplash = function(course: Course)
	local rise = Splashdown.Courses.SummitSplash.LavaRise
	lavaFloor(course, rise.Studs, rise.DelaySeconds, rise.Seconds)
	-- Polar course space: angle 0 points south (+Z) and angles grow toward east
	-- first; a tile's heading faces along the tangent toward increasing angle.
	local function polar(angle: number, radius: number): Vector3
		local radians = math.rad(angle)
		return Vector3.new(math.sin(radians) * radius, 0, math.cos(radians) * radius)
	end
	local tileLength = 124
	local gap = 4
	local tiles = 10
	local checkpointsAt = { [3] = true, [6] = true, [8] = true, [10] = true }
	local angle = 180
	local radius = 256
	local top = -20
	local lastCenter = Vector3.zero
	for index = 0, tiles do
		local center = polar(angle, radius)
		local heading = angle - 90
		deck(course, center, heading, top)
		rails(course, center - forward(heading) * (tileLength / 2) + polar(angle, 38), heading, tileLength, 0, top)
		if index == 0 then
			startPads(course, center - forward(heading) * 24, heading, top)
		else
			if index % 3 == 1 then
				windmill(course, center + Vector3.new(0, top, 0), if index % 2 == 0 then 120 else -120)
			elseif index % 3 == 2 then
				mace(course, center + Vector3.new(0, top, 0), heading, index * 0.7)
			else
				local ahead = forward(heading) * 30
				hump(course, center + ahead + Vector3.new(0, top, 0), heading)
				hump(course, center - ahead + Vector3.new(0, top, 0), heading)
			end
			if index == 4 or index == 7 then
				fan(course, center + forward(heading) * 52 + Vector3.new(0, top, 0))
			end
			if checkpointsAt[index] then
				checkpoint(course, center - forward(heading) * 20, heading, 76, top)
			end
		end
		lastCenter = center
		local nextRadius = radius - 9
		angle += math.deg(2 * math.asin(math.min((tileLength + gap) / (2 * nextRadius), 1)))
		radius = nextRadius
		top += 4
	end

	local summitTop = top
	local summit, summitSize = piece("octagon_001")
	summit.Name = "sd_summit"
	placePart(summit, Vector3.new(0, summitTop - summitSize.Y, 0), 0, course.geometry)
	local inward = -lastCenter.Unit
	local bridgeCenter = lastCenter + inward * (38 + tileLength / 2 - 6)
	local bridge = piece(DECK)
	bridge.Name = nextName(course, "sd_deck")
	local bridgeHeading = math.deg(math.atan2(-inward.X, -inward.Z))
	placePart(bridge, Vector3.new(bridgeCenter.X, summitTop - 5, bridgeCenter.Z), bridgeHeading + 90, course.geometry)
	bothRails(course, lastCenter + inward * 38, bridgeHeading, tileLength - 6, 37, summitTop)
	finishLine(course, Vector3.new(0, 0, 0), bridgeHeading, 60, summitTop)
	flags(course, { Vector3.new(-30, summitTop, 30), Vector3.new(30, summitTop, -30) })
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
