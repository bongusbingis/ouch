-- Install as a normal temporary Script under ServerScriptService.Server.Scripts
-- (Rojo syncs places/arena/server/Scripts) and press Play. HANDOFF.md section 5.1
-- steps 3-4: for each listed source it clones the asset out of the injected
-- ServerStorage.SplashdownAuthoringSources.Kit, anchors the clone, moves it to an
-- isolated point far from anything else, and casts a downward raycast grid
-- through it, converting every hit to the clone's own object space so the
-- recorded sockets are root-local and independent of where the source sits. It
-- then derives Entry/Exit/Support/side sockets from the measured footprint and a
-- coarse hit/height cell map that shows real holes. The source gallery and the
-- exported Kit are never modified. Delete this script before committing.
--
-- Only WALKABLE surfaces belong in this list. Mounted hazard mechanisms are not
-- raycast-scanned: their Support contact and sub-part poses come from the
-- already-measured size/pivot rows in docs/splashdown/evidence/inventory.json,
-- exactly as course-sockets-ballbarrage.json records for the pilot's hazards.
assert(game:GetService("RunService"):IsStudio(), "Studio only")

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local RAY_STEP = 0.5
local EDGE_STEP = 0.25
local CELL_STUDS = 5
local ISOLATION = Vector3.new(0, 12000, 0)

local TARGETS = {
	{ Id = "obstacle_16_002", Role = "PizzaPlate", ForwardAxis = "Z" },
	{ Id = "obstacle_13_001", Role = "CarouselDeck", ForwardAxis = "Z" },
	{ Id = "obstacle_14_002", Role = "DiscPlateSmall", ForwardAxis = "Z" },
	{ Id = "obstacle_15_002", Role = "DiscPlateLarge", ForwardAxis = "Z" },
	{ Id = "obstacle_26_002", Role = "DiscPlateLargeVariant", ForwardAxis = "Z" },
	{ Id = "obstacle_8_002", Role = "SwingPanelDeck", ForwardAxis = "Z" },
	{ Id = "octagon_002", Role = "HubDeck", ForwardAxis = "Z" },
	{ Id = "water_platform_001", Role = "SmallRoundLanding", ForwardAxis = "Z" },
}

local result = Instance.new("StringValue")
result.Name = "SplashdownSocketResults"
result.Value = "running"
result.Parent = ServerStorage

local CHUNK = 150000
local function writeChunked(payload: string)
	for _, existing in ServerStorage:GetChildren() do
		if existing:IsA("StringValue") and string.match(existing.Name, "^SplashdownSocketChunk%d+$") then
			existing:Destroy()
		end
	end
	local count = math.max(1, math.ceil(#payload / CHUNK))
	for index = 1, count do
		local chunk = Instance.new("StringValue")
		chunk.Name = string.format("SplashdownSocketChunk%d", index)
		chunk.Value = string.sub(payload, (index - 1) * CHUNK + 1, index * CHUNK)
		chunk.Parent = ServerStorage
	end
	result.Value = string.format("chunks=%d length=%d", count, #payload)
end

local function findSource(kit: Instance, id: string): BasePart
	local queue: { Instance } = { kit }
	while #queue > 0 do
		local node = table.remove(queue) :: Instance
		if node.Name == id and node:IsA("BasePart") then
			return node :: BasePart
		end
		for _, child in node:GetChildren() do
			table.insert(queue, child)
		end
	end
	error(`[measure-course-sockets] source "{id}" not found under the injected Kit`)
end

local function measure(kit: Instance, target: { Id: string, Role: string, ForwardAxis: string })
	local source = findSource(kit, target.Id)
	local holder = Instance.new("Folder")
	holder.Name = "SplashdownSocketScratch"
	holder.Parent = Workspace

	local clone = source:Clone()
	clone.Anchored = true
	clone.CanCollide = true
	clone.CanQuery = true
	clone.PivotOffset = CFrame.identity
	clone.CFrame = CFrame.new(ISOLATION)
	clone.Parent = holder

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { clone }

	local size = clone.Size
	local halfX, halfZ = size.X / 2, size.Z / 2
	local top = ISOLATION.Y + size.Y + 8
	local depth = size.Y * 2 + 16

	local hits, misses = 0, 0
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	local cells: { [string]: number } = {}

	local function cast(localX: number, localZ: number)
		local origin = Vector3.new(ISOLATION.X + localX, top, ISOLATION.Z + localZ)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -depth, 0), params)
		if not hit then
			misses += 1
			return
		end
		hits += 1
		local point = clone.CFrame:PointToObjectSpace(hit.Position)
		minX, maxX = math.min(minX, point.X), math.max(maxX, point.X)
		minZ, maxZ = math.min(minZ, point.Z), math.max(maxZ, point.Z)
		minY, maxY = math.min(minY, point.Y), math.max(maxY, point.Y)
		local key = string.format(
			"%d,%d",
			math.floor((point.X + halfX) / CELL_STUDS),
			math.floor((point.Z + halfZ) / CELL_STUDS)
		)
		cells[key] = math.max(cells[key] or -math.huge, point.Y)
	end

	local x = -halfX
	while x <= halfX do
		local z = -halfZ
		while z <= halfZ do
			cast(x, z)
			z += RAY_STEP
		end
		-- 5.1.3 asks for finer sampling near boundaries and holes; the centre
		-- lines are where a round plate's hub hole and a pizza's missing wedges
		-- actually sit, so they are resampled at the edge step.
		cast(x, 0)
		cast(x, EDGE_STEP)
		cast(x, -EDGE_STEP)
		x += RAY_STEP
		task.wait()
	end

	local columns = math.ceil(size.X / CELL_STUDS)
	local rows = math.ceil(size.Z / CELL_STUDS)
	local cellMap = {}
	for row = rows - 1, 0, -1 do
		local line = {}
		for column = 0, columns - 1 do
			local value = cells[string.format("%d,%d", column, row)]
			table.insert(line, if value then string.format("%5.1f", value) else "    .")
		end
		table.insert(cellMap, table.concat(line, ""))
	end

	holder:Destroy()

	local topY = maxY
	return {
		role = target.Role,
		size = { size.X, size.Y, size.Z },
		rayStep = RAY_STEP,
		edgeStep = EDGE_STEP,
		hits = hits,
		misses = misses,
		topLocalY = topY,
		lowestHitLocalY = minY,
		footprintX = { minX, maxX },
		footprintZ = { minZ, maxZ },
		cellStuds = CELL_STUDS,
		cellMap = cellMap,
		sockets = {
			forwardAxis = target.ForwardAxis,
			Entry = { topY, minZ },
			Exit = { topY, maxZ },
			SideNegativeX = { minX, topY },
			SidePositiveX = { maxX, topY },
			Support = { -size.Y / 2 },
		},
	}
end

local ok, answer = xpcall(function()
	local root = ServerStorage:FindFirstChild("SplashdownAuthoringSources")
	assert(root, "[measure-course-sockets] ServerStorage.SplashdownAuthoringSources is missing")
	local kit = root:FindFirstChild("Kit")
	assert(kit, "[measure-course-sockets] SplashdownAuthoringSources.Kit is missing")

	local assets = {}
	for _, target in TARGETS do
		assets[target.Id] = measure(kit, target)
	end
	return {
		purpose = "Real Studio raycast measurements of the walkable ride/landing surfaces Whirlpool Waltz uses, per HANDOFF.md section 5.1 steps 3-4.",
		placeId = game.PlaceId,
		rayStep = RAY_STEP,
		assets = assets,
	}
end, debug.traceback)

writeChunked(HttpService:JSONEncode({ ok = ok, result = answer }))
print("[measure-course-sockets] ok=" .. tostring(ok) .. " " .. result.Value)
