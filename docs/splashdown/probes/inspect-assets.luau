-- Discovery only. Run through execute_luau in Studio Edit mode.
-- Reads the showcase, registered templates, and parked legacy courses; never moves them.
local HttpService = game:GetService("HttpService")
local function vector(v)
	return { v.X, v.Y, v.Z }
end
local function frame(cf)
	return { cf:GetComponents() }
end
local function bounds(root)
	local pivot = root:GetPivot()
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	local parts = if root:IsA("BasePart") then { root } else {}
	for _, child in root:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	for _, part in parts do
		for _, x in { -0.5, 0.5 } do
			for _, y in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					local p = pivot:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z)))
					low = Vector3.new(math.min(low.X, p.X), math.min(low.Y, p.Y), math.min(low.Z, p.Z))
					high = Vector3.new(math.max(high.X, p.X), math.max(high.Y, p.Y), math.max(high.Z, p.Z))
				end
			end
		end
	end
	return parts, vector(high - low), frame(pivot), vector((high + low) / 2)
end
local result = {
	placeId = game.PlaceId,
	gravity = workspace.Gravity,
	starter = {
		walkSpeed = game.StarterPlayer.CharacterWalkSpeed,
		jumpPower = game.StarterPlayer.CharacterJumpPower,
		jumpHeight = game.StarterPlayer.CharacterJumpHeight,
		useJumpPower = game.StarterPlayer.CharacterUseJumpPower,
	},
	assets = {},
	courses = {},
}
local showcase = assert(workspace:FindFirstChild("battle_stadium"), "Missing asset showcase")
local meshFamilies = {}
local children = showcase:GetChildren()
table.sort(children, function(a, b)
	return a.Name < b.Name
end)
for _, source in children do
	if not (source:IsA("Model") or source:IsA("BasePart")) then
		continue
	end
	local parts, size, pivot, center = bounds(source)
	local row = {
		name = source.Name,
		class = source.ClassName,
		path = source:GetFullName(),
		size = size,
		pivot = pivot,
		boundsCenterInPivot = center,
		partCount = #parts,
		parts = {},
		scripts = {},
		usedBy = {},
	}
	for _, part in parts do
		local mesh = if part:IsA("MeshPart") then part.MeshId else ""
		if mesh ~= "" then
			meshFamilies[mesh] = meshFamilies[mesh] or {}
			table.insert(meshFamilies[mesh], row)
		end
		table.insert(row.parts, {
			name = part.Name,
			size = vector(part.Size),
			cframe = frame(part.CFrame),
			pivotOffset = frame(part.PivotOffset),
			meshId = mesh,
			attributes = part:GetAttributes(),
			anchored = part.Anchored,
			canCollide = part.CanCollide,
		})
	end
	for _, child in source:GetDescendants() do
		if child:IsA("LuaSourceContainer") then
			table.insert(row.scripts, child:GetFullName())
		end
	end
	table.insert(result.assets, row)
end
local folders = { game.ReplicatedStorage.Assets.Maps.Splashdown }
local legacy = workspace:FindFirstChild("LegacyCourses")
if legacy then
	table.insert(folders, legacy)
end
for _, folder in folders do
	for _, model in folder:GetChildren() do
		if not model:IsA("Model") or not model:FindFirstChild("Start") then
			continue
		end
		local origin = model:FindFirstChild("Origin")
		local row = {
			name = model.Name,
			path = model:GetFullName(),
			parts = 0,
			meshParts = 0,
			instances = #model:GetDescendants(),
			families = {},
			attributes = {},
			hazards = {},
			spawns = 0,
			checkpoints = 0,
			maxCornerRadius = 0,
			maxSpawnDistance = 0,
			cloneSeconds = 0,
		}
		local used = {}
		for _, part in model:GetDescendants() do
			if not part:IsA("BasePart") then
				continue
			end
			row.parts += 1
			if part:IsA("MeshPart") then
				row.meshParts += 1
				for _, asset in meshFamilies[part.MeshId] or {} do
					used[asset.name] = true
					asset.usedBy[model.Name] = true
				end
			end
			local attrs = part:GetAttributes()
			if next(attrs) then
				table.insert(
					row.attributes,
					{ path = part:GetFullName(), attributes = attrs, size = vector(part.Size) }
				)
			end
			for name, value in attrs do
				if name == "Rotor" or name == "Bumper" or name == "Fan" or name == "DoorRow" then
					local key = if name == "Rotor" then "Rotor:" .. tostring(value) else name
					row.hazards[key] = (row.hazards[key] or 0) + 1
				end
			end
			if origin then
				for _, x in { -0.5, 0.5 } do
					for _, y in { -0.5, 0.5 } do
						for _, z in { -0.5, 0.5 } do
							local p = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z)) - origin.Position
							row.maxCornerRadius = math.max(row.maxCornerRadius, p.Magnitude)
						end
					end
				end
			end
		end
		for name in used do
			table.insert(row.families, name)
		end
		table.sort(row.families)
		for _, pad in model.Start.Pads:GetChildren() do
			if pad:IsA("BasePart") then
				row.spawns += 1
				row.maxSpawnDistance = math.max(row.maxSpawnDistance, (pad.Position - origin.Position).Magnitude)
			end
		end
		row.checkpoints = #model.Checkpoints:GetChildren()
		local t = os.clock()
		local copy = model:Clone()
		row.cloneSeconds = os.clock() - t
		copy:Destroy()
		table.insert(result.courses, row)
	end
end
table.sort(result.courses, function(a, b)
	return a.name < b.name
end)
-- Page large results to stay below the Studio tool response limit. Prefix the
-- chunk with local ASSET_FIRST, ASSET_LAST = 1, 12 (and optionally COURSE_INDEX).
local allAssets = result.assets
result.assetCount = #allAssets
result.assets = {}
for index = ASSET_FIRST or 1, math.min(ASSET_LAST or 0, #allAssets) do
	table.insert(result.assets, allAssets[index])
end
for index, row in result.courses do
	if index ~= COURSE_INDEX then
		row.attributes = nil
	end
end
return HttpService:JSONEncode(result)
