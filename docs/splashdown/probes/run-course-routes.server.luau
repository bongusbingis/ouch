-- Install as a normal temporary Script under ServerScriptService.Server.Scripts
-- (Rojo syncs places/arena/server/Scripts) and press Play. HANDOFF.md section 8.5
-- and 10 step 8. It builds the course from its declarative spec through the same
-- CourseBuilder.build call CourseAuthoring.stage makes, activates the hazards
-- through the existing ScriptableRoots tag path so they actually move, drives a
-- real R15 Humanoid along the builder's own route cursor trace with
-- Humanoid:MoveTo/Jump only -- never a CFrame teleport except the two relocations
-- section 8.5 permits -- and writes ServerStorage.SplashdownCourseRouteResults as
-- JSON. Delete it before committing.
--
-- Scope note, to be copied verbatim into the gate packet: this harness is a
-- reproducible scripted proxy. It is NOT a human skill classification and it is
-- NOT the interactive keyboard run section 8.5 also requires. Kits that select
-- Players still need real Player trials.
assert(game:GetService("RunService"):IsStudio(), "Studio only")

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local COURSE_ID = "DoorDash"
-- Set true to stop after the deterministic double build and its published
-- build.json. A build that fails its route, bounds or attribute checks is worth
-- knowing in ten seconds rather than after eight scripted trials.
local BUILD_ONLY = false
local STUCK_SECONDS = 8
-- Well above the 90 s upper bound of section 8.5's pass window, so a run that
-- hits it has genuinely failed rather than been cut short, but not so high that
-- eight resets of a course the proxy cannot clear cost forty minutes.
local RUN_CEILING_SECONDS = 150
local RESPAWN_SECONDS = 0.8
local MID_SEEDS = { 101, 102, 103, 104, 105 }
local EXPERT_RESETS = 3
local WAYPOINT_RADIUS = 7
local CONTACT_COOLDOWN = 0.8
-- Roughly an R15 body: 4 studs wide and 7 tall, centred on the root. Wider than
-- the rig so a hazard that reaches the runner registers, not only one already
-- interpenetrating it.
local CONTACT_BOX = Vector3.new(4, 7, 4)
-- A course builds around its own local origin, and the connected place has a
-- solid Workspace.Baseplate at Y 0 covering exactly that. Left there, every fall
-- off the course lands on the baseplate a few studs up instead of passing the
-- liquid plane, so the harness records zero falls and then a stall -- which is
-- what the first two executions of this probe actually measured. The isolated
-- clone is therefore lifted clear of everything before anyone runs on it.
local ISOLATION_OFFSET = Vector3.new(0, 20000, 0)
-- Splashdown.Courses.<Id>.Doors.BreakablePerRow for the course under test. The
-- isolated clone has no mode running to set a door plan, so the harness carries
-- the quota -- but it READS it from the same course config production does
-- instead of carrying a hand-set number. It was hand-set to 1 while Whirlpool
-- Waltz (3/1) was the only course with doors, and would have measured Door Dash
-- (5/2) against a quota the real round never uses.
local BREAKABLE_PER_ROW = (function(): number
	local config =
		require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Splashdown")) :: any
	local course = config.Courses[COURSE_ID]
	local doors = course and course.Doors
	return if doors and doors.BreakablePerRow then doors.BreakablePerRow else 1
end)()
-- MapFeatures.Door.ContactPadding / VerticalPadding: the same reach the real
-- Doors kit uses to decide an approaching root has broken a breakable slab.
local DOOR_CONTACT_PADDING = 3
local DOOR_VERTICAL_PADDING = 1

local result = Instance.new("StringValue")
result.Name = "SplashdownCourseRouteResults"
result.Value = "running"
result.Parent = ServerStorage

-- A StringValue.Value is capped at 200,000 characters and a full eight-run
-- record is larger than that, so the payload is written as numbered chunks and
-- the reader concatenates them. Writing it as one value silently fails with
-- "Provided string length is greater than or equal to max length" and loses the
-- whole measurement.
local CHUNK = 150000
local function writeChunked(payload: string)
	for _, existing in ServerStorage:GetChildren() do
		if existing:IsA("StringValue") and string.match(existing.Name, "^SplashdownCourseRouteChunk%d+$") then
			existing:Destroy()
		end
	end
	local count = math.max(1, math.ceil(#payload / CHUNK))
	for index = 1, count do
		local chunk = Instance.new("StringValue")
		chunk.Name = string.format("SplashdownCourseRouteChunk%d", index)
		chunk.Value = string.sub(payload, (index - 1) * CHUNK + 1, index * CHUNK)
		chunk.Parent = ServerStorage
	end
	result.Value = string.format("chunks=%d length=%d", count, #payload)
end

-- Optional: a local evidence sink (scratchpad/evidence_sink.py, 127.0.0.1) that
-- writes a posted JSON body straight into docs/splashdown/evidence. A Script
-- running in Play has the Network capability, unlike the Assistant's
-- execute_luau VM, so this is the only way a probe can hand a large result
-- straight to the repository instead of being read back a chunk at a time. It
-- is strictly an optimisation: the chunked StringValue above is always written
-- too, and a sink that is not running changes nothing.
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
local ScriptableRoots = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("ScriptableRoots")
) :: any

local function specFor(id: string)
	local specs = Splashdown:WaitForChild("CourseSpecs")
	local module = specs:FindFirstChild(id)
	assert(module and module:IsA("ModuleScript"), `[run-course-routes] no CourseSpecs module named "{id}"`)
	return require(module) :: any
end

local function sources()
	local root = ServerStorage:FindFirstChild("SplashdownAuthoringSources")
	assert(root, "[run-course-routes] ServerStorage.SplashdownAuthoringSources is missing")
	local kit = root:FindFirstChild("Kit")
	local arena = root:FindFirstChild("ArenaSources")
	local wall = arena and arena:FindFirstChild("BoundaryWall")
	assert(kit, "[run-course-routes] SplashdownAuthoringSources.Kit is missing")
	assert(wall and wall:IsA("BasePart"), "[run-course-routes] ArenaSources.BoundaryWall is missing")
	return { Kit = kit, BoundaryWall = wall :: BasePart }
end

-- The actual R15 rig the engine ships, not a three-part approximation: a blank
-- HumanoidDescription gives the default R15 body with a real HipHeight, real
-- limb collision and the real state machine. Movement is then set to this
-- project's measured configuration (HANDOFF 3.2), never engine defaults.
local function buildRig(): (Model, Humanoid, BasePart)
	local rig =
		Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	rig.Name = "SplashdownRouteRig"
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = 26
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 10
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	rig.PrimaryPart = root
	return rig, humanoid, root
end

local function liquidTop(model: Model): number
	local hazards = model:FindFirstChild("Hazards")
	local highest = -math.huge
	if hazards then
		for _, part in hazards:GetChildren() do
			if part:IsA("BasePart") then
				highest = math.max(highest, part.Position.Y + part.Size.Y / 2)
			end
		end
	end
	return if highest > -math.huge then highest else -math.huge
end

local function checkpointPads(model: Model): { { Name: string, Pad: BasePart } }
	local pads = {}
	local checkpoints = model:FindFirstChild("Checkpoints")
	if not checkpoints then
		return pads
	end
	local ordered = checkpoints:GetChildren()
	table.sort(ordered, function(a, b)
		return a.Name < b.Name
	end)
	for _, checkpoint in ordered do
		local pad = checkpoint:FindFirstChild("Pad")
		if pad and pad:IsA("BasePart") then
			table.insert(pads, { Name = checkpoint.Name, Pad = pad :: BasePart })
		end
	end
	return pads
end

-- Waypoints are the builder's own route cursor trace, so the scripted runner
-- follows exactly the arclength the length targets are measured against, plus
-- the finish deck. Nothing here is a hand-listed path.
local function routeWaypoints(model: Model, report: any)
	local points = {}
	for _, step in report.Route do
		table.insert(points, {
			Id = step.PieceId,
			Beat = step.BeatId,
			Kind = step.Kind,
			ArcLength = step.ArcLength,
			-- The report's cursor trace is in the model's own build coordinates;
			-- the clone has since been lifted clear of the place's baseplate.
			Position = step.Position + ISOLATION_OFFSET,
		})
	end
	local finish = model:FindFirstChild("Finish")
	local deck = finish and finish:FindFirstChild("Deck")
	if deck and deck:IsA("BasePart") then
		table.insert(points, {
			Id = "Finish",
			Beat = "Finish",
			Kind = "Finish",
			ArcLength = report.RouteLength,
			Position = deck.Position,
		})
	end
	return points
end

-- HANDOFF 8.6 names build.json as the deterministic build measurement. The
-- route cursor trace is flattened to plain numbers first, because JSONEncode
-- cannot serialize a Vector3.
local function publishBuild(report: any, hashesMatch: boolean): string
	local flattened = {}
	for _, step in report.Route do
		table.insert(flattened, {
			beat = step.BeatId,
			piece = step.PieceId,
			kind = step.Kind,
			x = math.round(step.Position.X * 100) / 100,
			y = math.round(step.Position.Y * 100) / 100,
			z = math.round(step.Position.Z * 100) / 100,
			yaw = math.round(step.Yaw * 100) / 100,
			segment = step.Segment,
			segmentTravel = math.round(step.SegmentTravel * 100) / 100,
			arcLength = math.round(step.ArcLength * 100) / 100,
		})
	end
	return publish("courses/" .. COURSE_ID .. "/build.json", {
		courseId = COURSE_ID,
		placeId = game.PlaceId,
		method = "CourseBuilder.build called twice from identical spec and sources inside a real Studio Play session by run-course-routes.server.luau",
		specHash = report.SpecHash,
		rebuildHashMatches = hashesMatch,
		partCount = report.PartCount,
		routeLength = report.RouteLength,
		checkpointCount = report.CheckpointCount,
		buildOk = report.Ok,
		attributeErrors = report.AttributeErrors,
		routeErrors = report.RouteErrors,
		boundsViolations = report.Bounds.Violations,
		guideDeviation = report.GuideDeviation,
		guideLength = report.GuideLength,
		beats = report.Beats,
		bounds = {
			MaxCornerDistance = report.Bounds.MaxCornerDistance,
			MaxGeometryCenterRadius = report.Bounds.MaxGeometryCenterRadius,
			MaxRouteRadius = report.Bounds.MaxRouteRadius,
			RouteMinY = report.Bounds.RouteMinY,
			RouteMaxY = report.Bounds.RouteMaxY,
			MinY = report.Bounds.MinY,
			MaxY = report.Bounds.MaxY,
			Violations = report.Bounds.Violations,
		},
		route = flattened,
	})
end

-- HANDOFF 8.5 makes door rows the harness's job, not the mode's: "Door test seeds
-- use existing DoorPlan.choose with seeded Random only in the test harness;
-- production stays unchanged." That is necessary as well as prescribed, because
-- in an isolated clone with no match running nothing ever calls Doors.setPlan,
-- so every slab is solid, and Doors.tickPlayer selects Players, so a scripted
-- rig could not break one even if it were breakable. Without this a door row is
-- an unpassable wall and the trial records a stall that says nothing about the
-- course.
local function resolveDoorRows(model: Model): { { BasePart } }
	local scriptables = model:FindFirstChild("Scriptables")
	local folder = scriptables and scriptables:FindFirstChild("Doors")
	if not folder then
		return {}
	end
	local rows: { [number]: { [number]: BasePart } } = {}
	local rowCount = 0
	for _, part in folder:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local row, index = part:GetAttribute("DoorRow"), part:GetAttribute("DoorIndex")
		if typeof(row) ~= "number" or typeof(index) ~= "number" then
			continue
		end
		rows[row] = rows[row] or {}
		rows[row][index] = part
		rowCount = math.max(rowCount, row)
	end
	local ordered: { { BasePart } } = {}
	for row = 1, rowCount do
		local slabs: { BasePart } = {}
		local index = 1
		while rows[row] and rows[row][index] do
			table.insert(slabs, rows[row][index])
			index += 1
		end
		table.insert(ordered, slabs)
	end
	return ordered
end

-- Centre-out, exactly as 8.5 specifies: 3,2,4,1,5 for five and 2,1,3 for three.
local function centreOutOrder(count: number): { number }
	local centre = math.ceil(count / 2)
	local order = { centre }
	local step = 1
	while #order < count do
		local low, high = centre - step, centre + step
		if low >= 1 then
			table.insert(order, low)
		end
		if high <= count then
			table.insert(order, high)
		end
		step += 1
	end
	return order
end

local function pieceIdOf(instance: Instance): string?
	local current: Instance? = instance
	while current do
		local id = current:GetAttribute("PieceId")
		if typeof(id) == "string" then
			local beat = current:GetAttribute("BeatId")
			return if typeof(beat) == "string" then beat .. "/" .. id else id
		end
		current = current.Parent
	end
	return nil
end

local function runTrial(
	model: Model,
	waypoints: { any },
	policy: string,
	decisionInterval: number,
	responseDelay: number,
	seed: number
)
	local pads = checkpointPads(model)
	local startPads = model.Start.Pads:GetChildren()
	table.sort(startPads, function(a, b)
		return a.Name < b.Name
	end)
	local firstPad = startPads[1] :: BasePart

	local rig, humanoid, root = buildRig()
	local hipHeight = humanoid.HipHeight + root.Size.Y / 2
	local relocations = {}
	local contacts = {}
	local lastContactAt: { [string]: number } = {}
	local started = os.clock()

	-- Per-trial door plan. Expert knows which slab gives (8.5 lets it use measured
	-- hazard windows); mid does not, and works the row centre-out, paying for
	-- every slab it bounces off first.
	local doorRows = resolveDoorRows(model)
	local doorPlan: { [BasePart]: boolean } = {}
	local doorAttempts: { [number]: number } = {}
	local doorEvents = {}
	-- A row this runner has already opened is behind it. Without this the target
	-- stays locked on the slab it just broke -- the row is still within the 36-stud
	-- approach radius -- so the runner walks back into the doorway, makes no
	-- forward progress, and the stall logic then sends it sideways along a row it
	-- has already passed. Measured on Door Dash's three rows before the fix: every
	-- trial parked at row 1.
	-- The slab the runner actually opened, and whether it has walked through it
	-- yet. Aiming at the NEXT row the moment a slab gives sends the runner
	-- diagonally into the solid slabs beside its own hole; a player walks through
	-- the hole it just made first.
	local openedSlab: { [number]: BasePart } = {}
	-- Which side of the slab the runner was on when it gave way, in the slab's own
	-- local Z. The row is not behind the runner until that sign flips.
	local openedSide: { [number]: number } = {}
	local rowCleared: { [number]: boolean } = {}
	local planRandom = Random.new(seed)
	for rowIndex, slabs in doorRows do
		local pool = {}
		for index = 1, #slabs do
			table.insert(pool, index)
		end
		for _ = 1, math.min(BREAKABLE_PER_ROW, #pool) do
			local pick = table.remove(pool, planRandom:NextInteger(1, #pool)) :: number
			doorPlan[slabs[pick]] = true
		end
		doorAttempts[rowIndex] = 1
	end

	-- CoursePresets builds every course piece with CanTouch = false so the kits
	-- own touch detection, which means a Touched connection on the rig can never
	-- fire against course geometry -- the first execution of this probe recorded
	-- zero contacts on every run for exactly that reason. Contacts are instead
	-- sampled by an overlap query against the Scriptables tree (kit-driven
	-- hazards, all CanQuery = true); Geometry is static floor and is not a
	-- contact. The per-piece cooldown matches the kits' own RetriggerCooldown so
	-- one continuous visit counts once.
	local scriptablesRoot = model:FindFirstChild("Scriptables")
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { rig }
	overlapParams.MaxParts = 32

	local function sampleContacts(elapsed: number)
		if not scriptablesRoot then
			return
		end
		for _, part in Workspace:GetPartBoundsInBox(root.CFrame, CONTACT_BOX, overlapParams) do
			if not part:IsDescendantOf(scriptablesRoot) then
				continue
			end
			local id = pieceIdOf(part)
			if not id then
				continue
			end
			if lastContactAt[id] and elapsed - lastContactAt[id] < CONTACT_COOLDOWN then
				continue
			end
			lastContactAt[id] = elapsed
			table.insert(contacts, { pieceId = id, t = math.round(elapsed * 100) / 100 })
		end
	end

	-- The same reach test Doors.tickPlayer applies, run for the scripted rig
	-- because that kit selects Players and a rig is not one.
	local function tickDoors(elapsed: number)
		for rowIndex, slabs in doorRows do
			for _, slab in slabs do
				if not doorPlan[slab] or not slab.CanCollide then
					continue
				end
				local reach = slab.Size
					+ Vector3.new(DOOR_CONTACT_PADDING * 2, DOOR_VERTICAL_PADDING * 2, DOOR_CONTACT_PADDING * 2)
				local offset = slab.CFrame:PointToObjectSpace(root.Position)
				if
					math.abs(offset.X) <= reach.X / 2
					and math.abs(offset.Y) <= reach.Y / 2
					and math.abs(offset.Z) <= reach.Z / 2
				then
					slab.CanCollide = false
					slab.CanQuery = false
					openedSlab[rowIndex] = slab
					openedSide[rowIndex] = if offset.Z >= 0 then 1 else -1
					table.insert(doorEvents, {
						row = rowIndex,
						door = slab.Name,
						t = math.round(elapsed * 100) / 100,
						attempts = doorAttempts[rowIndex] or 1,
					})
				end
			end
		end
	end

	-- Where the runner aims while a door row is in front of it. Expert goes
	-- straight for the slab that gives; mid works the row centre-out with no
	-- advance knowledge, which is what makes a wrong first guess cost time.
	local function doorTarget(position: Vector3): Vector3?
		for rowIndex, slabs in doorRows do
			if #slabs == 0 or rowCleared[rowIndex] then
				continue
			end
			local opened = openedSlab[rowIndex]
			if opened then
				local side = openedSide[rowIndex] or 1
				if opened.CFrame:PointToObjectSpace(position).Z * side < 0 then
					-- Out the other side: this row is behind the runner now. Releasing
					-- it on proximity alone released it while the runner was still in
					-- front of the slab, and it then walked diagonally into the solid
					-- slab beside its own opening.
					rowCleared[rowIndex] = true
					continue
				end
				-- Aim THROUGH the hole, eight studs past it, not at the slab itself.
				return opened.CFrame:PointToWorldSpace(Vector3.new(0, 0, -8 * side))
			end
			local centre = slabs[math.ceil(#slabs / 2)]
			if (position - centre.Position).Magnitude > 36 then
				continue
			end
			if policy == "expert" then
				for _, slab in slabs do
					if doorPlan[slab] then
						return slab.Position
					end
				end
			end
			local order = centreOutOrder(#slabs)
			local attempt = math.clamp(doorAttempts[rowIndex] or 1, 1, #order)
			return slabs[order[attempt]].Position
		end
		return nil
	end

	local function nextDoorAttempt(position: Vector3)
		for rowIndex, slabs in doorRows do
			if #slabs == 0 or rowCleared[rowIndex] or openedSlab[rowIndex] then
				continue
			end
			local centre = slabs[math.ceil(#slabs / 2)]
			if (position - centre.Position).Magnitude <= 36 then
				doorAttempts[rowIndex] = ((doorAttempts[rowIndex] or 1) % #slabs) + 1
				return
			end
		end
	end

	local function placeAt(position: Vector3, reason: string)
		root.CFrame = CFrame.new(position + Vector3.new(0, hipHeight + 1, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		table.insert(relocations, { reason = reason, at = os.clock() - started })
	end

	rig.Parent = Workspace
	placeAt(firstPad.Position + Vector3.new(0, firstPad.Size.Y / 2, 0), "initial seating")

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { rig }

	local random = Random.new(seed)
	local trajectory, falls, splits = {}, {}, {}
	local liquidY = liquidTop(model)
	local lastProgress = started
	local lastDoorNudge = started
	local lastTrajectoryAt = -1
	local lastDistance = math.huge
	local index = 1
	local dnf: string? = nil
	local lastCheckpointIndex = 0
	local lastCheckpointPosition = firstPad.Position + Vector3.new(0, firstPad.Size.Y / 2, 0)

	-- The clock starts when movement is released, which for a scripted trial is
	-- the moment after the single permitted initial seating (8.5).
	started = os.clock()
	lastProgress = started

	local doorAim: Vector3? = nil
	local lastAim: Vector3? = nil
	while index <= #waypoints do
		local waypoint = waypoints[index]
		doorAim = doorTarget(root.Position)
		local aim = doorAim or waypoint.Position
		-- Progress is measured against whatever the runner is actually walking at.
		-- A door row is worked sideways, so the distance to the NEXT WAYPOINT does
		-- not fall while the runner tries slabs, and a stuck detector keyed on the
		-- waypoint alone recorded a FAIL in the middle of the runner doing exactly
		-- the right thing: measured on Door Dash, an expert trial broke row 1 at
		-- 5.66 s and row 2 at 9.22 s and was then failed at 19.2 s for "no progress".
		if lastAim == nil or (aim - lastAim).Magnitude > 1 then
			-- Only the distance baseline resets. Rewinding lastProgress here let a
			-- runner sitting on the 36-stud door-approach boundary flicker between
			-- two aims and never record a stuck FAIL at all.
			lastAim = aim
			lastDistance = math.huge
		end
		humanoid:MoveTo(aim)
		-- The policy interval is how often the runner re-reads the course and
		-- re-aims (8.5). Jumping, falling and contact are resolved every frame
		-- inside it: a quarter-second reflex floor would be a harness artefact,
		-- not a mid-skill player, and it was what made the first execution of
		-- this probe stall at every gap.
		local deadline = os.clock()
			+ decisionInterval
			+ (if responseDelay > 0 then random:NextNumber(0, responseDelay) else 0)
		local settled = false
		repeat
			task.wait()
			local now = os.clock()
			local elapsed = now - started
			local position = root.Position
			local distance = (position * Vector3.new(1, 0, 1) - waypoint.Position * Vector3.new(1, 0, 1)).Magnitude
			sampleContacts(elapsed)
			tickDoors(elapsed)

			-- The trace is downsampled to two samples a second: a raw frame trace
			-- is larger than the whole result payload budget, and half a second
			-- still resolves every fall and split.
			if elapsed - lastTrajectoryAt >= 0.5 then
				lastTrajectoryAt = elapsed
				table.insert(trajectory, {
					t = math.round(elapsed * 100) / 100,
					x = math.round(position.X * 10) / 10,
					y = math.round(position.Y * 10) / 10,
					z = math.round(position.Z * 10) / 10,
					wp = waypoint.Id,
				})
			end

			for padIndex = lastCheckpointIndex + 1, #pads do
				local pad = pads[padIndex].Pad
				if (position - pad.Position).Magnitude < 12 then
					lastCheckpointIndex = padIndex
					lastCheckpointPosition = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
				end
			end

			if position.Y < liquidY + 1 then
				table.insert(falls, { t = elapsed, x = position.X, y = position.Y, z = position.Z, wp = waypoint.Id })
				-- The actual mode's .8 s checkpoint respawn is the second permitted
				-- relocation; it is paid for in the clock and logged, never skipped.
				task.wait(RESPAWN_SECONDS)
				placeAt(lastCheckpointPosition, "checkpoint respawn after fall at " .. waypoint.Id)
				-- A respawn puts the runner back BEFORE rows it had already crossed.
				-- The holes it made stay open (that is what the real kit does for the
				-- rest of the round), but the rows are ahead of it again, so it has to
				-- walk through those openings rather than beeline past them into the
				-- solid slab beside one.
				table.clear(rowCleared)
				-- Falling back to a checkpoint means re-walking from that beat: the
				-- cursor rewinds to the route waypoint nearest the pad it respawned on.
				local nearest, nearestDistance = index, math.huge
				for candidate = 1, #waypoints do
					local separation = (waypoints[candidate].Position - lastCheckpointPosition).Magnitude
					if separation < nearestDistance then
						nearestDistance = separation
						nearest = candidate
					end
				end
				index = math.max(1, math.min(index, nearest))
				lastProgress = os.clock()
				lastDistance = math.huge
				settled = true
			elseif distance < WAYPOINT_RADIUS then
				table.insert(splits, { id = waypoint.Id, beat = waypoint.Beat, t = elapsed, arc = waypoint.ArcLength })
				index += 1
				lastProgress = now
				lastDoorNudge = now
				lastDistance = math.huge
				settled = true
			else
				local aimDistance = (position * Vector3.new(1, 0, 1) - aim * Vector3.new(1, 0, 1)).Magnitude
				if aimDistance < lastDistance - 0.5 then
					lastProgress = now
					lastDistance = aimDistance
				end
				-- Jump from the ground when the floor runs out just ahead: a
				-- measured gap detector standing in for the takeoff markers. The
				-- probe sits close to the body so the takeoff is at the edge and
				-- the full measured 22-stud envelope is available, and a stalled
				-- runner also tries a jump before it is recorded as stuck.
				-- Never jump at a door row. The stall-jump below is a gap heuristic,
				-- and a door slab is a wall: measured on Door Dash, jumping into one
				-- repeatedly climbs it -- the rig reached the top of a 14.65-stud slab
				-- in about 0.6 s and then stood there for the rest of the run. A runner
				-- walks into a door; it either gives or it does not.
				local grounded = humanoid.FloorMaterial ~= Enum.Material.Air and doorAim == nil
				if grounded then
					local heading = (waypoint.Position - position) * Vector3.new(1, 0, 1)
					if heading.Magnitude > 0.1 then
						local probe = position + heading.Unit * 3
						local hit = Workspace:Raycast(probe, Vector3.new(0, -10, 0), rayParams)
						if not hit or now - lastProgress > 0.8 then
							humanoid.Jump = true
						end
					end
				end
				-- A stalled mid runner in front of a door row has guessed the wrong
				-- channel; it moves to the next one in centre-out order and pays
				-- for the mistake in the clock.
				-- A stalled mid runner in front of a door row guesses again, but the
				-- retry must NOT reset the progress clock past the stuck detector:
				-- rewinding lastProgress every 1.5 s kept `now - lastProgress` under
				-- 2.25 s forever, so a runner jammed at a row never recorded a stuck
				-- FAIL and burned the whole 150 s ceiling instead.
				if now - lastDoorNudge > 1.5 then
					lastDoorNudge = now
					nextDoorAttempt(position)
				end
				if now - lastProgress > STUCK_SECONDS then
					-- 8.5: a stuck state is a recorded FAIL, never a forced move.
					dnf = string.format("stuck for %d s before %s", STUCK_SECONDS, waypoint.Id)
					settled = true
				end
			end
			if elapsed > RUN_CEILING_SECONDS then
				dnf = "exceeded the " .. RUN_CEILING_SECONDS .. " s harness ceiling"
				settled = true
			end
		until settled or os.clock() >= deadline
		if dnf then
			break
		end
	end

	local cleared = dnf == nil and index > #waypoints
	local elapsed = os.clock() - started
	-- Restore every slab this trial broke, so the next reset faces a whole row.
	for _, slabs in doorRows do
		for _, slab in slabs do
			slab.CanCollide = true
			slab.CanQuery = true
		end
	end
	rig:Destroy()
	return {
		policy = policy,
		seed = seed,
		cleared = cleared,
		dnf = dnf,
		elapsedSeconds = elapsed,
		splits = splits,
		falls = falls,
		fallCount = #falls,
		contacts = contacts,
		contactCount = #contacts,
		distinctContacts = (function()
			local seen, count = {}, 0
			for _, contact in contacts do
				if not seen[contact.pieceId] then
					seen[contact.pieceId] = true
					count += 1
				end
			end
			return count
		end)(),
		relocations = relocations,
		relocationCount = #relocations,
		doorEvents = doorEvents,
		checkpointsEarned = lastCheckpointIndex,
		trajectorySamples = #trajectory,
		trajectory = trajectory,
	}
end

local ok, answer = xpcall(function()
	local spec = specFor(COURSE_ID)
	local injected = sources()

	local container = Instance.new("Folder")
	container.Name = "SplashdownRouteIsolation"
	container.Parent = Workspace

	-- Two builds from identical spec and sources: the section 5.1.12 determinism
	-- check, run through the same call stage() uses.
	local model, report = CourseBuilder.build(spec, injected)
	local secondModel, secondReport = CourseBuilder.build(spec, injected)
	local hashesMatch = report.SpecHash == secondReport.SpecHash
	secondModel:Destroy()

	model.Parent = container
	model:PivotTo(CFrame.new(ISOLATION_OFFSET))
	local waypoints = routeWaypoints(model, report)

	-- build.json is published before the trials, so a build that failed its
	-- route, bounds or attribute checks is visible immediately instead of after
	-- eight scripted runs.
	publishBuild(report, hashesMatch)

	if BUILD_ONLY then
		container:Destroy()
		return {
			courseId = COURSE_ID,
			placeId = game.PlaceId,
			buildOnly = true,
			specHash = report.SpecHash,
			rebuildHashMatches = hashesMatch,
			partCount = report.PartCount,
			routeLength = report.RouteLength,
			checkpointCount = report.CheckpointCount,
			buildOk = report.Ok,
			attributeErrors = report.AttributeErrors,
			routeErrors = report.RouteErrors,
			boundsViolations = report.Bounds.Violations,
			guideDeviation = report.GuideDeviation,
			guideLength = report.GuideLength,
			waypointCount = #waypoints,
			runs = {},
			contactedPieces = {},
			midCompletionRate = 0,
			expertCompletionRate = 0,
			pacePass = false,
			scopeNote = "BUILD_ONLY: the deterministic double build only; no scripted trials were run",
		}
	end

	-- Activate the hazards through the existing path so the scripted runs face
	-- moving obstacles rather than a static sculpture.
	local scriptables = model:FindFirstChild("Scriptables")
	if scriptables then
		ScriptableRoots.tag(scriptables)
	end
	task.wait(1)

	local runs = {}
	for trial = 1, EXPERT_RESETS do
		table.insert(runs, runTrial(model, waypoints, "expert", 0.05, 0, 900 + trial))
		task.wait(0.25)
	end
	for _, seed in MID_SEEDS do
		table.insert(runs, runTrial(model, waypoints, "mid", 0.25, 0.2, seed))
		task.wait(0.25)
	end

	if scriptables then
		ScriptableRoots.untag(scriptables)
	end
	container:Destroy()

	local midTimes, expertTimes = {}, {}
	local expertClean: number? = nil
	local contacted: { [string]: boolean } = {}
	for _, run in runs do
		for _, contact in run.contacts do
			contacted[contact.pieceId] = true
		end
		if run.policy == "mid" and run.cleared then
			table.insert(midTimes, run.elapsedSeconds)
		elseif run.policy == "expert" and run.cleared then
			table.insert(expertTimes, run.elapsedSeconds)
			if run.fallCount == 0 then
				expertClean = math.min(expertClean or math.huge, run.elapsedSeconds)
			end
		end
	end
	table.sort(midTimes)
	local median = if #midTimes > 0 then midTimes[math.ceil(#midTimes / 2)] else nil

	local contactedList = {}
	for pieceId in contacted do
		table.insert(contactedList, pieceId)
	end
	table.sort(contactedList)

	return {
		courseId = COURSE_ID,
		placeId = game.PlaceId,
		specHash = report.SpecHash,
		rebuildHashMatches = hashesMatch,
		partCount = report.PartCount,
		routeLength = report.RouteLength,
		checkpointCount = report.CheckpointCount,
		buildOk = report.Ok,
		attributeErrors = report.AttributeErrors,
		routeErrors = report.RouteErrors,
		boundsViolations = report.Bounds.Violations,
		beats = report.Beats,
		bounds = {
			MaxCornerDistance = report.Bounds.MaxCornerDistance,
			MaxGeometryCenterRadius = report.Bounds.MaxGeometryCenterRadius,
			MaxRouteRadius = report.Bounds.MaxRouteRadius,
			RouteMinY = report.Bounds.RouteMinY,
			RouteMaxY = report.Bounds.RouteMaxY,
			MinY = report.Bounds.MinY,
			MaxY = report.Bounds.MaxY,
			Violations = report.Bounds.Violations,
		},
		-- JSONEncode cannot serialize a Vector3, so the route trace is flattened
		-- to plain numbers before it leaves the probe.
		route = (function()
			local flattened = {}
			for _, step in report.Route do
				table.insert(flattened, {
					beat = step.BeatId,
					piece = step.PieceId,
					kind = step.Kind,
					x = math.round(step.Position.X * 100) / 100,
					y = math.round(step.Position.Y * 100) / 100,
					z = math.round(step.Position.Z * 100) / 100,
					yaw = step.Yaw,
					segment = step.Segment,
					segmentTravel = math.round(step.SegmentTravel * 100) / 100,
					arcLength = math.round(step.ArcLength * 100) / 100,
				})
			end
			return flattened
		end)(),
		guideDeviation = report.GuideDeviation,
		guideLength = report.GuideLength,
		waypointCount = #waypoints,
		runs = runs,
		midCompletionRate = #midTimes / #MID_SEEDS,
		midMedianSeconds = median,
		expertCleanSeconds = expertClean,
		expertCompletionRate = #expertTimes / EXPERT_RESETS,
		contactedPieces = contactedList,
		studsPerSecondMid = if median then report.RouteLength / median else nil,
		pacePass = median ~= nil
			and median >= 60
			and median <= 90
			and expertClean ~= nil
			and expertClean <= 0.6 * median,
		scopeNote = "scripted proxy only; not a human skill classification and not the required interactive keyboard run",
	}
end, debug.traceback)

writeChunked(HttpService:JSONEncode({ ok = ok, result = answer }))

-- routes.json is the scripted-trial half of the record; build.json was already
-- published before the trials started. Trajectories stay out of both: they are
-- the bulk of the payload and the chunked StringValue above keeps the full
-- record for anyone who wants it.
local published = "not attempted"
if ok and not (answer :: any).buildOnly then
	local r = answer :: any
	local trimmedRuns = {}
	for _, run in r.runs do
		local beatSplits = {}
		for _, split in run.splits do
			local previous = beatSplits[#beatSplits]
			if not previous or previous.beat ~= split.beat then
				table.insert(beatSplits, { beat = split.beat, firstPiece = split.id, t = split.t, arc = split.arc })
			end
		end
		table.insert(trimmedRuns, {
			policy = run.policy,
			seed = run.seed,
			cleared = run.cleared,
			dnf = run.dnf,
			elapsedSeconds = run.elapsedSeconds,
			fallCount = run.fallCount,
			falls = run.falls,
			contactCount = run.contactCount,
			distinctContacts = run.distinctContacts,
			contacts = run.contacts,
			relocations = run.relocations,
			doorEvents = run.doorEvents,
			checkpointsEarned = run.checkpointsEarned,
			trajectorySamples = run.trajectorySamples,
			beatSplits = beatSplits,
		})
	end
	local base = "courses/" .. r.courseId .. "/"
	local routesWrite = publish(base .. "routes.json", {
		courseId = r.courseId,
		placeId = r.placeId,
		specHash = r.specHash,
		routeLength = r.routeLength,
		midCompletionRate = r.midCompletionRate,
		midMedianSeconds = r.midMedianSeconds,
		expertCleanSeconds = r.expertCleanSeconds,
		expertCompletionRate = r.expertCompletionRate,
		studsPerSecondMid = r.studsPerSecondMid,
		pacePass = r.pacePass,
		contactedPieces = r.contactedPieces,
		scopeNote = r.scopeNote,
		runs = trimmedRuns,
	})
	published = routesWrite
end
print("[run-course-routes] ok=" .. tostring(ok) .. " " .. result.Value .. " | " .. published)
