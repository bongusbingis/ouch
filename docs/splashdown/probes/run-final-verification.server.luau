-- The HANDOFF.md section 12.3 final TestEZ bootstrap, run in the connected arena
-- place AFTER the 12.1 replacement transaction and with every temporary probe,
-- fixture, preview and detached ball removed. Install as an ordinary temporary
-- Script under ServerScriptService (section 2.2's pattern), press Play, read
-- ServerStorage.SplashdownFinalResults, then stop Play and delete the Script.
--
-- 12.3 asks for one bootstrap carrying four things:
--   * the existing Server kit specs (25 expected),
--   * Assets/SplashdownCourses.spec, now 14 contract assertions over seven
--     courses because it iterates CourseOrder,
--   * Assets/SplashdownQA.spec over all seven ids, and
--   * the lifecycle/reset/clone tests and the malformed-course mutation
--     fixtures, which live in the set-wide describe at the end of that spec.
--
-- COURSE_IDS is the only line to edit between runs. Seven full course audits in
-- one Play session is several million graph edges per course and Studio kills a
-- script that long, so the courses are run in batches and the batch totals are
-- added up in the report. KIT_AND_CONTRACT is set true for exactly one batch so
-- the 25 kit assertions and the 14 contract assertions are counted once.
assert(game:GetService("RunService"):IsStudio(), "Studio only")

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local COURSE_IDS = { "BallBarrage", "WhirlpoolWaltz" }
local KIT_AND_CONTRACT = true

local result = Instance.new("StringValue")
result.Name = "SplashdownFinalResults"
result.Value = "running"
result.Parent = ServerStorage

local existing = ServerStorage:FindFirstChild("SplashdownQASelection")
local selection: StringValue
if existing and existing:IsA("StringValue") then
	selection = existing
else
	selection = Instance.new("StringValue")
	selection.Name = "SplashdownQASelection"
	selection.Parent = ServerStorage
end
selection.Value = table.concat(COURSE_IDS, ",")

local ok, answer = xpcall(function()
	local folder = Instance.new("Folder")
	folder.Name = "SplashdownFinalVerification"
	folder.Parent = ServerStorage

	local specs: { string } = {}
	if KIT_AND_CONTRACT then
		for _, name in { "RotatingComposition.spec", "CarryMotion.spec", "HazardKits.spec" } do
			ServerStorage.Tests.Server:WaitForChild(name):Clone().Parent = folder
			table.insert(specs, "Server/" .. name)
		end
		ServerStorage.Tests.Assets:WaitForChild("SplashdownCourses.spec"):Clone().Parent = folder
		table.insert(specs, "Assets/SplashdownCourses.spec")
	end
	ServerStorage.Tests.Assets:WaitForChild("SplashdownQA.spec"):Clone().Parent = folder
	table.insert(specs, "Assets/SplashdownQA.spec")

	local TestEZ = require(ReplicatedStorage.Packages.testEZ) :: any
	local run = TestEZ.TestBootstrap:run({ folder }, TestEZ.Reporters.TextReporter)
	folder:Destroy()

	local errors = {}
	for _, message in run.errors do
		table.insert(errors, tostring(message))
	end
	return {
		courses = COURSE_IDS,
		kitAndContract = KIT_AND_CONTRACT,
		specs = specs,
		passed = run.successCount,
		failed = run.failureCount,
		skipped = run.skippedCount,
		errors = errors,
	}
end, debug.traceback)

result.Value = HttpService:JSONEncode({ ok = ok, result = answer })
print("[run-final-verification] ok=" .. tostring(ok) .. " " .. result.Value:sub(1, 400))
