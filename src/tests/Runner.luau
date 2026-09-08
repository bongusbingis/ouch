-- Description: Bootstraps the in-place test suite, running every spec module under the tests folder and returning a plain summary table for the cloud task and the Studio command bar.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local packages = ReplicatedStorage:FindFirstChild("Packages")
assert(packages and packages:IsA("Folder"), "[Tests.Runner] ReplicatedStorage.Packages must be a Folder")
local testEZ = packages:FindFirstChild("testEZ")
assert(testEZ and testEZ:IsA("ModuleScript"), "[Tests.Runner] ReplicatedStorage.Packages.testEZ must be a ModuleScript")
local TestEZ = require(testEZ) :: any

export type Summary = {
	passed: number,
	failed: number,
	skipped: number,
	failureMessages: { string },
}

return function(): Summary
	local results = TestEZ.TestBootstrap:run({ script.Parent }, TestEZ.Reporters.TextReporter)

	local failureMessages = table.create(#results.errors)
	for _, message in ipairs(results.errors) do
		table.insert(failureMessages, tostring(message))
	end

	return {
		passed = results.successCount,
		failed = results.failureCount,
		skipped = results.skippedCount,
		failureMessages = failureMessages,
	}
end
