-- Edit-only visual review fixture. Clones nine catalog visuals into an isolated sheet; Clear restores the saved camera.
--!strict

local CATEGORY = "BallAssets"
local PAGE = 1
local CLEAR = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local Workspace = game:GetService("Workspace")

assert(not RunService:IsRunning(), "[CosmeticContactSheet] Stop Play before creating an Edit review sheet")
assert(CATEGORY == "BallAssets" or CATEGORY == "HammerAssets", "[CosmeticContactSheet] Invalid category")
assert(PAGE >= 1 and PAGE <= 4 and PAGE % 1 == 0, "[CosmeticContactSheet] Page must be 1 through 4")

local camera = Workspace.CurrentCamera
assert(camera, "[CosmeticContactSheet] A Studio viewport camera is required")
local old = Workspace:FindFirstChild("CosmeticNamingSheet")
local cameraFrame, fieldOfView = camera.CFrame, camera.FieldOfView
if old then
	assert(
		old:GetAttribute("ReviewOwner") == "CosmeticContactSheet",
		"[CosmeticContactSheet] Existing folder is not ours"
	)
	cameraFrame = old:GetAttribute("SavedCameraFrame")
	fieldOfView = old:GetAttribute("SavedFieldOfView")
	old:Destroy()
end
if CLEAR then
	camera.CFrame, camera.FieldOfView = cameraFrame, fieldOfView
	return "Review sheet removed and camera restored"
end

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Factory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CosmeticVisualFactory")
)
local sheet = Instance.new("Folder")
sheet.Name = "CosmeticNamingSheet"
sheet:SetAttribute("ReviewOwner", "CosmeticContactSheet")
sheet:SetAttribute("SavedCameraFrame", cameraFrame)
sheet:SetAttribute("SavedFieldOfView", fieldOfView)
sheet.Parent = Workspace

local prefix = if CATEGORY == "BallAssets" then "DodgeBall" else "Hammer"
local origin = Vector3.new(0, 60, 5000)
local visuals, manifest = {}, {}
local function fixed(part: BasePart)
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.Massless = true
end

local lightHost = Instance.new("Part")
lightHost.Name = "ReviewFill"
lightHost.Size = Vector3.one
lightHost.CFrame = CFrame.new(origin + Vector3.new(0, 0, 14))
lightHost.Transparency = 1
fixed(lightHost)
lightHost.Parent = sheet
local light = Instance.new("PointLight")
light.Color = Color3.new(1, 1, 1)
light.Brightness = 3
light.Range = 60
light.Shadows = false
light.Parent = lightHost

for cell = 0, 8 do
	local itemId = prefix .. tostring((PAGE - 1) * 9 + cell + 1)
	local definition = Cosmetics.Items[itemId]
	assert(definition, `[CosmeticContactSheet] Unknown item {itemId}`)
	local center = origin + Vector3.new((cell % 3 - 1) * 9, (1 - math.floor(cell / 3)) * 9, 0)
	local backdrop = Instance.new("Part")
	backdrop.Name = itemId .. "Card"
	backdrop.Size = Vector3.new(8.7, 8.7, 0.1)
	backdrop.CFrame = CFrame.new(center + Vector3.new(0, 0, -3))
	backdrop.Color = Color3.fromRGB(43, 49, 66)
	backdrop.Material = Enum.Material.SmoothPlastic
	fixed(backdrop)
	backdrop.Parent = sheet

	local visual = Factory.create(CATEGORY, itemId)
	visual.Name = itemId
	fixed(visual)
	if CATEGORY == "BallAssets" then
		visual.Size *= 2.6
	end
	visual.CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0))
		* CFrame.Angles(
			0,
			math.rad(if CATEGORY == "HammerAssets" then 80 else 25),
			math.rad(if CATEGORY == "HammerAssets" then 12 else 0)
		)
	for _, child in visual:GetDescendants() do
		if child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Beam") then
			child.Enabled = false
		end
	end
	visual.Parent = sheet
	table.insert(visuals, visual)

	local caption = Instance.new("BillboardGui")
	caption.Name = itemId .. "Caption"
	caption.Adornee = backdrop
	caption.AlwaysOnTop = true
	caption.LightInfluence = 0
	caption.Size = UDim2.fromScale(8.2, 1.2)
	caption.StudsOffsetWorldSpace = Vector3.new(0, -3.35, 4)
	caption.Parent = backdrop
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Text = `{itemId}  ·  {definition.Rarity}`
	label.Parent = caption
	table.insert(manifest, {
		itemId = itemId,
		displayName = definition.DisplayName,
		colorMap = definition.Visual.SurfaceMaps and definition.Visual.SurfaceMaps.ColorMapId,
	})
end

camera.FieldOfView = 35
camera.CFrame = CFrame.lookAt(origin + Vector3.new(0, 0, 46), origin)
local loaded, loadError = pcall(ContentProvider.PreloadAsync, ContentProvider, visuals)
return {
	category = CATEGORY,
	page = PAGE,
	items = manifest,
	texturesLoaded = loaded,
	preloadError = if loaded then nil else tostring(loadError),
	cleanup = "Run again with CLEAR = true before saving or publishing the place",
}
