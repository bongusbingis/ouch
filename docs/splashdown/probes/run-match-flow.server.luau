-- HANDOFF.md section 12.3's three-course match flow, driven through the EXISTING
-- admin seams and nothing else: MatchService.restartForAdmin (what
-- places/arena/server/Cmdr/Commands/sb-match-restartServer.luau calls) plus
-- SplashdownService.stateForAdmin / .setNextCourseForAdmin / .advanceForAdmin.
-- No new flow code, no reaching into SplashdownService's internals.
--
-- 12.3 forbids advancing a RACING phase to falsify a completed run, so this
-- probe never claims a finish. It advances Intro and Countdown into Racing, lets
-- the racing phase close through the seam's own DNF close, and advances the
-- RoundOver phase to the next round. Every return value is read and recorded,
-- and the trace says which phase each advance acted on.
--
-- Round 1's course is whatever CourseSequence.draw picked, because
-- setNextCourseForAdmin writes sequence[roundIndex + 1] and roundIndex is
-- already 1 by the time a Studio session's match reaches Intro -- the Idle
-- window after restartForAdmin is not reliably observable. Rounds 2 and 3 ARE
-- chosen through the seam, from courses round 1 did not use, with SummitSplash
-- preferred so the newly registered course actually races.
--
-- Install as an ordinary temporary Script under ServerScriptService, press Play,
-- read ServerStorage.SplashdownMatchFlow, then stop Play and delete the Script.
assert(game:GetService("RunService"):IsStudio(), "Studio only")

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local MatchService = require(Modules:WaitForChild("MatchService"))
local SplashdownService = require(Modules:WaitForChild("Splashdown"):WaitForChild("SplashdownService"))
local SplashdownConfig = require(ReplicatedStorage:WaitForChild("Config").Gameplay.Splashdown)

local PREFERRED = { "SummitSplash", "DoorDash", "PistonPeak", "TumbleTunnels", "TiptoeTrials", "WhirlpoolWaltz" }

local result = Instance.new("StringValue")
result.Name = "SplashdownMatchFlow"
result.Value = "running"
result.Parent = ServerStorage

local trace: { string } = {}
local function log(line: string)
	table.insert(trace, line)
	print("[match-flow] " .. line)
end

-- Waits for a phase in the given set, or gives up. Never advances on its own.
local function waitForPhase(wanted: { [string]: boolean }, seconds: number): string?
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		local state = SplashdownService.stateForAdmin()
		if state.active and state.phase and wanted[state.phase] then
			return state.phase
		end
		task.wait(0.1)
	end
	return nil
end

-- restartForAdmin returns as soon as the mode switch is requested; the venue
-- swap that makes SplashdownService active runs after it, and every admin seam
-- answers venue_not_splashdown until then.
local function waitForActive(seconds: number): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if SplashdownService.stateForAdmin().active then
			return true
		end
		task.wait(0.1)
	end
	return false
end

local function liveCourseModel(): Model
	local stood = workspace.Assets.Arena:FindFirstChild(SplashdownConfig.ActiveCourseName)
	assert(stood and stood:IsA("Model"), "no live course model in the bowl")
	return stood :: Model
end

local ok, answer = xpcall(function()
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	log("player " .. player.Name)

	local restarted, reason = MatchService.restartForAdmin("Splashdown")
	assert(restarted, "restartForAdmin failed: " .. tostring(reason))
	log("restartForAdmin ok; mode " .. tostring(MatchService.stateForAdmin().modeId))
	assert(waitForActive(90), "the Splashdown venue never became active after restartForAdmin")
	log("venue active; phase " .. tostring(SplashdownService.stateForAdmin().phase))

	local used: { [string]: boolean } = {}
	local rounds = {}

	for index = 1, SplashdownConfig.RoundCount do
		local entered = waitForPhase({ Intro = true, Countdown = true, Racing = true }, 90)
		assert(entered, `round {index} never reached a startable phase`)
		while SplashdownService.stateForAdmin().phase ~= "Racing" do
			local phase = SplashdownService.stateForAdmin().phase
			local advanced, advanceReason = SplashdownService.advanceForAdmin()
			assert(advanced, `advanceForAdmin from {tostring(phase)} failed: {tostring(advanceReason)}`)
			log(`round {index}: advanced {tostring(phase)} -> {tostring(SplashdownService.stateForAdmin().phase)}`)
			task.wait(0.1)
		end

		local racing = SplashdownService.stateForAdmin()
		local courseId = racing.courseId
		assert(courseId ~= nil, `round {index} is racing with no course id`)
		assert(SplashdownConfig.Courses[courseId] ~= nil, `round {index} stood unregistered course {courseId}`)
		assert(not used[courseId], `round {index} repeated {courseId}`)
		used[courseId] = true

		local stood = liveCourseModel()
		local parts = 0
		for _, descendant in stood:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
			end
		end
		local template = ReplicatedStorage.Assets.Maps.Splashdown:FindFirstChild(courseId)
		assert(template, `round {index} has no template for {courseId}`)
		table.insert(rounds, {
			index = index,
			courseId = courseId,
			chosen = index > 1,
			roundIndex = racing.roundIndex,
			racers = racing.racers,
			liveBaseParts = parts,
			specHash = template:GetAttribute("SpecHash"),
			checkpoints = #stood.Checkpoints:GetChildren(),
			declaredCheckpoints = stood:GetAttribute("CheckpointCount"),
			sequence = racing.sequence,
		})
		log(
			`round {index}: RACING on {courseId} ({parts} live BaseParts, hash {tostring(
				template:GetAttribute("SpecHash")
			)}, roundIndex {tostring(racing.roundIndex)})`
		)

		-- The racing phase closes through the seam's own close. No finish is
		-- credited to anyone and none is claimed: this is a DNF close.
		local closed, closeReason = SplashdownService.advanceForAdmin()
		assert(closed, `closing round {index} failed: {tostring(closeReason)}`)
		log(`round {index}: closed racing (DNF close; no completed run claimed)`)

		local over = waitForPhase({ RoundOver = true, Intro = true, Countdown = true, Idle = true }, 60)
		log(`round {index}: phase after close is {tostring(over)}`)

		if index < SplashdownConfig.RoundCount then
			local pick = nil
			for _, candidate in PREFERRED do
				if not used[candidate] then
					pick = candidate
					break
				end
			end
			assert(pick, "no unused course left to select")
			local set, setReason = SplashdownService.setNextCourseForAdmin(pick)
			assert(set, `setNextCourseForAdmin({pick}) failed: {tostring(setReason)}`)
			log(`round {index + 1}: setNextCourseForAdmin({pick}) ok in phase {tostring(over)}`)

			if over == "RoundOver" then
				local moved, moveReason = SplashdownService.advanceForAdmin()
				assert(moved, `leaving RoundOver on round {index} failed: {tostring(moveReason)}`)
				log(`round {index}: left RoundOver`)
			end
			task.wait(1)
		end
	end

	-- A retired id must be refused by the same seam.
	local retired, retiredReason = SplashdownService.setNextCourseForAdmin("CrossCurrent")
	log(`retired CrossCurrent: accepted={tostring(retired)} reason={tostring(retiredReason)}`)
	local retiredTemplates = {}
	for _, id in { "WhirlPool", "DiscJockey", "KnockKnock", "BumperBay", "TiltTrip", "CrossCurrent", "Downpour" } do
		if ReplicatedStorage.Assets.Maps.Splashdown:FindFirstChild(id) then
			table.insert(retiredTemplates, id)
		end
	end

	local templates = {}
	for _, child in ReplicatedStorage.Assets.Maps.Splashdown:GetChildren() do
		table.insert(templates, `{child.Name}:{tostring(child:GetAttribute("SpecHash"))}`)
	end
	table.sort(templates)

	return {
		courseOrder = SplashdownConfig.CourseOrder,
		rounds = rounds,
		retiredRefused = not retired,
		retiredReason = retiredReason,
		retiredTemplatesStillPresent = retiredTemplates,
		templates = templates,
		trace = trace,
	}
end, debug.traceback)

result.Value = HttpService:JSONEncode({ ok = ok, result = answer })
print("[match-flow] done ok=" .. tostring(ok))
