-- Description: Open Cloud Luau Execution payload submitted by the deploy pipeline, running the in-place test suite and erroring on any failure so the cloud task lands in a failed state.

local ServerStorage = game:GetService("ServerStorage")

print("[cloud-tests] loading TestEZ runner")
local tests = ServerStorage:FindFirstChild("Tests")
assert(tests and tests:IsA("Folder"), "[cloud-tests] ServerStorage.Tests must be a Folder")
local runner = tests:FindFirstChild("Runner")
assert(runner and runner:IsA("ModuleScript"), "[cloud-tests] ServerStorage.Tests.Runner must be a ModuleScript")
local runSuite = require(runner)
local helpers = tests:WaitForChild("Helpers")
assert(helpers:IsA("Folder"), "[cloud-tests] ServerStorage.Tests.Helpers must be a Folder")
local gate = helpers:WaitForChild("CloudTestGate")
assert(gate:IsA("ModuleScript"), "[cloud-tests] ServerStorage.Tests.Helpers.CloudTestGate must be a ModuleScript")
local assertCloudTestSuccess = require(gate)
print("[cloud-tests] running suite")
local summary = runSuite()
print("[cloud-tests] suite returned")

print(string.format("cloud tests: %d passed, %d failed, %d skipped", summary.passed, summary.failed, summary.skipped))

assertCloudTestSuccess(summary.passed, summary.failed, summary.failureMessages)

return summary
