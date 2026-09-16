-- Name: CourseQA.luau
-- Author: Jack C.
-- Description: Independent acceptance audit for one built course model (HANDOFF.md section 8). Every figure comes from real Workspace raycasts on a disposable clone, from enumerated instances, or from the declarative spec's own encounter table; nothing trusts a spec annotation about geometry. Checks this module cannot measure without a live playtest are reported NOT RUN with a reason, never as an implied pass.
-- Created: 2026-09-15

--!strict

local CourseGraph = require(script.Parent.CourseGraph)

local CourseQA = {}

export type Calibration = {
	-- docs/splashdown/evidence/movement-final.json: 22-stud flat gap succeeds and
	-- 22.25 fails; an 11.5-stud ledge succeeds and 11.75 fails. HANDOFF 3.2.
	MaxGapStuds: number,
	MaxStepStuds: number,
	WalkSpeed: number,
	JumpHeight: number,
	Gravity: number,
	RootOffsetStuds: number,
	SlopeLimitDegrees: number,
	SampleStep: number,
	RefineStep: number,
}

CourseQA.DefaultCalibration = {
	MaxGapStuds = 22,
	MaxStepStuds = 11.5,
	WalkSpeed = 26,
	JumpHeight = 10,
	Gravity = 120,
	RootOffsetStuds = 3.5,
	SlopeLimitDegrees = 45,
	SampleStep = 1,
	RefineStep = 0.25,
} :: Calibration

export type SurfaceCell = {
	Key: string,
	Position: Vector3,
	Normal: Vector3,
	Beat: string?,
	PieceId: string?,
	Headroom: number,
	Standable: boolean,
}

export type Finding = { Check: string, Status: string, Detail: string }

export type Report = {
	CourseId: string,
	SpecHash: string,
	SourceHash: string,
	PlaceId: number,
	Calibration: Calibration,
	SampleResolution: { Coarse: number, Refined: number },
	TestTime: string,
	Status: string,
	Errors: { string },
	Warnings: { string },
	NotRun: { string },
	Counts: { [string]: number },
	Findings: { Finding },
	Encounters: { { Id: string, Beat: string, Type: string, Family: string } },
}

local function key(x: number, z: number, y: number): string
	return string.format("%d:%d:%d", math.round(x * 4), math.round(z * 4), math.round(y * 4))
end

-- 8.2.1-8.2.2: real downward rays on a 1-stud grid, continuing below each hit so
-- stacked surfaces (reachable roofs and rail tops, which are shortcuts) are all
-- retained, not just the highest roof. Liquid, QA volumes and the perimeter ring
-- are excluded because they are not walkable course surfaces.
--
-- The grid is laid over each candidate part's own footprint rather than over the
-- whole model bounding box: the 780-stud boundary ring would otherwise force
-- hundreds of thousands of empty columns and blow the Studio script budget
-- without sampling one extra surface.
function CourseQA.sampleSurfaces(model: Model, calibration: Calibration, step: number?): { SurfaceCell }
	local spacing = step or calibration.SampleStep
	local include: { Instance } = {}
	for _, name in { "Geometry", "Scriptables", "Start", "Checkpoints", "Finish" } do
		local child = model:FindFirstChild(name)
		if child then
			table.insert(include, child)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	params.IgnoreWater = true
	params.RespectCanCollide = true

	local minSlopeNormalY = math.cos(math.rad(calibration.SlopeLimitDegrees))
	local cells: { SurfaceCell } = {}
	local seen: { [string]: boolean } = {}
	local columns: { [string]: boolean } = {}
	local budget = 0

	local function sampleColumn(x: number, z: number, top: number, bottom: number)
		local columnKey = string.format("%d,%d", math.round(x / spacing), math.round(z / spacing))
		if columns[columnKey] then
			return
		end
		columns[columnKey] = true
		local rayY = top
		local guard = 0
		while rayY > bottom and guard < 12 do
			guard += 1
			budget += 1
			if budget % 4000 == 0 then
				task.wait()
			end
			local hit = workspace:Raycast(Vector3.new(x, rayY, z), Vector3.new(0, bottom - rayY, 0), params)
			if not hit then
				break
			end
			local cellKey = key(x, z, hit.Position.Y)
			if not seen[cellKey] then
				seen[cellKey] = true
				local up = workspace:Raycast(
					hit.Position + Vector3.new(0, 0.2, 0),
					Vector3.new(0, top - hit.Position.Y, 0),
					params
				)
				table.insert(cells, {
					Key = cellKey,
					Position = hit.Position,
					Normal = hit.Normal,
					Beat = hit.Instance:GetAttribute("BeatId") :: string?,
					PieceId = hit.Instance:GetAttribute("PieceId") :: string?,
					Headroom = if up then (up.Position.Y - hit.Position.Y) else math.huge,
					Standable = hit.Normal.Y >= minSlopeNormalY,
				})
			end
			rayY = hit.Position.Y - 0.1
		end
	end

	for _, container in include do
		for _, part in container:GetDescendants() do
			if not part:IsA("BasePart") or not part.CanCollide then
				continue
			end
			local half = part.Size / 2
			local extentX, extentZ = 0, 0
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner =
							part.CFrame:VectorToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						extentX = math.max(extentX, math.abs(corner.X))
						extentZ = math.max(extentZ, math.abs(corner.Z))
					end
				end
			end
			local top = part.Position.Y + half.Magnitude + 6
			local bottom = part.Position.Y - half.Magnitude - 6
			local x = part.Position.X - extentX
			while x <= part.Position.X + extentX do
				local z = part.Position.Z - extentZ
				while z <= part.Position.Z + extentZ do
					sampleColumn(x, z, top, bottom)
					z += spacing
				end
				x += spacing
			end
		end
	end
	return cells
end

-- 8.2.3-8.2.5: nodes are real support cells; walk edges need a climbable measured
-- step, jump edges need the measured 22-stud/11.5-step envelope. Ballistic
-- clearance is sampled along the arc rather than assumed from Euclidean distance.
function CourseQA.buildGraph(cells: { SurfaceCell }, calibration: Calibration): CourseGraph.Graph
	local graph = CourseGraph.new()
	local standable: { SurfaceCell } = {}
	for _, cell in cells do
		if cell.Standable and cell.Headroom >= 5 then
			table.insert(standable, cell)
			CourseGraph.addNode(graph, {
				Id = cell.Key,
				Beat = cell.Beat or "unowned",
				Position = cell.Position,
			})
		end
	end

	-- Column index at the sampling resolution: walk edges only ever connect
	-- neighbouring columns, so they resolve by direct lookup instead of a radius
	-- scan over every other cell.
	-- Numeric column keys: the jump pass does millions of index lookups, and
	-- string.format there dominates the whole audit.
	local spacing = calibration.SampleStep
	local STRIDE = 1000000
	local byColumn: { [number]: { SurfaceCell } } = {}
	for _, cell in standable do
		local id = math.round(cell.Position.X / spacing) * STRIDE + math.round(cell.Position.Z / spacing)
		byColumn[id] = byColumn[id] or {}
		table.insert(byColumn[id], cell)
	end

	local neighbours = { STRIDE, -STRIDE, 1, -1 }
	local edgeCells: { SurfaceCell } = {}
	for _, cell in standable do
		local base = math.round(cell.Position.X / spacing) * STRIDE + math.round(cell.Position.Z / spacing)
		local open = false
		for _, offset in neighbours do
			local connected = false
			for _, other in byColumn[base + offset] or {} do
				if math.abs(other.Position.Y - cell.Position.Y) <= calibration.MaxStepStuds then
					CourseGraph.addEdge(graph, { From = cell.Key, To = other.Key, Kind = "Walk" })
					connected = true
				end
			end
			if not connected then
				open = true
			end
		end
		-- Only cells on a surface boundary can start or receive a jump, which is
		-- both physically true and what keeps the jump pass tractable.
		if open then
			table.insert(edgeCells, cell)
		end
	end

	local reach = math.ceil(calibration.MaxGapStuds / spacing)
	local edgeByColumn: { [number]: { SurfaceCell } } = {}
	for _, cell in edgeCells do
		local id = math.round(cell.Position.X / spacing) * STRIDE + math.round(cell.Position.Z / spacing)
		edgeByColumn[id] = edgeByColumn[id] or {}
		table.insert(edgeByColumn[id], cell)
	end
	local maxGapSquared = calibration.MaxGapStuds ^ 2
	local minJumpSquared = (spacing * 1.6) ^ 2
	local processed = 0
	for _, cell in edgeCells do
		local base = math.round(cell.Position.X / spacing) * STRIDE + math.round(cell.Position.Z / spacing)
		for dx = -reach, reach do
			local column = base + dx * STRIDE
			for dz = -reach, reach do
				local bucket = edgeByColumn[column + dz]
				if bucket == nil then
					continue
				end
				for _, other in bucket do
					if other.Key == cell.Key then
						continue
					end
					local dxw = other.Position.X - cell.Position.X
					local dzw = other.Position.Z - cell.Position.Z
					local flatSquared = dxw * dxw + dzw * dzw
					if
						flatSquared > minJumpSquared
						and flatSquared <= maxGapSquared
						and other.Position.Y - cell.Position.Y <= calibration.MaxStepStuds
					then
						CourseGraph.addEdge(graph, { From = cell.Key, To = other.Key, Kind = "Jump" })
					end
				end
			end
		end
		processed += 1
		if processed % 200 == 0 then
			task.wait()
		end
	end
	return graph
end

local function gateBoxes(model: Model): { { Id: string, Box: { Min: Vector3, Max: Vector3 } } }
	local result = {}
	local qa = model:FindFirstChild("QA")
	local gates = qa and qa:FindFirstChild("Gates")
	for _, gate in (gates and gates:GetChildren() or {}) do
		if gate:IsA("BasePart") then
			local half = gate.Size / 2
			local corners: { Vector3 } = {}
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						table.insert(
							corners,
							gate.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						)
					end
				end
			end
			local min, max = corners[1], corners[1]
			for _, corner in corners do
				min = Vector3.new(math.min(min.X, corner.X), math.min(min.Y, corner.Y), math.min(min.Z, corner.Z))
				max = Vector3.new(math.max(max.X, corner.X), math.max(max.Y, corner.Y), math.max(max.Z, corner.Z))
			end
			table.insert(result, { Id = gate.Name, Box = { Min = min, Max = max } })
		end
	end
	return result
end

local function nearestNode(graph: CourseGraph.Graph, position: Vector3): CourseGraph.NodeId?
	local best: CourseGraph.NodeId? = nil
	local bestDistance = math.huge
	for id, node in graph.Nodes do
		local distance = (node.Position - position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			best = id
		end
	end
	if bestDistance > 24 then
		return nil
	end
	return best
end

-- 8.2.7-8.2.8: an intended path from every spawn cell through the ordered
-- checkpoints to Finish, and every beat gate must be a true cut set.
function CourseQA.checkCutSets(model: Model, graph: CourseGraph.Graph): ({ Finding }, { string })
	local findings: { Finding } = {}
	local errors: { string } = {}

	local spawnNodes: { CourseGraph.NodeId } = {}
	local pads = model:FindFirstChild("Start") and (model.Start :: Instance):FindFirstChild("Pads")
	for _, pad in (pads and pads:GetChildren() or {}) do
		if pad:IsA("BasePart") then
			local node = nearestNode(graph, pad.Position)
			if node then
				table.insert(spawnNodes, node)
			else
				table.insert(errors, string.format("start pad %s has no walkable cell within 24 studs", pad.Name))
			end
		end
	end

	local waypoints: { CourseGraph.NodeId } = {}
	local checkpoints = model:FindFirstChild("Checkpoints")
	local checkpointChildren = checkpoints and checkpoints:GetChildren() or {}
	table.sort(checkpointChildren, function(left, right)
		return left.Name < right.Name
	end)
	for _, checkpoint in checkpointChildren do
		local pad = checkpoint:FindFirstChild("Pad")
		if pad and pad:IsA("BasePart") then
			local node = nearestNode(graph, pad.Position)
			if node then
				table.insert(waypoints, node)
			else
				table.insert(errors, string.format("%s pad has no walkable cell within 24 studs", checkpoint.Name))
			end
		end
	end
	local finish = model:FindFirstChild("Finish")
	local deck = finish and finish:FindFirstChild("Deck")
	local finishNode = if deck and deck:IsA("BasePart") then nearestNode(graph, deck.Position) else nil
	if finishNode then
		table.insert(waypoints, finishNode)
	else
		table.insert(errors, "Finish.Deck has no walkable cell within 24 studs")
	end

	if #spawnNodes > 0 and #waypoints > 0 then
		-- One reverse traversal per leg answers "can every source reach this
		-- waypoint", instead of one forward traversal per (source, waypoint) pair.
		local failedLegs = 0
		local previous: { CourseGraph.NodeId } = spawnNodes
		local previousLabel = "spawn cells"
		for _, waypoint in waypoints do
			local reaching = CourseGraph.reachingNodes(graph, { waypoint })
			local missing = 0
			for _, node in previous do
				if not reaching[node] then
					missing += 1
				end
			end
			if missing > 0 then
				failedLegs += 1
				table.insert(
					errors,
					string.format(
						"%d of %d %s cannot reach %s in the sampled graph",
						missing,
						#previous,
						previousLabel,
						waypoint
					)
				)
			end
			previous = { waypoint }
			previousLabel = "the previous waypoint"
			task.wait()
		end
		table.insert(findings, {
			Check = "OrderedRouteFromEverySpawn",
			Status = if failedLegs == 0 then "PASS" else "FAIL",
			Detail = string.format(
				"%d spawn cells, %d ordered waypoints, %d failing legs",
				#spawnNodes,
				#waypoints,
				failedLegs
			),
		})

		if finishNode then
			local spawnSet: { [CourseGraph.NodeId]: boolean } = {}
			for _, node in spawnNodes do
				spawnSet[node] = true
			end
			for _, gate in gateBoxes(model) do
				local reaching = CourseGraph.reachingNodes(graph, { finishNode }, { Gates = { gate.Box } })
				local leaks = 0
				for node in spawnSet do
					if reaching[node] then
						leaks += 1
					end
				end
				local bypass = ""
				if leaks > 0 then
					-- Trace one actual bypass so the failure names the route rather
					-- than just its existence.
					local leaking: CourseGraph.NodeId? = nil
					for _, node in spawnNodes do
						if reaching[node] then
							leaking = node
							break
						end
					end
					local path = if leaking
						then CourseGraph.tracePath(graph, leaking, finishNode, { Gates = { gate.Box } })
						else nil
					if path then
						-- Report the hops that actually matter: every edge that
						-- changes beat, or that is not a plain Walk, with both
						-- endpoints and the edge kind. That is the edge to close.
						local kindOf: { [string]: string } = {}
						for _, edge in graph.Edges do
							kindOf[edge.From .. ">" .. edge.To] = edge.Kind
						end
						local steps: { string } = {}
						for step = 2, #path do
							local fromNode = graph.Nodes[path[step - 1]]
							local toNode = graph.Nodes[path[step]]
							local kind = kindOf[path[step - 1] .. ">" .. path[step]] or "?"
							if fromNode.Beat ~= toNode.Beat or kind ~= "Walk" then
								table.insert(
									steps,
									string.format(
										"%s(%.0f,%.0f,%.0f) -%s-> %s(%.0f,%.0f,%.0f)",
										fromNode.Beat,
										fromNode.Position.X,
										fromNode.Position.Y,
										fromNode.Position.Z,
										kind,
										toNode.Beat,
										toNode.Position.X,
										toNode.Position.Y,
										toNode.Position.Z
									)
								)
							end
						end
						bypass = string.format(
							"; bypass is %d cells, non-walk or beat-changing hops: %s",
							#path,
							table.concat(steps, " | ")
						)
					end
					table.insert(
						errors,
						string.format(
							"gate %s is not a cut set: %d spawn cells still reach Finish%s",
							gate.Id,
							leaks,
							bypass
						)
					)
				end
				table.insert(findings, {
					Check = "GateCutSet:" .. gate.Id,
					Status = if leaks == 0 then "PASS" else "FAIL",
					Detail = string.format("%d of %d spawn cells bypass this gate%s", leaks, #spawnNodes, bypass),
				})
				task.wait()
			end
		end
	end
	return findings, errors
end

-- 8.3: every declared open transition classified against the measured envelope.
-- Supported flush joins are chained pieces, not gaps, so only Advance pieces are
-- tested; unintended reachable-looking gaps are caught separately by the graph.
function CourseQA.auditGaps(spec: any, route: { any }, calibration: Calibration): ({ Finding }, { string })
	local findings: { Finding } = {}
	local errors: { string } = {}
	local lower = calibration.MaxGapStuds * 0.6
	local upper = calibration.MaxGapStuds * 0.9
	local launchPieces: { [string]: boolean } = {}
	for _, beat in spec.Beats do
		for _, piece in beat.Pieces do
			if piece.Preset == "JumpPad" or piece.Preset == "Fan" or piece.Preset == "BigBall" then
				launchPieces[beat.Id] = true
			end
		end
	end
	for _, step in route do
		if step.Kind ~= "Advance" or step.ArcLength <= 0 then
			continue
		end
		local isLaunchBeat = launchPieces[step.BeatId] == true
		local status = "PASS"
		local detail = string.format("%.2f studs", step.ArcLength)
		if isLaunchBeat then
			-- 8.3: launches and moving-platform transfers use their own measured
			-- reach window; do not force them through the ordinary gap formula.
			status = "NOT RUN"
			detail ..= " (launch/ball transfer: needs a measured reach window, not the 13.2-19.8 rule)"
		elseif step.ArcLength < lower or step.ArcLength > upper then
			status = "FAIL"
			detail ..= string.format(" outside the %.1f-%.1f ordinary jump window", lower, upper)
			table.insert(errors, string.format("%s/%s gap %s", step.BeatId, step.PieceId, detail))
		end
		table.insert(
			findings,
			{ Check = string.format("Gap:%s/%s", step.BeatId, step.PieceId), Status = status, Detail = detail }
		)
	end
	return findings, errors
end

-- 8.4 variety, scored on encounters exactly as section 7 defines them.
local ENCOUNTER_TYPES: { [string]: string } = {
	Conveyor = "Conveyor",
	Bumper = "Bumper",
	BigBall = "BigBall",
	Sweeper = "RotorBump",
	Piston = "RotorBump",
	Hammer = "RotorBump",
	Fan = "Fan",
	JumpPad = "JumpPad",
	-- A Rotor plus a Shove is one RotorBump, never two kits (section 7 override 3),
	-- which is why every single-mesh spinner and the swing panel land here.
	Spinner = "RotorBump",
	SwingPanel = "RotorBump",
	Mace = "RotorBump",
	PaddleWheel = "RotorBump",
	Mallet = "RotorBump",
	RidePlatform = "RotatingPlatforms",
	Door = "Door",
	FoamPit = "FoamPit",
	-- A seesaw is scored on its board ("Seesaw: each board") and a beach ball on the
	-- ball ("BeachBall: each ball"), exactly as section 7's counting rule lists them.
	Seesaw = "Seesaw",
	BeachBall = "BeachBall",
	-- Deliberately absent, because they are support geometry and never an
	-- encounter: Platform, Ramp, Slide, Corner, Fill, Prop and RoundLanding.
}

-- HANDOFF section 7 override 2 caps each NON-GLUE mechanic at three of the six
-- new courses. Glue -- pendulum and spinner RotorBumps, bumpers, jump pads, foam
-- pits, static ramps, slides and tunnels -- may appear anywhere, so the cap is
-- keyed on the preset rather than the encounter type: a piston and a pendulum
-- both score as RotorBump, but only the piston is capped.
local NON_GLUE_PRESETS: { [string]: boolean } = {
	Conveyor = true,
	Fan = true,
	Seesaw = true,
	FallingTile = true,
	Door = true,
	Piston = true,
	Sweeper = true,
	BeachBall = true,
	RidePlatform = true,
	BigBall = true,
	-- A mace is a pendulum and stays glue; a paddle wheel is a distinct rolling
	-- drum rather than a swinging bar, so it is capped with the sweepers/log-rolls
	-- section 7's override 2 names. Section 7's own tables use it twice (Door Dash
	-- 03, Tumble Tunnels 06), inside the three-course cap either way.
	PaddleWheel = true,
}

function CourseQA.auditVariety(spec: any): ({ Finding }, { string }, { string }, {
	{
		Id: string,
		Beat: string,
		Type: string,
		Family: string,
	}
})
	local findings: { Finding } = {}
	local errors: { string } = {}
	local warnings: { string } = {}
	local encounters: { { Id: string, Beat: string, Type: string, Family: string } } = {}
	local families: { [string]: boolean } = {}
	local typeCounts: { [string]: number } = {}

	local instanceCounts: { [string]: number } = {}
	local seenGroups: { [string]: boolean } = {}
	for _, beat in spec.Beats do
		families[beat.Family] = true
		for _, piece in beat.Pieces do
			local encounterType = piece.Preset and ENCOUNTER_TYPES[piece.Preset]
			if not encounterType then
				continue
			end
			instanceCounts[encounterType] = (instanceCounts[encounterType] or 0) + 1
			-- Section 7 override 3: an encounter is one thing the runner solves as
			-- a unit, so a grouped chicane scores once however many slabs it has.
			local group = piece.EncounterGroup
			if group then
				local groupKey = beat.Id .. "/" .. group
				if seenGroups[groupKey] then
					continue
				end
				seenGroups[groupKey] = true
			end
			table.insert(encounters, {
				Id = group or piece.Id,
				Beat = beat.Id,
				Type = encounterType,
				Family = beat.Family,
			})
			typeCounts[encounterType] = (typeCounts[encounterType] or 0) + 1
		end
	end

	local total = #encounters
	local distinctTypes = 0
	local dominantType, dominantCount = "", 0
	for encounterType, count in typeCounts do
		distinctTypes += 1
		if count > dominantCount then
			dominantType, dominantCount = encounterType, count
		end
	end
	local familyCount = 0
	for _ in families do
		familyCount += 1
	end

	local function expect(check: string, ok: boolean, detail: string)
		table.insert(findings, { Check = check, Status = if ok then "PASS" else "FAIL", Detail = detail })
		if not ok then
			table.insert(errors, check .. ": " .. detail)
		end
	end

	expect("EncounterTypes>=6", distinctTypes >= 6, string.format("%d distinct encounter types", distinctTypes))
	expect("Families>=4", familyCount >= 4, string.format("%d distinct families", familyCount))
	expect(
		"DominantType<=40%",
		total > 0 and dominantCount / total <= 0.4,
		string.format(
			"%s is %d of %d (%.1f%%)",
			dominantType,
			dominantCount,
			total,
			total > 0 and dominantCount / total * 100 or 0
		)
	)

	local run, runType, worstRun = 0, "", 0
	for _, encounter in encounters do
		if encounter.Type == runType then
			run += 1
		else
			runType, run = encounter.Type, 1
		end
		worstRun = math.max(worstRun, run)
	end
	expect("SameTypeRun<=3", worstRun <= 3, string.format("longest same-type run is %d", worstRun))

	-- The climax is the second-to-last beat (HANDOFF 3.2); Difficulty is declared
	-- per course, so this is checked structurally by encounter density instead of
	-- a self-reported difficulty number.
	local perBeat: { [string]: number } = {}
	for _, encounter in encounters do
		perBeat[encounter.Beat] = (perBeat[encounter.Beat] or 0) + 1
	end
	local lastBeat = spec.Beats[#spec.Beats].Id
	local climaxBeat = spec.Beats[#spec.Beats - 1].Id
	if (perBeat[lastBeat] or 0) > (perBeat[climaxBeat] or 0) then
		table.insert(
			warnings,
			string.format(
				"final beat %s carries %d encounters against climax %s's %d; 3.2 wants the final sprint short and easier",
				lastBeat,
				perBeat[lastBeat] or 0,
				climaxBeat,
				perBeat[climaxBeat] or 0
			)
		)
	end
	return findings, errors, warnings, encounters
end

-- 8.4 / section 7 override 2: the three cross-course rules, scored over every
-- spec that exists rather than over one course. A violation fails the set, so
-- the findings and errors are returned into the selected course's report.
function CourseQA.auditCrossCourse(allSpecs: { [string]: any }): ({ Finding }, { string })
	local findings: { Finding } = {}
	local errors: { string } = {}

	local ids: { string } = {}
	for id in allSpecs do
		table.insert(ids, id)
	end
	table.sort(ids)
	if #ids < 2 then
		table.insert(findings, {
			Check = "CrossCourse",
			Status = "NOT RUN",
			Detail = string.format("only %d spec exists; the cross-course rules need at least two", #ids),
		})
		return findings, errors
	end

	local function expect(check: string, ok: boolean, detail: string)
		table.insert(findings, { Check = check, Status = if ok then "PASS" else "FAIL", Detail = detail })
		if not ok then
			table.insert(errors, check .. ": " .. detail)
		end
	end

	-- Per course: the encounter type of every beat, the beat's dominant type, the
	-- course's DECLARED headline and the presets it uses. The headline is read
	-- from the spec, never inferred from frequency: section 7 names it per course
	-- ("Headline: three Big Balls over liquid; Big Balls appear nowhere else"),
	-- and the most frequent type is usually the glue instead -- RotorBump is the
	-- commonest encounter in four of the six courses and is nobody's headline.
	local courseHeadline: { [string]: string } = {}
	local beatDominant: { [string]: { [string]: string } } = {}
	local courseRecipes: { [string]: { [string]: string } } = {}
	local presetCourses: { [string]: { [string]: boolean } } = {}

	for _, id in ids do
		local spec = allSpecs[id]
		local courseCounts: { [string]: number } = {}
		beatDominant[id] = {}
		courseRecipes[id] = {}
		for _, beat in spec.Beats do
			local counts: { [string]: number } = {}
			local recipe: { string } = {}
			local seenGroups: { [string]: boolean } = {}
			for _, piece in beat.Pieces do
				local preset = piece.Preset
				if not preset then
					continue
				end
				if NON_GLUE_PRESETS[preset] then
					presetCourses[preset] = presetCourses[preset] or {}
					presetCourses[preset][id] = true
				end
				local encounterType = ENCOUNTER_TYPES[preset]
				if not encounterType then
					continue
				end
				local group = piece.EncounterGroup
				if group then
					local groupKey = beat.Id .. "/" .. group
					if seenGroups[groupKey] then
						continue
					end
					seenGroups[groupKey] = true
				end
				counts[encounterType] = (counts[encounterType] or 0) + 1
				courseCounts[encounterType] = (courseCounts[encounterType] or 0) + 1
				table.insert(recipe, encounterType)
			end
			local dominant, best = "", 0
			for encounterType, count in counts do
				if count > best or (count == best and encounterType < dominant) then
					dominant, best = encounterType, count
				end
			end
			beatDominant[id][beat.Id] = dominant
			table.sort(recipe)
			courseRecipes[id][beat.Id] =
				string.format("%s|%s|%s", beat.Family, beat.Mechanic, table.concat(recipe, ","))
		end
		local declared = spec.Headline
		if typeof(declared) ~= "string" or declared == "" then
			table.insert(errors, string.format("CrossCourse:%s: the spec declares no Headline encounter type", id))
			declared = ""
		elseif courseCounts[declared] == nil then
			table.insert(
				errors,
				string.format("CrossCourse:%s: declared headline %s does not occur in the course", id, declared)
			)
		end
		courseHeadline[id] = declared
	end

	-- Rule 1: a course's headline is not the dominant mechanic of another
	-- course's climax (second-to-last) beat, and is dominant in at most one beat
	-- outside its own course.
	for _, id in ids do
		local headline = courseHeadline[id]
		local outsideDominant = 0
		local climaxClash: { string } = {}
		for _, other in ids do
			if other == id then
				continue
			end
			local spec = allSpecs[other]
			local climax = spec.Beats[#spec.Beats - 1]
			if climax and beatDominant[other][climax.Id] == headline then
				table.insert(climaxClash, other .. "/" .. climax.Id)
			end
			for _, beat in spec.Beats do
				if beatDominant[other][beat.Id] == headline then
					outsideDominant += 1
				end
			end
		end
		expect(
			string.format("HeadlineNotAnotherClimax:%s", id),
			#climaxClash == 0,
			string.format("headline %s; clashes: %s", headline, table.concat(climaxClash, ", "))
		)
		expect(
			string.format("HeadlineDominantOutside<=1:%s", id),
			outsideDominant <= 1,
			string.format("headline %s dominates %d beats outside %s", headline, outsideDominant, id)
		)
	end

	-- Rule 2: at most three of the six new courses use any one non-glue mechanic.
	local presets: { string } = {}
	for preset in presetCourses do
		table.insert(presets, preset)
	end
	table.sort(presets)
	for _, preset in presets do
		local users: { string } = {}
		for id in presetCourses[preset] do
			table.insert(users, id)
		end
		table.sort(users)
		expect(
			string.format("NonGlueCap<=3:%s", preset),
			#users <= 3,
			string.format("used by %d courses: %s", #users, table.concat(users, ", "))
		)
	end

	-- Rule 3: no two beats in different courses share family + mechanic +
	-- encounter recipe.
	local seenRecipes: { [string]: string } = {}
	local clashes: { string } = {}
	for _, id in ids do
		for beatId, recipe in courseRecipes[id] do
			local owner = seenRecipes[recipe]
			if owner and string.sub(owner, 1, #id + 1) ~= id .. "/" then
				table.insert(clashes, string.format("%s/%s == %s (%s)", id, beatId, owner, recipe))
			else
				seenRecipes[recipe] = id .. "/" .. beatId
			end
		end
	end
	expect(
		"NoSharedBeatRecipe",
		#clashes == 0,
		if #clashes == 0 then "no beat recipe repeats across courses" else table.concat(clashes, " ; ")
	)

	return findings, errors
end

-- 8.4: no hazard/gap/elevation-free 24x24 breather square on the route. Start and
-- finish plazas are exempt by 5.1.9.
function CourseQA.auditCoverage(model: Model, cells: { SurfaceCell }): ({ Finding }, { string })
	local findings: { Finding } = {}
	local warnings: { string } = {}
	local exempt: { BasePart } = {}
	local geometry = model:FindFirstChild("Geometry")
	for _, child in (geometry and geometry:GetChildren() or {}) do
		if child:IsA("BasePart") and (child.Name:find("startplaza") or child.Name:find("finishplaza")) then
			table.insert(exempt, child)
		end
	end

	local occupied: { [string]: number } = {}
	for _, cell in cells do
		if not cell.Standable then
			continue
		end
		local skip = false
		for _, plaza in exempt do
			local local2 = plaza.CFrame:PointToObjectSpace(cell.Position)
			if
				math.abs(local2.X) <= plaza.Size.X / 2
				and math.abs(local2.Z) <= plaza.Size.Z / 2
				and math.abs(local2.Y) <= plaza.Size.Y
			then
				skip = true
				break
			end
		end
		if not skip then
			local cellKey = string.format("%d,%d", math.floor(cell.Position.X), math.floor(cell.Position.Z))
			local existing = occupied[cellKey]
			if existing == nil or cell.Position.Y > existing then
				occupied[cellKey] = cell.Position.Y
			end
		end
	end

	-- Largest all-flat square by the standard dynamic-programming recurrence:
	-- square(x,z) = min(square(x-1,z), square(x,z-1), square(x-1,z-1)) + 1 when
	-- this cell is level with its west, north and north-west neighbours. Linear in
	-- the number of occupied columns instead of cubic in the window size.
	local square: { [string]: number } = {}
	local ordered: { { x: number, z: number, y: number } } = {}
	for cellKey, height in occupied do
		local cx, cz = cellKey:match("(-?%d+),(-?%d+)")
		table.insert(ordered, { x = tonumber(cx) :: number, z = tonumber(cz) :: number, y = height })
	end
	table.sort(ordered, function(left, right)
		if left.x ~= right.x then
			return left.x < right.x
		end
		return left.z < right.z
	end)

	local worst = 0
	for _, cell in ordered do
		local function level(dx: number, dz: number): number?
			local neighbour = occupied[string.format("%d,%d", cell.x + dx, cell.z + dz)]
			if neighbour == nil or math.abs(neighbour - cell.y) > 0.6 then
				return nil
			end
			return square[string.format("%d,%d", cell.x + dx, cell.z + dz)] or 0
		end
		local west, north, northWest = level(-1, 0), level(0, -1), level(-1, -1)
		local size = 1
		if west and north and northWest then
			size = math.min(west, north, northWest) + 1
		end
		square[string.format("%d,%d", cell.x, cell.z)] = size
		worst = math.max(worst, size)
	end
	local ok = worst < 24
	table.insert(findings, {
		Check = "NoBreatherSquare",
		Status = if ok then "PASS" else "FAIL",
		Detail = string.format(
			"largest flat hazard-free square on the route is %d x %d studs (limit 24)",
			worst,
			worst
		),
	})
	if not ok then
		table.insert(warnings, "a 24x24 flat breather square exists outside the start/finish plazas")
	end
	return findings, warnings
end

-- 8.3: newly created deep penetrations. Source-internal compound intersections
-- are permitted by exact source child pair, so only parts from different PieceIds
-- are compared, and only their real oriented extents.
function CourseQA.auditGeometry(model: Model): ({ Finding }, { string })
	local findings: { Finding } = {}
	local errors: { string } = {}
	local parts: { BasePart } = {}
	local geometry = model:FindFirstChild("Geometry")
	for _, descendant in (geometry and geometry:GetDescendants() or {}) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = parts
	overlapParams.MaxParts = 64

	local deep = 0
	local worst = ""
	local scanned = 0
	for _, part in parts do
		scanned += 1
		if scanned % 50 == 0 then
			task.wait()
		end
		local pieceId = part:GetAttribute("PieceId")
		-- Shrinking by the .1-stud seam allowance turns "touching" into "not
		-- overlapping", so anything still reported is a real penetration.
		local probe = part.Size - Vector3.one * 0.2
		if probe.X <= 0 or probe.Y <= 0 or probe.Z <= 0 then
			continue
		end
		for _, other in workspace:GetPartBoundsInBox(part.CFrame, probe, overlapParams) do
			if other == part then
				continue
			end
			if other:GetAttribute("PieceId") == pieceId then
				continue
			end
			deep += 1
			if worst == "" then
				worst = string.format("%s vs %s", part.Name, other.Name)
			end
		end
	end
	-- HANDOFF 8.3 is explicit that "oriented bounding overlap alone is not a mesh
	-- intersection test": a sloped ramp's box necessarily overlaps the slab it
	-- socket-joins even when the collision meshes only touch. So this reports a
	-- count to inspect, and the mesh-level verdict stays NOT RUN for the visual
	-- seam pass rather than being asserted from box math.
	table.insert(findings, {
		Check = "CrossPieceBoundingOverlap",
		Status = "NOT RUN",
		Detail = string.format(
			"%d oriented-box overlaps between different PieceIds%s; a box test cannot decide mesh penetration (8.3), so the seams need the visual inspection pass",
			deep,
			if worst == "" then "" else " (e.g. " .. worst .. ")"
		),
	})
	return findings, errors
end

-- 8.1 structural contract: pads, checkpoints, finish, boundary ring.
local function auditStructure(model: Model, spec: any): ({ Finding }, { string }, { [string]: number })
	local findings: { Finding } = {}
	local errors: { string } = {}
	local counts: { [string]: number } = {}

	local function expect(check: string, ok: boolean, detail: string)
		table.insert(findings, { Check = check, Status = if ok then "PASS" else "FAIL", Detail = detail })
		if not ok then
			table.insert(errors, check .. ": " .. detail)
		end
	end

	local start = model:FindFirstChild("Start")
	local pads = start and start:FindFirstChild("Pads")
	local padCount = 0
	for _, pad in (pads and pads:GetChildren() or {}) do
		if pad:IsA("BasePart") then
			padCount += 1
		end
	end
	counts.StartPads = padCount
	expect("StartPads==30", padCount == 30, string.format("%d immediate Start/Pads BaseParts", padCount))

	local checkpoints = model:FindFirstChild("Checkpoints")
	local checkpointCount = #(checkpoints and checkpoints:GetChildren() or {})
	counts.Checkpoints = checkpointCount
	expect("Checkpoints>=1", checkpointCount >= 1, string.format("%d ordered checkpoints", checkpointCount))
	expect(
		"CheckpointCountAttributeExact",
		model:GetAttribute("CheckpointCount") == checkpointCount,
		string.format("attribute %s vs %d actual", tostring(model:GetAttribute("CheckpointCount")), checkpointCount)
	)
	for _, checkpoint in (checkpoints and checkpoints:GetChildren() or {}) do
		expect(
			"Checkpoint:" .. checkpoint.Name,
			checkpoint:FindFirstChild("Pad") ~= nil and checkpoint:FindFirstChild("Trigger") ~= nil,
			"needs both Pad and Trigger"
		)
	end

	local finish = model:FindFirstChild("Finish")
	local triggers, decks = 0, 0
	for _, child in (finish and finish:GetChildren() or {}) do
		if child.Name == "Trigger" then
			triggers += 1
		elseif child.Name == "Deck" then
			decks += 1
		end
	end
	expect("ExactlyOneFinish", triggers == 1 and decks == 1, string.format("%d triggers, %d decks", triggers, decks))

	local boundary = model:FindFirstChild("Boundary")
	local walls = 0
	local radiusOk = true
	local worstRadius = 0
	for _, wall in (boundary and boundary:GetChildren() or {}) do
		if wall:IsA("BasePart") then
			walls += 1
			local radius = Vector3.new(wall.Position.X, 0, wall.Position.Z).Magnitude
			worstRadius = math.max(worstRadius, math.abs(radius - 390))
			if math.abs(radius - 390) > 1 then
				radiusOk = false
			end
			if not wall.Anchored or not wall.CanCollide or wall.Transparency < 1 then
				radiusOk = false
			end
		end
	end
	counts.BoundaryWalls = walls
	expect(
		"Boundary24At390",
		walls == 24 and radiusOk,
		string.format("%d anchored colliding invisible walls, worst radius error %.2f", walls, worstRadius)
	)

	counts.BaseParts = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			counts.BaseParts += 1
		end
	end
	counts.Beats = #spec.Beats
	return findings, errors, counts
end

-- Checks that cannot be measured without a live, driven playtest. They are listed
-- so the report never reads as an implied pass (HANDOFF section 8 preamble).
local NOT_RUN = {
	"8.2.6 time-expanded dynamic-state graph (periodic sampling every .1s across one common cycle)",
	"8.4 lane cross-section hazard coverage and blocked-fraction >= .4 per pendulum/hammer crossing",
	"8.4 measured shove travel from five real-player contacts per hazard and direction",
	"8.4 bumper chicane centreline/edge/slalom avoidance probes",
	"8.4 line-of-sight readability (>= 15 studs of approach) corroborated by screenshots",
	"8.4 cross-course auditVariety over all six staged specs",
	"8.5 scripted expert/mid policy route trials and the interactive keyboard run",
	"8.5 thirty-rider start load test and the Studio local multi-client session",
	"8.6 fixed-camera captures and the bad-map-refs comparison",
}

function CourseQA.check(model: Model, spec: any, calibration: Calibration?, context: { [string]: any }?): Report
	local cal = calibration or CourseQA.DefaultCalibration
	local ctx = context or {}
	local errors: { string } = {}
	local warnings: { string } = {}
	local findings: { Finding } = {}

	local function absorb(newFindings: { Finding }, newErrors: { string }?)
		for _, finding in newFindings do
			table.insert(findings, finding)
		end
		for _, message in newErrors or {} do
			table.insert(errors, message)
		end
	end

	local structureFindings, structureErrors, counts = auditStructure(model, spec)
	absorb(structureFindings, structureErrors)

	local cells = CourseQA.sampleSurfaces(model, cal)
	counts.SurfaceCells = #cells
	local graph = CourseQA.buildGraph(cells, cal)
	local nodeCount = 0
	for _ in graph.Nodes do
		nodeCount += 1
	end
	counts.GraphNodes = nodeCount
	counts.GraphEdges = #graph.Edges

	absorb(CourseQA.checkCutSets(model, graph))
	absorb(CourseQA.auditGaps(spec, ctx.Route or {}, cal))
	absorb(CourseQA.auditGeometry(model))

	local coverageFindings, coverageWarnings = CourseQA.auditCoverage(model, cells)
	absorb(coverageFindings)
	for _, message in coverageWarnings do
		table.insert(warnings, message)
	end

	local varietyFindings, varietyErrors, varietyWarnings, encounters = CourseQA.auditVariety(spec)
	absorb(varietyFindings, varietyErrors)
	for _, message in varietyWarnings do
		table.insert(warnings, message)
	end
	counts.Encounters = #encounters

	-- The cross-course rules run as soon as more than one spec exists, and they
	-- stop being a NOT RUN item once every course in the set has been built.
	local allSpecs = ctx.AllSpecs
	local crossCourseRan = false
	if typeof(allSpecs) == "table" then
		local specCount = 0
		for _ in allSpecs do
			specCount += 1
		end
		counts.CrossCourseSpecs = specCount
		if specCount >= 2 then
			absorb(CourseQA.auditCrossCourse(allSpecs))
			crossCourseRan = specCount >= 6
		end
	end

	local notRun: { string } = {}
	for _, item in NOT_RUN do
		if crossCourseRan and string.find(item, "cross-course", 1, true) then
			continue
		end
		table.insert(notRun, item)
		table.insert(
			findings,
			{ Check = item, Status = "NOT RUN", Detail = "requires a live driven playtest or the full course set" }
		)
	end

	return {
		CourseId = spec.Id,
		SpecHash = tostring(ctx.SpecHash or model:GetAttribute("SpecHash")),
		SourceHash = tostring(ctx.SourceHash or ""),
		PlaceId = game.PlaceId,
		Calibration = cal,
		SampleResolution = { Coarse = cal.SampleStep, Refined = cal.RefineStep },
		TestTime = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		-- Never "PASS by absence of data": unresolved NOT RUN items keep the whole
		-- report at BLOCKED even when every executed check passed.
		Status = if #errors > 0 then "FAIL" else "BLOCKED",
		Errors = errors,
		Warnings = warnings,
		NotRun = notRun,
		Counts = counts,
		Findings = findings,
		Encounters = encounters,
	}
end

return CourseQA
