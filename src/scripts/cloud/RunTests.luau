-- Open Cloud Luau Execution payload. Submitted as the task script by
-- test-and-deploy.luau (never synced into the place): runs the cloud TestEZ
-- suite in ServerStorage.Tests and errors on any failure so the task lands in
-- the FAILED state. The summary is returned so it also appears in
-- task.output.results.

local ServerStorage = game:GetService("ServerStorage")

print("[cloud-tests] loading TestEZ runner")
local runSuite = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Runner"))
print("[cloud-tests] running suite")
local summary = runSuite()
print("[cloud-tests] suite returned")

print(string.format("cloud tests: %d passed, %d failed, %d skipped", summary.passed, summary.failed, summary.skipped))

if summary.failed > 0 then
	error(string.format("cloud tests: %d failing spec(s); see logs above", summary.failed), 0)
end

return summary
