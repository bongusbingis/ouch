-- Install as a normal temporary Script under ServerScriptService and press Play
-- (HANDOFF.md section 10 step 6). It bootstraps the real TestEZ runner over
-- SplashdownQA.spec against an isolated clone of the staged course and writes
-- ServerStorage.SplashdownCourseQAResults as JSON. Delete it before committing.
assert(game:GetService("RunService"):IsStudio(), "Studio only")

local SS = game.ServerStorage
local RS = game.ReplicatedStorage
local HttpService = game:GetService("HttpService")

local selectedIds = { "BallBarrage" }
local sourceFolderName = "SplashdownStaging"

local selection = SS:FindFirstChild("SplashdownQASelection")
if not selection then
	selection = Instance.new("StringValue")
	selection.Name = "SplashdownQASelection"
	selection.Parent = SS
end
selection.Value = table.concat(selectedIds, ",")

local result = Instance.new("StringValue")
result.Name = "SplashdownCourseQAResults"
result.Value = "running"
result.Parent = SS

local folder = Instance.new("Folder")
folder.Name = "SplashdownIsolatedCourseQA"
folder.Parent = SS

local ok, answer = xpcall(function()
	local staging = SS:FindFirstChild(sourceFolderName)
	local staged = {}
	for _, id in selectedIds do
		local model = staging and staging:FindFirstChild(id)
		assert(model, `[run-course-qa] {sourceFolderName}.{id} is not staged`)
		table.insert(staged, id)
	end

	SS.Tests.Assets:WaitForChild("SplashdownQA.spec"):Clone().Parent = folder
	local TestEZ = require(RS.Packages.testEZ)
	local run = TestEZ.TestBootstrap:run({ folder }, TestEZ.Reporters.TextReporter)
	return {
		selected = staged,
		source = sourceFolderName,
		passed = run.successCount,
		failed = run.failureCount,
		skipped = run.skippedCount,
		errors = run.errors,
	}
end, debug.traceback)

folder:Destroy()
result.Value = HttpService:JSONEncode({ ok = ok, result = answer })
print("[run-course-qa] " .. result.Value)
