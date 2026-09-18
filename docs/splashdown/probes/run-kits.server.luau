assert(game:GetService("RunService"):IsStudio(), "Studio only")
local SS = game.ServerStorage
local RS = game.ReplicatedStorage
local result = Instance.new("StringValue")
result.Name = "SplashdownKitTestResults"
result.Value = "running"
result.Parent = SS
local folder = Instance.new("Folder")
folder.Name = "SplashdownIsolatedKitTests"
folder.Parent = SS
local ok, answer = xpcall(function()
	local names = { "RotatingComposition.spec", "CarryMotion.spec", "HazardKits.spec" }
	for _, name in names do
		SS.Tests.Server:WaitForChild(name):Clone().Parent = folder
	end
	local TestEZ = require(RS.Packages.testEZ)
	local r = TestEZ.TestBootstrap:run({ folder }, TestEZ.Reporters.TextReporter)
	return { passed = r.successCount, failed = r.failureCount, skipped = r.skippedCount, errors = r.errors }
end, debug.traceback)
folder:Destroy()
result.Value = game.HttpService:JSONEncode({ ok = ok, result = answer })
