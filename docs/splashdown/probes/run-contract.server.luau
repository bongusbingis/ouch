-- Temporary Studio-only bootstrap. Remove this Script after the discovery run.
-- Uses the real TestEZ framework, not a replacement assertion harness.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Discovery is Studio-only")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local result = Instance.new("StringValue")
result.Name = "SplashdownDiscoveryContractResults"
result.Value = "running"
result.Parent = SS
local ok, summary = pcall(function()
	local TestEZ = require(RS.Packages.testEZ)
	local tests = Instance.new("Folder")
	tests.Name = "SplashdownDiscoveryContractTests"
	tests.Parent = SS
	SS.Tests.Assets["SplashdownCourses.spec"]:Clone().Parent = tests
	local function run()
		local r = TestEZ.TestBootstrap:run({ tests }, TestEZ.Reporters.TextReporter)
		return { passed = r.successCount, failed = r.failureCount, skipped = r.skippedCount, errors = r.errors }
	end
	local before = run()
	-- Only runtime copies. Preserve the Edit-mode source and empty template folder.
	local staged = {}
	for _, model in workspace.LegacyCourses:GetChildren() do
		if model:IsA("Model") and model:FindFirstChild("Start") then
			local copy = model:Clone()
			copy.Parent = RS.Assets.Maps.Splashdown
			table.insert(staged, copy)
		end
	end
	local copied = run()
	for _, copy in staged do
		copy:Destroy()
	end
	tests:Destroy()
	return { asOpened = before, withSevenLegacyCopies = copied }
end)
result.Value = game:GetService("HttpService")
	:JSONEncode({ ok = ok, result = if ok then summary else tostring(summary) })
