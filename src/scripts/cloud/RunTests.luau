-- Name: RunTests.luau
-- Author: Jack C.
-- Description: Open Cloud Luau Execution payload submitted by the deploy pipeline, running the in-place test suite and erroring on any failure so the cloud task lands in a failed state.
-- Created: 2026-07-16

local ServerStorage = game:GetService("ServerStorage")

print("[cloud-tests] loading TestEZ runner")
local tests = ServerStorage:FindFirstChild("Tests")
assert(tests and tests:IsA("Folder"), "[cloud-tests] ServerStorage.Tests must be a Folder")
local runner = tests:FindFirstChild("Runner")
assert(runner and runner:IsA("ModuleScript"), "[cloud-tests] ServerStorage.Tests.Runner must be a ModuleScript")
local runSuite = require(runner)
print("[cloud-tests] running suite")
local summary = runSuite()
print("[cloud-tests] suite returned")

print(string.format("cloud tests: %d passed, %d failed, %d skipped", summary.passed, summary.failed, summary.skipped))

if summary.failed > 0 then
	error(string.format("cloud tests: %d failing spec(s); see logs above", summary.failed), 0)
end

return summary
