-- Edit-only, reproducible kit fixture, NOT a registered course or replacement.
-- Captures the existing meshes before the venue loader clears the asset gallery.
assert(game:GetService("RunService"):IsStudio() and not game:GetService("RunService"):IsRunning(), "Edit mode only")
local source = assert(workspace:FindFirstChild("battle_stadium"), "Open the Match Place asset gallery")
local RS = game.ReplicatedStorage
local previous = RS:FindFirstChild("SplashdownKitFixtures")
if previous then
	assert(previous:GetAttribute("SplashdownProbeOwned") == true, "Refusing to replace foreign fixture")
	previous:Destroy()
end
local fixtures = Instance.new("Folder")
fixtures.Name = "SplashdownKitFixtures"
fixtures:SetAttribute("SplashdownProbeOwned", true)
local specs = {
	{ name = "BigBall", asset = "obstacle_23_001", scale = 1 },
	{ name = "Roller", asset = "obstacle_2_001", scale = 0.5 },
	{ name = "Piston", asset = "obstacle_22_001", scale = 0.5 },
	{ name = "Mace", asset = "obstacle_5_001", scale = 0.7 },
	{ name = "Hammer", asset = "obstacle_4_001", scale = 0.6 },
	{ name = "Seesaw", asset = "obstacle_25_001", scale = 0.6 },
	{ name = "Pizza", asset = "obstacle_16_001", scale = 0.4 },
	{ name = "Carousel", asset = "obstacle_13_001", scale = 0.4 },
	{ name = "Conveyor", asset = "obstacle_9_001", scale = 1 },
	{ name = "Tile", asset = "color_box_001", scale = 0.5 },
	{ name = "Fan", asset = "propeller_trampoline_1_001", scale = 0.5 },
	{ name = "BeachBall", asset = "ball_001", scale = 0.5 },
	{ name = "Bumper", asset = "obstacle_18_001", scale = 0.5 },
	{ name = "Spinner", asset = "obstacle_6_001", scale = 0.5 },
	{ name = "Disc", asset = "obstacle_14_001", scale = 0.5 },
	{ name = "SwingPanel", asset = "obstacle_8_001", scale = 0.5 },
}
for _, spec in specs do
	local original = assert(source:FindFirstChild(spec.asset), "Missing asset " .. spec.asset)
	local model = Instance.new("Model")
	model.Name = spec.name
	local clone = original:Clone()
	clone.Parent = model
	model.PrimaryPart = clone
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("SourceAsset", part.Name)
			part.Name = if part == clone
				then "Base"
				else "Piece" .. tostring(#part.Name) .. "_" .. part.Name:match("(%d+)$")
			part.Anchored = true
			part.CanCollide = true
			-- Imported display pivots are not mechanical axes. Author explicit pivots in each test.
			part.PivotOffset = CFrame.identity
		end
	end
	model:ScaleTo(spec.scale)
	model:PivotTo(CFrame.identity)
	model.Parent = fixtures
end
fixtures.Parent = RS
return #fixtures:GetChildren()
