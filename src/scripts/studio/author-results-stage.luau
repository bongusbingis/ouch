-- Run in Studio Edit mode in each place. Authors the shared results-stage template.
local assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets")
local ui = assets:WaitForChild("UI")
assert(ui:FindFirstChild("ResultsStage") == nil, "ResultsStage already exists; edit the authored model in Studio")
local stage = Instance.new("Model")
stage.Name = "ResultsStage"
local ink = Color3.fromRGB(28, 23, 57)
local white = Color3.fromRGB(255, 251, 245)
local cyan = Color3.fromRGB(30, 218, 217)
local pink = Color3.fromRGB(241, 26, 135)
local yellow = Color3.fromRGB(255, 222, 49)
local function part(parent, name, size, frame, color, cylinder)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = frame
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	if cylinder then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = parent
	return p
end
local function disc(parent, name, x, y, z, diameter, height, color)
	return part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		true
	)
end
local origin = part(stage, "Origin", Vector3.one, CFrame.identity, white)
origin.Transparency = 1
stage.PrimaryPart = origin
local confetti = part(stage, "ConfettiPiece", Vector3.new(0.12, 0.22, 0.025), CFrame.identity, white)
confetti.Transparency = 1
part(stage, "Backdrop", Vector3.new(250, 160, 1), CFrame.new(0, 50, -15), Color3.fromRGB(105, 35, 187))
local texture = Instance.new("Texture")
texture.Texture = "rbxassetid://5975725510"
texture.Face = Enum.NormalId.Back
texture.StudsPerTileU = 14
texture.StudsPerTileV = 14
texture.Transparency = 0.84
texture.Parent = stage.Backdrop
disc(stage, "DeckShadow", 0, -1.1, 0, 37, 1, ink)
disc(stage, "DeckRim", 0, -0.6, 0, 36.6, 0.7, white)
disc(stage, "Deck", 0, -0.15, 0, 35.7, 0.5, Color3.fromRGB(85, 66, 153))
local stands = Instance.new("Folder")
stands.Name = "Stands"
stands.Parent = stage
for index, info in { { 0, 3.1, yellow }, { -7.2, 2.3, cyan }, { 7.2, 1.5, pink } } do
	local x, height, color = info[1], info[2], info[3]
	local stand = Instance.new("Model")
	stand.Name = "Stand" .. index
	stand.Parent = stands
	local bottom = part(stand, "Origin", Vector3.one, CFrame.new(x, 0, 0), white)
	bottom.Transparency = 1
	stand.PrimaryPart = bottom
	disc(stand, "Shadow", x, 0.15, 0, 6.8, 0.3, ink)
	disc(stand, "Pillar", x, height / 2, 0, 6.3, height, color)
	disc(stand, "Rim", x, height - 0.14, 0, 6.5, 0.32, white)
	disc(stand, "Top", x, height + 0.04, 0, 6.1, 0.1, color)
	local marker = part(stand, "Avatar", Vector3.one, CFrame.new(x, height + 0.11, 0), white)
	marker.Transparency = 1
	local plaque =
		part(stand, "Plaque", Vector3.new(3, math.min(height - 0.3, 1.7), 0.05), CFrame.new(x, height / 2, 3.18), color)
	plaque.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.LightInfluence = 0
	gui.Parent = plaque
	local rank = Instance.new("TextLabel")
	rank.Name = "Rank"
	rank.Size = UDim2.fromScale(1, 1)
	rank.BackgroundTransparency = 1
	rank.Text = tostring(index)
	rank.Font = Enum.Font.LuckiestGuy
	rank.TextScaled = true
	rank.TextColor3 = white
	rank.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = ink
	stroke.Parent = rank
end
for _, side in { -1, 1 } do
	part(
		stage,
		"Wing" .. side,
		Vector3.new(4.5, 27, 2),
		CFrame.new(side * 19, 10, -9) * CFrame.Angles(0, 0, side * -0.16),
		if side == 1 then pink else cyan
	)
	part(
		stage,
		"WingTrim" .. side,
		Vector3.new(0.5, 27, 2.1),
		CFrame.new(side * 16.7, 10, -9) * CFrame.Angles(0, 0, side * -0.16),
		white
	)
end
stage:SetAttribute("AssetVersion", 1)
stage.Parent = ui
return stage:GetFullName()
