--[[
Studio-only recipe that converts a 3D-Importer outfit drop into costume components.
Reads workspace.<Id>_Imported and writes Assets.Cosmetics.Costumes.<Id>{Head,Body,Feet}.
Only generated models with this author's version marker may be replaced.
]]
local Author = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rig = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs"):WaitForChild("CharacterRig")
local cosmetics = ReplicatedStorage.Assets:WaitForChild("Cosmetics")
local roles = {
	Head = { "Head" },
	Body = { "UpperTorso", "RightUpperArm", "RightLowerArm", "LeftUpperArm", "LeftLowerArm" },
	Feet = { "RightLowerLeg", "RightFoot", "LeftLowerLeg", "LeftFoot" },
}
local packages = {
	PrismCloud = {
		prefix = "PC_",
		pieces = {
			Head = {
				size = Vector3.new(2.565000057, 2.501309872, 1.597642183),
				offset = Vector3.new(-0.000000060, 0.131844997, 0.296135038),
			},
			UpperTorso = {
				size = Vector3.new(2.770000219, 1.605000019, 2.434928417),
				offset = Vector3.new(0.000000000, 0.273299068, -0.002112299),
			},
			RightUpperArm = {
				size = Vector3.new(1.133000374, 1.058400035, 1.089000106),
				offset = Vector3.new(-0.000000119, 0.000000000, -0.005499884),
			},
			RightLowerArm = {
				size = Vector3.new(1.048000216, 0.245999992, 1.088999987),
				offset = Vector3.new(0.000000000, -0.122999996, -0.010499924),
			},
			RightLowerLeg = {
				size = Vector3.new(1.219751239, 0.636422396, 1.369545817),
				offset = Vector3.new(-0.000000060, -0.023211122, -0.042827070),
			},
			RightFoot = {
				size = Vector3.new(1.209100008, 0.544350386, 1.353550076),
				offset = Vector3.new(0.000000000, 0.029925108, -0.045474991),
			},
			LeftUpperArm = {
				size = Vector3.new(1.133000374, 1.058400035, 1.089000106),
				offset = Vector3.new(-0.000000119, 0.000000000, -0.005499884),
			},
			LeftLowerArm = {
				size = Vector3.new(1.048000216, 0.245999992, 1.088999987),
				offset = Vector3.new(0.000000000, -0.122999996, -0.010499924),
			},
			LeftLowerLeg = {
				size = Vector3.new(1.219751239, 0.636422396, 1.369545817),
				offset = Vector3.new(0.000000060, -0.023211122, -0.042827070),
			},
			LeftFoot = {
				size = Vector3.new(1.209100008, 0.544350386, 1.353550076),
				offset = Vector3.new(0.000000000, 0.029924870, -0.045474991),
			},
		},
	},
	CosmicArcade = {
		prefix = "CA_",
		pieces = {
			Head = {
				size = Vector3.new(2.394999981, 2.136141777, 1.704998136),
				offset = Vector3.new(0.000000000, 0.005858660, 0.222499400),
			},
			UpperTorso = {
				size = Vector3.new(2.753549814, 1.535567284, 2.737592220),
				offset = Vector3.new(0.000000000, 0.260785192, 0.192723960),
			},
			RightUpperArm = {
				size = Vector3.new(1.116499305, 1.015200138, 1.075249672),
				offset = Vector3.new(0.000000119, 0.000000030, -0.006875172),
			},
			RightLowerArm = {
				size = Vector3.new(0.993999958, 0.142035604, 1.013999939),
				offset = Vector3.new(0.000000000, 0.071779758, 0.000000015),
			},
			RightLowerLeg = {
				size = Vector3.new(1.171611309, 0.698252439, 1.246506691),
				offset = Vector3.new(0.000000000, 0.027937293, -0.005371600),
			},
			RightFoot = {
				size = Vector3.new(1.195725083, 0.502739906, 1.332149982),
				offset = Vector3.new(0.009362519, 0.011970282, -0.050825015),
			},
			LeftUpperArm = {
				size = Vector3.new(1.116499424, 1.015200138, 1.075249672),
				offset = Vector3.new(0.000000119, 0.000000030, -0.006875172),
			},
			LeftLowerArm = {
				size = Vector3.new(0.993999958, 0.142035604, 1.013999939),
				offset = Vector3.new(0.000000000, 0.071779758, 0.000000015),
			},
			LeftLowerLeg = {
				size = Vector3.new(1.171611309, 0.698252439, 1.246506691),
				offset = Vector3.new(0.000000000, 0.027937293, -0.005371600),
			},
			LeftFoot = {
				size = Vector3.new(1.195725083, 0.502739906, 1.332149982),
				offset = Vector3.new(-0.009362519, 0.011970282, -0.050825015),
			},
		},
	},
}
local function fresh(parent, name)
	local old = parent:FindFirstChild(name)
	if old then
		assert(old:GetAttribute("AuthoringVersion"), name .. " has no authoring ownership marker")
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("AuthoringVersion", 3)
	model.Parent = parent
	return model
end
local function source(drop, meshName)
	local found
	for _, instance in drop:GetDescendants() do
		if instance.Name == meshName and instance:IsA("MeshPart") then
			assert(not found, `[ModelerOutfit] {drop.Name} has more than one {meshName}`)
			found = instance
		end
	end
	return assert(found, `[ModelerOutfit] {drop.Name} is missing MeshPart {meshName}`)
end
-- The FBX export's world orientation is not guaranteed: Blender's exporter lands
-- this package in Studio a half turn about Y, so every piece faces backwards.
-- Measure it instead of assuming -- the mesh named for the left arm has to sit on
-- the rig's left (-X), and a positive difference means the whole drop is yawed.
-- Sizes are restated from the fit data, so the export's scale needs no handling.
local function detectYaw(drop, package)
	local left = source(drop, package.prefix .. "LeftUpperArm")
	local right = source(drop, package.prefix .. "RightUpperArm")
	local flipped = (left.Position.X - right.Position.X) > 0
	return if flipped then CFrame.Angles(0, math.pi, 0) else CFrame.identity
end
local function component(model, drop, package, body, yaw)
	local spec = assert(package.pieces[body], `[ModelerOutfit] No fit data for {body}`)
	local target = assert(rig:FindFirstChild(body), `[ModelerOutfit] CharacterRig has no {body}`)
	local instance = source(drop, package.prefix .. body):Clone()
	for _, child in instance:GetChildren() do
		if not child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	instance.Name = body
	instance.Size = spec.size
	instance.CFrame = target.CFrame * CFrame.new(spec.offset) * yaw
	instance.Anchored = true
	instance.CanCollide, instance.CanQuery, instance.CanTouch = false, false, false
	instance.Massless = true
	instance.CastShadow = true
	instance:SetAttribute("BodyPart", body)
	instance:SetAttribute("BodySize", target.Size)
	local mount = Instance.new("Attachment")
	mount.Name = "BodyMount"
	mount.CFrame = instance.CFrame:ToObjectSpace(target.CFrame)
	mount.Parent = instance
	instance.Parent = model
	return instance
end
function Author.convert(ids)
	local costumes = cosmetics:FindFirstChild("Costumes")
	if not costumes then
		costumes = Instance.new("Folder")
		costumes.Name = "Costumes"
		costumes.Parent = cosmetics
	end
	local result = {}
	for _, id in ids do
		local package = assert(packages[id], `[ModelerOutfit] Unknown package {id}`)
		local drop = assert(
			workspace:FindFirstChild(id .. "_Imported"),
			`[ModelerOutfit] Import the FBX and name the model {id}_Imported in Workspace`
		)
		local yaw = detectYaw(drop, package)
		local built = 0
		for role, bodies in roles do
			local model = fresh(costumes, id .. role)
			for _, body in bodies do
				component(model, drop, package, body, yaw)
				built += 1
			end
		end
		assert(built == 10, `[ModelerOutfit] {id} wrote {built} pieces, expected 10`)
		table.insert(result, id)
	end
	return result
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
		for role in roles do
			local piece = cosmetics.Costumes[id .. role]:Clone()
			piece.Parent = character
			for _, instance in piece:GetDescendants() do
				if instance:IsA("BasePart") then
					local target = character[instance:GetAttribute("BodyPart")]
					instance.CFrame = target.CFrame * instance.BodyMount.CFrame:Inverse()
				end
			end
		end
	end
	return folder:GetFullName()
end
return Author
