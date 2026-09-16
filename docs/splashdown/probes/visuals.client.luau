-- Temporary client observer; checks the running presentation module, not a copy.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local RS = game.ReplicatedStorage
local Http = game:GetService("HttpService")
local result = Instance.new("StringValue")
result.Name = "SplashdownVisualResults"
result.Value = "waiting"
result.Parent = game.Players.LocalPlayer:WaitForChild("PlayerScripts")
local rows = {}
RS:WaitForChild("Remotes"):WaitForChild("HazardVisual").OnClientEvent:Connect(function(part, kind, duration)
	if not part or not part:FindFirstAncestor("SplashdownVisualProbe") then
		return
	end
	local size, cf = part.Size, part.CFrame
	task.wait(0.1)
	local ghost = workspace.CurrentCamera:FindFirstChild("HazardVisualGhost")
	local row = {
		kind = kind,
		ghostPresent = ghost ~= nil,
		sourceUnchanged = part.Size == size and part.CFrame == cf,
		sourceHidden = part.LocalTransparencyModifier == 1,
	}
	if ghost then
		row.ghostNonColliding = not ghost.CanCollide and not ghost.CanTouch and not ghost.CanQuery
		row.ghostMoved = (ghost.CFrame.Position - cf.Position).Magnitude > 0
			or ghost.CFrame.UpVector ~= cf.UpVector
			or ghost.Size ~= size
	end
	table.insert(rows, row)
	result.Value = Http:JSONEncode(rows)
	task.wait(duration + 0.1)
	row.cleaned = workspace.CurrentCamera:FindFirstChild("HazardVisualGhost") == nil
		and (part.Parent == nil or part.LocalTransparencyModifier == 0)
	result.Value = Http:JSONEncode(rows)
end)
