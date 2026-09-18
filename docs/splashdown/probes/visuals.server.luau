-- Temporary Studio-only presentation probe. Normal Script permissions, not MCP elevation.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local RS = game.ReplicatedStorage
local player = game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")
task.wait(5)
local model = RS.SplashdownKitFixtures.BigBall:Clone()
model.Name = "SplashdownVisualProbe"
model:PivotTo(root.CFrame * CFrame.new(16, -18, -8))
model.Parent = workspace
local sphere
for _, part in model:GetDescendants() do
	if part:GetAttribute("SourceAsset") == "obstacle_23_002" then
		sphere = part
	end
end
task.wait(2)
RS.Remotes.HazardVisual:FireAllClients(sphere, "shake", 8)
task.wait(9)
RS.Remotes.HazardVisual:FireAllClients(sphere, "impact", 0.8)
task.wait(2)
model:Destroy()
