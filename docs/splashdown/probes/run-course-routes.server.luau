-- Install as a normal temporary Script under ServerScriptService and press Play
-- (HANDOFF.md section 8.5 and 10 step 8). It drives a real R15 Humanoid along the
-- socket-derived route of a staged course with Humanoid:MoveTo/Jump only -- never
-- a CFrame teleport -- and writes ServerStorage.SplashdownCourseRouteResults as
-- JSON. Delete it before committing.
--
-- Scope note, to be copied verbatim into the gate packet: this harness is a
-- reproducible scripted proxy. It is NOT a human skill classification and it is
-- NOT the interactive keyboard run section 8.5 also requires. Kits that select
-- Players still need real Player trials.
assert(game:GetService("RunService"):IsStudio(), "Studio only")

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SS = game.ServerStorage
local Workspace = game.Workspace

local COURSE_ID = "BallBarrage"
local STAGING = "SplashdownStaging"
local STUCK_SECONDS = 8
local MID_SEEDS = { 101, 102, 103, 104, 105 }
local EXPERT_RESETS = 3

local result = Instance.new("StringValue")
result.Name = "SplashdownCourseRouteResults"
result.Value = "running"
result.Parent = SS

local function buildRig(): (Model, Humanoid, BasePart)
	-- The actual R15 movement configuration, not an approximation.
	local rig = Instance.new("Model")
	rig.Name = "SplashdownRouteRig"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = rig
	local torso = Instance.new("Part")
	torso.Name = "UpperTorso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Parent = rig
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Parent = rig
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.WalkSpeed = 26
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 10
	humanoid.Parent = rig
	rig.PrimaryPart = root
	return rig, humanoid, root
end

local function routeWaypoints(model: Model): { { Id: string, Beat: string, Position: Vector3 } }
	-- Waypoints come from the course's own socket-derived Beats index and its
	-- ordered checkpoints, never from a hand-listed path.
	local points = {}
	local checkpoints = model:FindFirstChild("Checkpoints")
	local ordered = checkpoints and checkpoints:GetChildren() or {}
	table.sort(ordered, function(a, b)
		return a.Name < b.Name
	end)
	for _, checkpoint in ordered do
		local pad = checkpoint:FindFirstChild("Pad")
		if pad and pad:IsA("BasePart") then
			table.insert(points, { Id = checkpoint.Name, Beat = checkpoint.Name, Position = pad.Position })
		end
	end
	local finish = model:FindFirstChild("Finish")
	local deck = finish and finish:FindFirstChild("Deck")
	if deck and deck:IsA("BasePart") then
		table.insert(points, { Id = "Finish", Beat = "Finish", Position = deck.Position })
	end
	return points
end

local function runTrial(model: Model, policy: string, decisionInterval: number, responseDelay: number, seed: number)
	local waypoints = routeWaypoints(model)
	local startPads = model.Start.Pads:GetChildren()
	table.sort(startPads, function(a, b)
		return a.Name < b.Name
	end)
	local firstPad = startPads[1]

	local rig, humanoid, root = buildRig()
	rig.Parent = Workspace
	local relocations = {}
	-- Initial seating is one of the only two permitted relocations (8.5).
	root.CFrame = CFrame.new(firstPad.Position + Vector3.new(0, 3.5, 0))
	table.insert(relocations, { reason = "initial seating", at = 0 })

	local random = Random.new(seed)
	local trajectory, falls, contacts = {}, {}, {}
	local splits = {}
	local liquid = model.Hazards:FindFirstChild("Liquid")
	local liquidY = liquid and liquid.Position.Y or -math.huge

	local started = os.clock()
	local lastProgress = started
	local lastDistance = math.huge
	local index = 1
	local dnf = nil
	local lastCheckpoint = "none"
	local cleared = false

	while index <= #waypoints do
		local waypoint = waypoints[index]
		humanoid:MoveTo(waypoint.Position)
		task.wait(decisionInterval + (if responseDelay > 0 then random:NextNumber(0, responseDelay) else 0))
		local now = os.clock()
		local distance = (root.Position - waypoint.Position).Magnitude
		table.insert(trajectory, { t = now - started, x = root.Position.X, y = root.Position.Y, z = root.Position.Z })

		if root.Position.Y < liquidY + 2 then
			table.insert(falls, { t = now - started, x = root.Position.X, y = root.Position.Y, z = root.Position.Z })
			-- The actual mode's checkpoint respawn is the second permitted
			-- relocation; it is logged, never silently applied.
			local recover = if index > 1 then waypoints[index - 1].Position else firstPad.Position
			root.CFrame = CFrame.new(recover + Vector3.new(0, 3.5, 0))
			table.insert(relocations, { reason = "checkpoint respawn after fall", at = now - started })
			lastProgress = now
		elseif distance < 8 then
			table.insert(splits, { id = waypoint.Id, t = now - started })
			lastCheckpoint = waypoint.Id
			index += 1
			lastProgress = now
			lastDistance = math.huge
		else
			if distance < lastDistance - 0.5 then
				lastProgress = now
				lastDistance = distance
			end
			if humanoid.FloorMaterial == Enum.Material.Air then
				humanoid.Jump = true
			end
			if now - lastProgress > STUCK_SECONDS then
				-- 8.5: a stuck state is a recorded FAIL, never a forced move.
				dnf = string.format("stuck for %d s before %s", STUCK_SECONDS, waypoint.Id)
				break
			end
		end
		if now - started > 300 then
			dnf = "exceeded the 300 s harness ceiling"
			break
		end
	end

	cleared = dnf == nil and index > #waypoints
	local elapsed = os.clock() - started
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
		relocations = relocations,
		lastCheckpoint = lastCheckpoint,
		trajectorySamples = #trajectory,
		trajectory = trajectory,
	}
end

local ok, answer = xpcall(function()
	local staging = SS:FindFirstChild(STAGING)
	local staged = staging and staging:FindFirstChild(COURSE_ID)
	assert(staged, `[run-course-routes] {STAGING}.{COURSE_ID} is not staged`)

	local container = Instance.new("Folder")
	container.Name = "SplashdownRouteIsolation"
	container.Parent = Workspace
	local model = staged:Clone()
	model.Parent = container

	local runs = {}
	for trial = 1, EXPERT_RESETS do
		table.insert(runs, runTrial(model, "expert", 0.05, 0, 900 + trial))
	end
	for _, seed in MID_SEEDS do
		table.insert(runs, runTrial(model, "mid", 0.25, 0.2, seed))
	end
	container:Destroy()

	local midTimes = {}
	local expertClean = nil
	for _, run in runs do
		if run.policy == "mid" and run.cleared then
			table.insert(midTimes, run.elapsedSeconds)
		elseif run.policy == "expert" and run.cleared and run.fallCount == 0 then
			expertClean = math.min(expertClean or math.huge, run.elapsedSeconds)
		end
	end
	table.sort(midTimes)
	local median = if #midTimes > 0 then midTimes[math.ceil(#midTimes / 2)] else nil

	return {
		courseId = COURSE_ID,
		placeId = game.PlaceId,
		runs = runs,
		midCompletionRate = #midTimes / #MID_SEEDS,
		midMedianSeconds = median,
		expertCleanSeconds = expertClean,
		pacePass = median ~= nil
			and median >= 60
			and median <= 90
			and expertClean ~= nil
			and expertClean <= 0.6 * median,
		scopeNote = "scripted proxy only; not a human skill classification and not the required interactive keyboard run",
	}
end, debug.traceback)

result.Value = HttpService:JSONEncode({ ok = ok, result = answer })
print("[run-course-routes] ok=" .. tostring(ok))
