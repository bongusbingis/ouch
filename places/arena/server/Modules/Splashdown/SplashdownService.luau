-- Description: Owns the Splashdown race inside a match: draws the course sequence, keeps the current course standing in the bowl, runs each round's intro, countdown, race and results, holds racers on their pads, tracks checkpoints, splashes and finishes from the replicated roots, scores placement points through the match service seams, and publishes the race snapshot every client renders.

--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Splashdown = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local MapFeatures = require(Config:WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")
local Network = require(Shared:WaitForChild("Network"))
local PlayerIds = require(Game:WaitForChild("Adapters"):WaitForChild("PlayerIds"))
local MovementGuard = require(Game:WaitForChild("Adapters"):WaitForChild("MovementGuard"))
local Race = Game:WaitForChild("Splashdown")
local RaceRound = require(Race:WaitForChild("RaceRound"))
local RacePoints = require(Race:WaitForChild("RacePoints"))
local CourseSequence = require(Race:WaitForChild("CourseSequence"))
local DoorPlan = require(Race:WaitForChild("DoorPlan"))
local SplashdownState = require(Race:WaitForChild("SplashdownState"))

local ArenaService = require(script.Parent.Parent.ArenaService)
local ArenaSessionService = require(script.Parent.Parent.ArenaSessionService)
local MatchService = require(script.Parent.Parent.MatchService)
local VenueService = require(script.Parent.Parent.VenueService)
local Doors = require(script.Parent.Parent.MapFeatures.Doors)
local SplashdownCourses = require(script.Parent.SplashdownCourses)

local SplashdownService = {}

local MODE_ID = "Splashdown"
local Phases = SplashdownState.Phases
local Attributes = Splashdown.Attributes

type Hold = { character: Model, root: BasePart }
type Pending = { generation: number }

local active = false
local started = false
local live: SplashdownCourses.LiveCourse? = nil
local sequence: { string } = {}
local roundIndex = 0
local round: RaceRound.Round? = nil
local rounds: { RacePoints.RoundScore } = {}
local participants: { [string]: boolean } = {}
local splashTotals: { [string]: number } = {}
local standings: { RacePoints.Standing } = {}
local lastRound: { courseName: string, placements: { RacePoints.Placement }, dnf: { string } }? = nil
local phase: string = Phases.Idle
local phaseEndsAt = 0
local phaseGeneration = 0
local raceStartedAt = 0
local lavaRiseStartsAt = 0
local RisingLiquid = require(ReplicatedStorage.Shared.Game.MapFeatures.RisingLiquid)
local holds: { [Model]: Hold } = {}
local pendingRespawns: { [Player]: Pending } = {}
local respawnGeneration = 0
local snapshotValue: StringValue? = nil
local revision = 0
local random = Random.new()
local adminNextCourse: string? = nil
local heartbeat: RBXScriptConnection? = nil

local function playerId(player: Player): string
	return PlayerIds.toId(player)
end

local function chooseIndex(count: number): number
	return random:NextInteger(1, count)
end

local function ensureSnapshotValue(): StringValue
	if snapshotValue then
		return snapshotValue
	end
	local folder = Instance.new("Folder")
	folder.Name = Splashdown.StateFolderName
	local created = Instance.new("StringValue")
	created.Name = Splashdown.SnapshotValueName
	created.Parent = folder
	folder.Parent = ReplicatedStorage
	snapshotValue = created
	return created
end

local function currentPlacements(): { RacePoints.Placement }
	local current = round
	if current == nil then
		return {}
	end
	local finishers = {}
	for id, racer in current.racers do
		if racer.finishTime ~= nil then
			table.insert(finishers, { playerId = id, time = racer.finishTime })
		end
	end
	return RacePoints.placements(finishers, Splashdown.PointsForFirst)
end

local function publish()
	revision += 1
	local snapshot = SplashdownState.idle()
	snapshot.revision = revision
	snapshot.roundIndex = roundIndex
	snapshot.roundCount = Splashdown.RoundCount
	snapshot.courseId = if live then live.id else ""
	snapshot.courseName = if live then live.displayName else ""
	snapshot.checkpointCount = if live then #live.checkpoints else 0
	snapshot.phase = phase
	snapshot.phaseEndsAt = phaseEndsAt
	snapshot.raceStartedAt = raceStartedAt
	snapshot.closesAt = if round and round.closesAt then round.closesAt else 0
	snapshot.sequence = table.clone(sequence)
	snapshot.placements = currentPlacements()
	local rows = {}
	for _, standing in standings do
		table.insert(rows, { playerId = standing.playerId, points = standing.points, time = standing.time })
	end
	snapshot.standings = rows
	snapshot.lastRound = lastRound
	ensureSnapshotValue().Value = HttpService:JSONEncode(snapshot)
end

local function fire(payload: { [string]: any })
	Network.fire("SplashdownEvent", nil, payload)
end

local function rootOf(character: Model?): BasePart?
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function placeCharacter(character: Model, root: BasePart, target: CFrame)
	character:PivotTo(target * root.CFrame:Inverse() * character:GetPivot())
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	MovementGuard.reset(root)
end

local function standingTarget(marker: BasePart): CFrame
	return CFrame.new(marker.Position + Vector3.new(0, MapFeatures.Spawns.RootOffsetStuds, 0)) * marker.CFrame.Rotation
end

local function hold(character: Model, root: BasePart)
	root.Anchored = true
	holds[character] = { character = character, root = root }
end

local function release(character: Model)
	local held = holds[character]
	if held == nil then
		return
	end
	holds[character] = nil
	if held.root.Parent ~= nil then
		held.root.Anchored = false
		MovementGuard.reset(held.root)
	end
end

local function releaseAll()
	for character in holds do
		release(character)
	end
end

local function racingPlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if ArenaSessionService.isRoundEligible(player) then
			table.insert(result, player)
		end
	end
	table.sort(result, function(a, b)
		return a.UserId < b.UserId
	end)
	return result
end

local function padFor(player: Player): CFrame
	local course = assert(live, "[SplashdownService] pads need a standing course")
	local ordered = racingPlayers()
	local index = table.find(ordered, player) or (#ordered + 1)
	local pad = course.pads[(index - 1) % #course.pads + 1]
	return standingTarget(pad)
end

local function lavaTop(course: SplashdownCourses.LiveCourse): number?
	local lava = course.lava
	if lava == nil then
		return nil
	end
	return lava.Position.Y + lava.Size.Y / 2
end

-- Where a racer comes back: their checkpoint pad, or the next pad still above
-- rising lava, or the finish deck once they have finished or nothing is dry.
local function respawnTarget(player: Player): CFrame
	local course = assert(live, "[SplashdownService] respawn needs a standing course")
	local current = round
	local id = playerId(player)
	if current and RaceRound.hasFinished(current, id) then
		return standingTarget(course.finishDeck)
	end
	local index = if current then RaceRound.respawnIndex(current, id) else 0
	local surface = lavaTop(course)
	for candidate = index, #course.checkpoints do
		local marker = if candidate == 0 then nil else course.checkpoints[candidate].pad
		local position = if marker then marker.Position else course.pads[1].Position
		if surface == nil or position.Y > surface + 3 then
			return if marker then standingTarget(marker) else padFor(player)
		end
	end
	return standingTarget(course.finishDeck)
end

local function setRacerAttributes(player: Player, id: string)
	local current = round
	local racer = if current then current.racers[id] else nil
	player:SetAttribute(Attributes.Checkpoint, if racer then racer.checkpoint else 0)
	player:SetAttribute(Attributes.FinishTime, if racer then racer.finishTime else nil)
	player:SetAttribute(Attributes.Splashes, splashTotals[id] or 0)
end

local function setPhase(nextPhase: string, seconds: number?)
	phaseGeneration += 1
	phase = nextPhase
	phaseEndsAt = if seconds then Workspace:GetServerTimeNow() + seconds else 0
	publish()
	return phaseGeneration
end

local function after(seconds: number, generation: number, callback: () -> ())
	task.delay(seconds, function()
		if generation == phaseGeneration and active then
			callback()
		end
	end)
end

local function updateStats()
	local current = round
	for _, player in Players:GetPlayers() do
		local id = playerId(player)
		if not participants[id] then
			continue
		end
		local standing = nil
		for _, entry in standings do
			if entry.playerId == id then
				standing = entry
				break
			end
		end
		local best = if standing and standing.bestPlacement then standing.bestPlacement else 0
		local time = if standing then standing.time else 0
		MatchService.setContestantStats(player, {
			BestFinish = best,
			TotalTime = math.floor(time * 10 + 0.5) / 10,
			Splashdowns = splashTotals[id] or 0,
		})
		if current then
			setRacerAttributes(player, id)
		end
	end
end

local function standCourse(courseId: string)
	local arena = ArenaService.get()
	local previous = live
	if previous then
		Doors.reset()
		live = nil
		SplashdownCourses.destroy(previous)
	end
	live = SplashdownCourses.instantiate(courseId, arena.root, arena.origin.CFrame)
end

local function resetLava()
	local course = live
	if course and course.lava and course.lavaBase then
		course.lava.CFrame = course.lavaBase
	end
end

local function stepLava(now: number)
	local course = live
	if course == nil or course.lava == nil or course.lavaBase == nil or course.lavaRise == nil then
		return
	end
	local rise = course.lavaRise
	local target = course.lavaBase + Vector3.new(0, RisingLiquid.heightAt(now - lavaRiseStartsAt, rise), 0)
	if (course.lava.CFrame.Position - target.Position).Magnitude > 1e-3 then
		course.lava.CFrame = target
	end
end

local function planDoors()
	local course = live
	local definition = if course then Splashdown.Courses[course.id] else nil
	local doors = if definition then definition.Doors else nil
	if course == nil or doors == nil then
		Doors.reset()
		return
	end
	local rows: DoorPlan.Rows = {}
	local byKey: { [string]: BasePart } = {}
	for rowIndex, row in course.doorRows do
		local keys = {}
		for doorIndex, door in row do
			local key = `{rowIndex}:{doorIndex}`
			byKey[key] = door
			table.insert(keys, key)
		end
		table.insert(rows, keys)
	end
	local chosen = DoorPlan.choose(rows, doors.BreakablePerRow, chooseIndex)
	local plan: { [BasePart]: boolean } = {}
	for key in chosen do
		plan[byKey[key]] = true
	end
	Doors.setPlan(plan)
end

local function drawSequence()
	sequence = CourseSequence.draw(Splashdown.CourseOrder, Splashdown.RoundCount, chooseIndex)
	if adminNextCourse then
		sequence[1] = adminNextCourse
		adminNextCourse = nil
	end
end

local function seatEveryone(withHold: boolean)
	for _, player in racingPlayers() do
		local character = player.Character
		local root = rootOf(character)
		if character and root then
			release(character)
			placeCharacter(character, root, padFor(player))
			if withHold then
				hold(character, root)
			end
		end
	end
end

local function splash(player: Player, root: BasePart)
	local current = round
	local id = playerId(player)
	local character = root.Parent :: Model
	if pendingRespawns[player] then
		return
	end
	local counted = if current then RaceRound.splash(current, id) else nil
	if counted then
		splashTotals[id] = (splashTotals[id] or 0) + 1
		player:SetAttribute(Attributes.Splashes, splashTotals[id])
	end
	fire({
		kind = "Splash",
		playerId = id,
		position = root.Position,
		velocity = root.AssemblyLinearVelocity,
		counted = counted ~= nil,
	})
	respawnGeneration += 1
	local generation = respawnGeneration
	pendingRespawns[player] = { generation = generation }
	task.delay(Splashdown.RespawnDelaySeconds, function()
		local pending = pendingRespawns[player]
		if pending == nil or pending.generation ~= generation then
			return
		end
		pendingRespawns[player] = nil
		if player.Parent ~= Players or player.Character ~= character or root.Parent == nil then
			release(character)
			return
		end
		release(character)
		if live then
			placeCharacter(character, root, respawnTarget(player))
		end
		if phase == Phases.Intro or phase == Phases.Countdown or phase == Phases.RoundOver then
			hold(character, root)
		end
	end)
end

local function inHazard(course: SplashdownCourses.LiveCourse, position: Vector3): boolean
	if position.Y < course.model:GetPivot().Position.Y - Splashdown.VoidDepthStuds then
		return true
	end
	for _, hazard in course.hazards do
		local offset = hazard.CFrame:PointToObjectSpace(position)
		local size = hazard.Size
		if
			math.abs(offset.X) <= size.X / 2
			and math.abs(offset.Z) <= size.Z / 2
			and offset.Y <= size.Y / 2 + Splashdown.HazardVerticalPadding
			and offset.Y >= -Splashdown.VoidDepthStuds
		then
			return true
		end
	end
	return false
end

local function inTrigger(trigger: BasePart, position: Vector3): boolean
	local offset = trigger.CFrame:PointToObjectSpace(position)
	local size = trigger.Size
	return math.abs(offset.X) <= size.X / 2
		and math.abs(offset.Z) <= size.Z / 2
		and math.abs(offset.Y) <= size.Y / 2 + Splashdown.TriggerVerticalPadding
end

local closeRound: () -> ()

local function finishRacer(player: Player, id: string, now: number)
	local current = assert(round, "[SplashdownService] finishing needs a round")
	if not RaceRound.finish(current, id, now) then
		return
	end
	local placements = currentPlacements()
	local placement = 0
	local time = 0
	for _, entry in placements do
		if entry.playerId == id then
			placement = entry.placement
			time = entry.time
			break
		end
	end
	setRacerAttributes(player, id)
	fire({ kind = "Finish", playerId = id, placement = placement, time = time })
	publish()
end

local function stepRacing(now: number)
	local course = live
	local current = round
	if course == nil or current == nil or current.phase ~= "Racing" then
		return
	end
	stepLava(now)
	for _, player in Players:GetPlayers() do
		local id = playerId(player)
		local racer = current.racers[id]
		local root = rootOf(player.Character)
		if racer == nil or root == nil or pendingRespawns[player] or holds[player.Character :: Model] then
			continue
		end
		local position = root.Position
		if inHazard(course, position) then
			splash(player, root)
			continue
		end
		if racer.finishTime ~= nil then
			continue
		end
		local nextCheckpoint = course.checkpoints[racer.checkpoint + 1]
		if nextCheckpoint and inTrigger(nextCheckpoint.trigger, position) then
			if RaceRound.reachCheckpoint(current, id, nextCheckpoint.index) then
				player:SetAttribute(Attributes.Checkpoint, nextCheckpoint.index)
				fire({ kind = "Checkpoint", playerId = id, index = nextCheckpoint.index })
			end
		elseif racer.checkpoint >= #course.checkpoints and inTrigger(course.finishTrigger, position) then
			finishRacer(player, id, now)
		end
	end
	if RaceRound.shouldClose(current, now) then
		closeRound()
	end
end

local nextRound: () -> ()

local function finishRounds()
	local winner = RacePoints.winner(standings)
	updateStats()
	if not MatchService.finishMatch(winner, "RoundsComplete") then
		warn("[SplashdownService] the match could not be finished after the last round")
	end
end

closeRound = function()
	local current = round
	local course = live
	if current == nil or course == nil or current.phase ~= "Racing" then
		return
	end
	local outcome = RaceRound.close(current)
	local placements = RacePoints.placements(outcome.finishers, Splashdown.PointsForFirst)
	table.insert(rounds, { courseId = course.id, capSeconds = current.capSeconds, placements = placements })
	local ids = {}
	for id in participants do
		table.insert(ids, id)
	end
	standings = RacePoints.standings(rounds, ids)
	lastRound = { courseName = course.displayName, placements = placements, dnf = outcome.dnf }
	local pointsById: { [string]: number } = {}
	for _, placement in placements do
		pointsById[placement.playerId] = placement.points
	end
	for _, player in Players:GetPlayers() do
		local id = playerId(player)
		if participants[id] then
			player:SetAttribute(Attributes.RoundPoints, pointsById[id] or 0)
			for _, standing in standings do
				if standing.playerId == id then
					MatchService.setPlayerScore(player, standing.points)
					break
				end
			end
		end
	end
	updateStats()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = rootOf(character)
		if character and root and not pendingRespawns[player] then
			hold(character, root)
		end
	end
	fire({ kind = "RoundOver", roundIndex = roundIndex })
	local generation = setPhase(Phases.RoundOver, Splashdown.RoundResultsSeconds)
	after(Splashdown.RoundResultsSeconds, generation, function()
		if roundIndex >= Splashdown.RoundCount then
			finishRounds()
		else
			nextRound()
		end
	end)
end

local function beginRacing()
	local current = assert(round, "[SplashdownService] racing needs a round")
	local now = Workspace:GetServerTimeNow()
	RaceRound.start(current, now)
	raceStartedAt = now
	local course = live
	if course and course.lavaRise then
		lavaRiseStartsAt = now + course.lavaRise.delaySeconds
	end
	releaseAll()
	setPhase(Phases.Racing)
	fire({ kind = "Go", roundIndex = roundIndex })
end

nextRound = function()
	roundIndex += 1
	local courseId = sequence[roundIndex]
	if courseId == nil then
		finishRounds()
		return
	end
	if live == nil or live.id ~= courseId then
		standCourse(courseId)
	end
	local course = assert(live, "[SplashdownService] a round needs a standing course")
	local definition = Splashdown.Courses[courseId]
	round = RaceRound.new(courseId, #course.checkpoints, definition.CapSeconds, definition.CloseWindowSeconds)
	for _, player in racingPlayers() do
		local id = playerId(player)
		RaceRound.addRacer(round :: RaceRound.Round, id)
		participants[id] = true
		setRacerAttributes(player, id)
		player:SetAttribute(Attributes.RoundPoints, nil)
	end
	resetLava()
	planDoors()
	table.clear(pendingRespawns)
	seatEveryone(true)
	local generation = setPhase(Phases.Intro, Splashdown.IntroSeconds)
	after(Splashdown.IntroSeconds, generation, function()
		local countdown = setPhase(Phases.Countdown, Splashdown.CountdownSeconds)
		after(Splashdown.CountdownSeconds, countdown, beginRacing)
	end)
end

local function beginRounds()
	roundIndex = 0
	round = nil
	table.clear(rounds)
	table.clear(participants)
	table.clear(splashTotals)
	standings = {}
	lastRound = nil
	nextRound()
end

local function stopRounds()
	phaseGeneration += 1
	round = nil
	table.clear(pendingRespawns)
	releaseAll()
	Doors.reset()
	resetLava()
	phase = Phases.Idle
	phaseEndsAt = 0
	raceStartedAt = 0
	publish()
end

local function spawnHandler(character: Model, player: Player?, reason: ArenaService.SpawnReason): boolean
	local course = live
	local root = rootOf(character)
	if course == nil or root == nil then
		return false
	end
	if player == nil then
		placeCharacter(character, root, standingTarget(course.pads[1]))
		return true
	end
	release(character)
	local current = round
	if current and current.phase == "Racing" then
		local id = playerId(player)
		if current.racers[id] == nil then
			RaceRound.addRacer(current, id)
			participants[id] = true
			setRacerAttributes(player, id)
		end
		placeCharacter(character, root, respawnTarget(player))
		return true
	end
	placeCharacter(character, root, padFor(player))
	if phase == Phases.Intro or phase == Phases.Countdown or phase == Phases.RoundOver then
		hold(character, root)
	end
	return reason ~= nil
end

local function activate()
	if active then
		return
	end
	active = true
	SplashdownCourses.start()
	drawSequence()
	standCourse(sequence[1])
	seatEveryone(false)
	publish()
	if heartbeat == nil then
		heartbeat = RunService.Heartbeat:Connect(function()
			if phase == Phases.Racing then
				stepRacing(Workspace:GetServerTimeNow())
			end
		end)
	end
end

function SplashdownService.start()
	if started then
		return
	end
	started = true
	ensureSnapshotValue()
	publish()
	ArenaService.registerCourseHandler(spawnHandler)
	VenueService.onChanged(function(venue)
		if venue == "Splashdown" then
			activate()
		end
	end)
	MatchService.onEvent(function(event)
		if not active then
			return
		end
		if event.kind == "MatchStarted" and MatchService.activeModeId() == MODE_ID then
			beginRounds()
		elseif event.kind == "MatchEnded" then
			stopRounds()
		elseif event.kind == "MatchReset" then
			roundIndex = 0
			drawSequence()
			standCourse(sequence[1])
			seatEveryone(false)
			publish()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local current = round
		if current then
			RaceRound.removeRacer(current, playerId(player))
		end
		pendingRespawns[player] = nil
		local character = player.Character
		if character then
			release(character)
		end
	end)
end

function SplashdownService.isActive(): boolean
	return active
end

function SplashdownService.stateForAdmin(): { [string]: any }
	local current = round
	local total, finished = if current then RaceRound.counts(current) else 0, 0
	return {
		active = active,
		phase = phase,
		roundIndex = roundIndex,
		roundCount = Splashdown.RoundCount,
		courseId = if live then live.id else nil,
		sequence = table.clone(sequence),
		racers = total,
		finished = finished,
		closesAt = if current then current.closesAt else nil,
	}
end

-- Ends whatever the round is doing: an intro or countdown jumps to the race,
-- a race closes now, results move on.
function SplashdownService.advanceForAdmin(): (boolean, string?)
	if not active then
		return false, "venue_not_splashdown"
	end
	if phase == Phases.Intro or phase == Phases.Countdown then
		phaseGeneration += 1
		beginRacing()
		return true, nil
	elseif phase == Phases.Racing then
		closeRound()
		return true, nil
	elseif phase == Phases.RoundOver then
		phaseGeneration += 1
		if roundIndex >= Splashdown.RoundCount then
			finishRounds()
		else
			nextRound()
		end
		return true, nil
	end
	return false, "no_round"
end

-- Names the course the next round stands; between matches it stands at once.
function SplashdownService.setNextCourseForAdmin(courseId: string): (boolean, string?)
	if not active then
		return false, "venue_not_splashdown"
	end
	if Splashdown.Courses[courseId] == nil then
		return false, "unknown_course"
	end
	if phase == Phases.Idle then
		sequence[1] = courseId
		standCourse(courseId)
		seatEveryone(false)
		publish()
		return true, nil
	end
	if roundIndex >= Splashdown.RoundCount then
		adminNextCourse = courseId
		return true, nil
	end
	sequence[roundIndex + 1] = courseId
	publish()
	return true, nil
end

return SplashdownService
