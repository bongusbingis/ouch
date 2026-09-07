--[[
Studio-only authoring recipes for the fitted R15 costume capsule and preview stage.
Only generated models with this author's version marker may be replaced.
]]
local Author = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rig = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs"):WaitForChild("CharacterRig")
local cosmetics = ReplicatedStorage.Assets:WaitForChild("Cosmetics")
local palette = {
	cream = Color3.fromRGB(255, 240, 203),
	blue = Color3.fromRGB(37, 81, 198),
	coral = Color3.fromRGB(255, 98, 99),
	navy = Color3.fromRGB(35, 38, 78),
	lime = Color3.fromRGB(111, 188, 71),
	yellow = Color3.fromRGB(255, 197, 54),
	gold = Color3.fromRGB(242, 184, 51),
	plum = Color3.fromRGB(108, 57, 153),
	strawberry = Color3.fromRGB(244, 117, 156),
	cocoa = Color3.fromRGB(94, 51, 53),
	bun = Color3.fromRGB(239, 182, 102),
}
local function fresh(parent, name, className)
	local old = parent:FindFirstChild(name)
	if old then
		assert(old:GetAttribute("AuthoringVersion"), name .. " has no authoring ownership marker")
		old:Destroy()
	end
	local instance = Instance.new(className or "Model")
	instance.Name = name
	instance:SetAttribute("AuthoringVersion", 3)
	instance.Parent = parent
	return instance
end
local function part(size, cf, shape)
	local instance = Instance.new("Part")
	instance.Size = size
	instance.CFrame = cf
	instance.Shape = shape or Enum.PartType.Ball
	instance.Anchored = true
	instance.CanCollide = false
	instance.CanTouch = false
	instance.CanQuery = false
	instance.Massless = true
	instance.Material = Enum.Material.SmoothPlastic
	return instance
end
local function finish(model, instance, name, body, color)
	instance.Name = name
	instance.Color = color
	instance.Material = Enum.Material.SmoothPlastic
	instance.Anchored = true
	instance.CanCollide = false
	instance.CanTouch = false
	instance.CanQuery = false
	instance.Massless = true
	instance.CastShadow = true
	if instance:IsA("PartOperation") then
		instance.UsePartColor = true
	end
	if instance:IsA("Part") and instance.Shape == Enum.PartType.Ball then
		instance.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh")
		mesh.Name = "AuthoredEllipsoid"
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.one
		mesh.Parent = instance
	end
	instance:SetAttribute("BodyPart", body)
	instance:SetAttribute("BodySize", rig[body].Size)
	local mount = Instance.new("Attachment")
	mount.Name = "BodyMount"
	mount.CFrame = instance.CFrame:ToObjectSpace(rig[body].CFrame)
	mount.Parent = instance
	instance.Parent = model
	return instance
end
local function shape(model, name, body, size, offset, color, kind)
	return finish(model, part(size, rig[body].CFrame * offset, kind), name, body, color)
end
local function overlay(model, name, body, scale, offset, color)
	local instance = rig[body]:Clone()
	instance:ClearAllChildren()
	instance.TextureID = ""
	instance.Size *= scale
	instance.CFrame = rig[body].CFrame * offset
	return finish(model, instance, name, body, color)
end
local function difference(model, name, body, source, cutters, color)
	source.Parent = model
	local ok, result = pcall(function()
		return source:SubtractAsync(cutters, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	end)
	source:Destroy()
	for _, cutter in cutters do
		cutter:Destroy()
	end
	assert(ok, tostring(result))
	return finish(model, result, name, body, color)
end
local function ring(model, name, body, size, thickness, offset, color)
	local cf = rig[body].CFrame * offset
	local turn = CFrame.Angles(0, 0, math.pi / 2)
	local outer = part(Vector3.new(size.Y, size.X, size.Z), cf * turn, Enum.PartType.Cylinder)
	local inner =
		part(Vector3.new(size.Y * 4, size.X - thickness * 2, size.Z - thickness * 2), cf * turn, Enum.PartType.Cylinder)
	return difference(model, name, body, outer, { inner }, color)
end
local function paddedRing(model, name, body, size, thickness, offset, color)
	local cf = rig[body].CFrame * offset
	local diameter = math.max(size.X, size.Z)
	local outer = part(Vector3.one * diameter, cf)
	local inner = part(
		Vector3.new(diameter * 2, diameter - thickness * 2, diameter - thickness * 2),
		cf * CFrame.Angles(0, 0, math.pi / 2),
		Enum.PartType.Cylinder
	)
	local result = difference(model, name, body, outer, { inner }, color)
	result.Size = size
	result.CFrame = cf
	result.BodyMount.CFrame = cf:ToObjectSpace(rig[body].CFrame)
	return result
end
local function helmet(model, name, color, scale)
	scale = scale or 1
	local cf = rig.Head.CFrame
	local outer = part(Vector3.new(2.26, 2.27, 2.24) * scale, cf)
	local inner = part(Vector3.new(2.01, 2.03, 2.01), cf)
	local opening = part(Vector3.new(2.22, 1.93, 2.70) * scale, cf * CFrame.new(0, -0.17, -1.05))
	local bottom = part(Vector3.new(4, 2, 4), cf * CFrame.new(0, -1.92, 0), Enum.PartType.Block)
	return difference(model, name, "Head", outer, { inner, opening, bottom }, color)
end
local function torso(model, upper, lower)
	overlay(model, "Vest", "UpperTorso", Vector3.one, CFrame.new(), upper):SetAttribute("CoversBody", true)
	overlay(model, "LowerWear", "LowerTorso", Vector3.one, CFrame.new(), lower):SetAttribute("CoversBody", true)
end
local function shoes(model, upper, sole)
	for _, side in { "Left", "Right" } do
		for _, segment in { "UpperLeg", "LowerLeg", "Foot" } do
			overlay(
				model,
				side .. segment,
				side .. segment,
				Vector3.one,
				CFrame.new(),
				segment == "Foot" and sole or upper
			):SetAttribute("CoversBody", true)
		end
	end
end
local function chest(model, color, emblem)
	shape(model, "ChestPatch", "UpperTorso", Vector3.new(1.10, 1.27, 0.45), CFrame.new(0, 0.04, -0.72), color)
	if emblem then
		shape(model, "BallEmblem", "UpperTorso", Vector3.new(0.36, 0.36, 0.16), CFrame.new(0, 0.04, -0.94), emblem)
	end
end
local builders = {}
function builders.FoamLeague(head, body, feet)
	local shell = helmet(head, "HelmetShell", palette.blue)
	local cut = part(Vector3.new(0.26, 4, 4), rig.Head.CFrame, Enum.PartType.Block)
	local stripe = shell:IntersectAsync({ cut }, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	cut:Destroy()
	stripe:ClearAllChildren()
	stripe.Size *= 1.009
	finish(head, stripe, "CrownStripe", "Head", palette.cream)
	for _, sign in { -1, 1 } do
		shape(
			head,
			sign < 0 and "LeftEarPad" or "RightEarPad",
			"Head",
			Vector3.new(0.18, 0.52, 0.54),
			CFrame.new(sign * 1.06, -0.04, 0.02),
			palette.coral
		)
	end
	torso(body, palette.blue, palette.blue)
	chest(body, palette.cream, palette.coral)
	shoes(feet, palette.cream, palette.blue)
end
function builders.RainHopper(head, body, feet)
	helmet(head, "FrogHood", palette.lime)
	for _, sign in { -1, 1 } do
		local side = sign < 0 and "Left" or "Right"
		shape(
			head,
			side .. "EyeSocket",
			"Head",
			Vector3.new(0.59, 0.64, 0.57),
			CFrame.new(sign * 0.65, 0.87, -0.23),
			palette.lime
		)
		shape(
			head,
			side .. "EyeWhite",
			"Head",
			Vector3.new(0.35, 0.38, 0.14),
			CFrame.new(sign * 0.65, 0.92, -0.51),
			palette.cream
		)
		shape(
			head,
			side .. "Pupil",
			"Head",
			Vector3.new(0.13, 0.20, 0.08),
			CFrame.new(sign * 0.65, 0.94, -0.58),
			palette.navy
		)
	end
	torso(body, palette.yellow, palette.yellow)
	for i = 1, 3 do
		shape(
			body,
			"RaincoatButton" .. i,
			"UpperTorso",
			Vector3.new(0.16, 0.16, 0.16),
			CFrame.new(0, 0.45 - i * 0.35, -0.90 - i * 0.012),
			palette.cream
		)
	end
	for _, sign in { -1, 1 } do
		shape(
			body,
			sign < 0 and "LeftPocket" or "RightPocket",
			"UpperTorso",
			Vector3.new(0.52, 0.32, 0.32),
			CFrame.new(sign * 0.64, -0.55, -0.74) * CFrame.Angles(0, sign * -0.28, 0),
			palette.lime
		)
	end
	shoes(feet, palette.yellow, palette.lime)
end
function builders.SnackStack(head, body, feet)
	shape(head, "LettuceBrim", "Head", Vector3.new(2.28, 0.17, 2.08), CFrame.new(0, 0.76, 0), palette.lime)
	shape(head, "PattyBand", "Head", Vector3.new(2.13, 0.21, 1.96), CFrame.new(0, 0.87, 0), palette.cocoa)
	shape(head, "BunCrown", "Head", Vector3.new(2.23, 0.72, 2.07), CFrame.new(0, 1.09, 0), palette.bun)
	for i, offset in { Vector3.new(-0.4, 1.44, -0.2), Vector3.new(0.1, 1.46, -0.32), Vector3.new(0.5, 1.42, 0.03) } do
		shape(
			head,
			"Sesame" .. i,
			"Head",
			Vector3.new(0.10, 0.04, 0.23),
			CFrame.new(offset) * CFrame.Angles(0, i * 0.65, 0),
			palette.cream
		)
	end
	torso(body, palette.coral, palette.coral)
	shape(body, "ApronBib", "UpperTorso", Vector3.new(1.36, 1.72, 0.55), CFrame.new(0, -0.18, -0.74), palette.cream)
	shape(body, "ApronPocket", "UpperTorso", Vector3.new(0.68, 0.36, 0.16), CFrame.new(0, -0.64, -0.96), palette.bun)
	shoes(feet, palette.bun, palette.cocoa)
end
function builders.OrbitRookie(head, body, feet)
	helmet(head, "FlightHelmet", palette.cream, 1.045)
	paddedRing(
		head,
		"HelmetCollar",
		"Head",
		Vector3.new(2.18, 0.25, 2.12),
		0.20,
		CFrame.new(0, -0.79, 0.02),
		palette.navy
	)
	for _, sign in { -1, 1 } do
		shape(
			head,
			sign < 0 and "LeftComms" or "RightComms",
			"Head",
			Vector3.new(0.20, 0.54, 0.57),
			CFrame.new(sign * 1.13, 0.02, 0.06),
			palette.coral
		)
	end
	torso(body, palette.navy, palette.navy)
	shape(body, "FlightPanel", "UpperTorso", Vector3.new(1.30, 0.73, 0.48), CFrame.new(0, -0.07, -0.74), palette.cream)
	shape(
		body,
		"PanelDial",
		"UpperTorso",
		Vector3.new(0.29, 0.29, 0.12),
		CFrame.new(-0.33, -0.06, -0.94),
		palette.coral
	)
	shape(body, "PanelBar", "UpperTorso", Vector3.new(0.47, 0.12, 0.12), CFrame.new(0.20, -0.06, -0.94), palette.blue)
	for _, side in { "Left", "Right" } do
		shape(
			body,
			side .. "ShoulderPad",
			side .. "UpperArm",
			Vector3.new(0.91, 0.56, 0.90),
			CFrame.new(0, 0.18, 0),
			palette.cream
		)
	end
	shoes(feet, palette.cream, palette.navy)
end
function builders.SundaeSprinter(head, body, feet)
	local cream = game:GetService("AssetService"):CreateMeshPartAsync(Content.fromUri("rbxassetid://73959401212970"))
	cream.Size = Vector3.new(2.04, 1.43, 2.04)
	cream.CFrame = rig.Head.CFrame * CFrame.new(0, 1.32, 0)
	cream.TextureID = ""
	finish(head, cream, "SoftServeCrown", "Head", palette.cream)
	shape(head, "Cherry", "Head", Vector3.new(0.38, 0.38, 0.38), CFrame.new(0.08, 2.09, 0), palette.coral)
	torso(body, palette.strawberry, palette.strawberry)
	chest(body, palette.cream, palette.cocoa)
	shape(
		body,
		"WaferBadge",
		"UpperTorso",
		Vector3.new(0.21, 0.53, 0.10),
		CFrame.new(0.25, 0.20, -0.94) * CFrame.Angles(0, 0, -0.45),
		palette.bun
	)
	shoes(feet, palette.cream, palette.strawberry)
end
function builders.PartyRoyal(head, body, feet)
	local base =
		ring(head, "CrownBand", "Head", Vector3.new(2.04, 0.34, 1.94), 0.18, CFrame.new(0, 0.79, 0), palette.gold)
	local points = {}
	for i = 0, 5 do
		local angle = i * math.pi / 3
		local point = part(
			Vector3.new(0.34, 0.75, 0.34),
			rig.Head.CFrame * CFrame.new(math.sin(angle) * 0.84, 1.11, math.cos(angle) * 0.79)
		)
		point.Parent = head
		table.insert(points, point)
	end
	local crown = base:UnionAsync(points, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	crown:ClearAllChildren()
	base:Destroy()
	for _, point in points do
		point:Destroy()
	end
	finish(head, crown, "InflatableCrown", "Head", palette.gold)
	shape(head, "CrownJewel", "Head", Vector3.new(0.25, 0.28, 0.09), CFrame.new(0, 0.82, -0.98), palette.plum)
	torso(body, palette.plum, palette.plum)
	paddedRing(
		body,
		"ShoulderMantle",
		"UpperTorso",
		Vector3.new(2.10, 0.40, 1.74),
		0.42,
		CFrame.new(0, 0.73, 0),
		palette.cream
	)
	shape(
		body,
		"GoldSash",
		"UpperTorso",
		Vector3.new(0.29, 1.78, 0.50),
		CFrame.new(0, -0.1, -0.74) * CFrame.Angles(0, 0, -0.4),
		palette.gold
	)
	shape(body, "SashSeal", "UpperTorso", Vector3.new(0.34, 0.37, 0.18), CFrame.new(0.20, 0.36, -0.91), palette.coral)
	shoes(feet, palette.plum, palette.gold)
end
function Author.outfits(ids)
	local costumes = cosmetics:FindFirstChild("Costumes")
	if not costumes then
		costumes = Instance.new("Folder")
		costumes.Name = "Costumes"
		costumes.Parent = cosmetics
	end
	local result = {}
	for _, id in ids do
		local head = fresh(costumes, id .. "Head")
		local body = fresh(costumes, id .. "Body")
		local feet = fresh(costumes, id .. "Feet")
		assert(builders[id], "Unknown outfit " .. id)(head, body, feet)
		table.insert(result, id)
	end
	return result
end
function Author.previewScene()
	local stage = fresh(cosmetics, "PreviewScene")
	local function stagePart(name, size, cf, color, kind)
		local instance = part(size, cf, kind or Enum.PartType.Block)
		instance.Name = name
		instance.Color = color
		instance.Parent = stage
		return instance
	end
	local turn = CFrame.Angles(0, 0, math.pi / 2)
	local dark = Color3.fromRGB(36, 25, 63)
	stagePart(
		"Ground",
		Vector3.new(1.2, 84, 84),
		CFrame.new(0, -0.6, 0) * turn,
		Color3.fromRGB(69, 46, 107),
		Enum.PartType.Cylinder
	)
	local shell =
		stagePart("BackdropShell", Vector3.new(72, 88, 88), CFrame.new(0, 35, 0) * turn, dark, Enum.PartType.Cylinder)
	local inside =
		stagePart("BackdropCut", Vector3.new(74, 86, 86), CFrame.new(0, 35, 0) * turn, dark, Enum.PartType.Cylinder)
	local front = stagePart("FrontCut", Vector3.new(100, 80, 100), CFrame.new(0, 35, -50), dark)
	local back = shell:SubtractAsync({ inside, front }, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	back.Name = "Backdrop"
	back.Color = dark
	back.UsePartColor = true
	back.Anchored = true
	back.CanCollide = false
	back.CanQuery = false
	back.CanTouch = false
	back.Parent = stage
	shell:Destroy()
	inside:Destroy()
	front:Destroy()
	stagePart(
		"ImpactPlatform",
		Vector3.new(0.16, 7.2, 7.2),
		CFrame.new(0, 0.08, 0) * turn,
		Color3.fromRGB(81, 58, 123),
		Enum.PartType.Cylinder
	)
	stagePart(
		"PlatformRim",
		Vector3.new(0.08, 7.5, 7.5),
		CFrame.new(0, 0.025, 0) * turn,
		Color3.fromRGB(235, 123, 156),
		Enum.PartType.Cylinder
	)
	local origin = stagePart("Origin", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), palette.cream)
	origin.Transparency = 1
	local impact = stagePart("ImpactMarker", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 3, 0), palette.cream)
	impact.Transparency = 1
	local camera = stagePart(
		"CameraMarker",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.lookAt(Vector3.new(0, 12, -34), Vector3.new(0, 3, 0)),
		palette.cream
	)
	camera.Transparency = 1
	stage.PrimaryPart = origin
	stage:SetAttribute("CameraFieldOfView", 55)
	return stage:GetFullName()
end
function Author.review(ids, start)
	local folder = workspace:FindFirstChild("CostumeArtReview")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CostumeArtReview"
		folder.Parent = workspace
	end
	for index, id in ids do
		local old = folder:FindFirstChild(id .. "Review")
		if old then
			old:Destroy()
		end
		local character = rig:Clone()
		character.Name = id .. "Review"
		for _, instance in character:GetDescendants() do
			if instance:IsA("BasePart") then
				instance.Anchored = true
				instance.CanCollide = false
			elseif instance:IsA("BaseScript") then
				instance:Destroy()
			end
		end
		character.Parent = folder
		character:PivotTo(CFrame.new(start + Vector3.new((index - 1) * 5, 2.55, 0)))
		for _, role in { "Head", "Body", "Feet" } do
			local component = cosmetics.Costumes[id .. role]:Clone()
			component.Parent = character
			for _, instance in component:GetDescendants() do
				if instance:IsA("BasePart") then
					local target = character[instance:GetAttribute("BodyPart")]
					instance.CFrame = target.CFrame * instance.BodyMount.CFrame:Inverse()
					if instance:GetAttribute("CoversBody") then
						target.Transparency = 1
					end
				end
			end
		end
	end
	return folder:GetFullName()
end
return Author
