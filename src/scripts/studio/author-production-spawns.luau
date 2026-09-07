-- Studio-only authoring pass for full-capacity, grounded, separated arena spawn markers.
--!strict
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run spawn authoring in Edit mode")
local arena = workspace:WaitForChild("Assets"):WaitForChild("Arena")
local general = arena:WaitForChild("PlayerSpawns")
local teams = arena:WaitForChild("TeamSpawns")
local map = arena:WaitForChild("Map")
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { map }
params.RespectCanCollide = true
local function floorAt(x: number, z: number, expected: number): Vector3?
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -250, 0), params)
	if not hit or hit.Normal.Y < 0.95 or math.abs(hit.Position.Y - expected) > 1 then
		return nil
	end
	for _, offset in { Vector3.new(4, 0, 0), Vector3.new(-4, 0, 0), Vector3.new(0, 0, 4), Vector3.new(0, 0, -4) } do
		local edge = workspace:Raycast(hit.Position + offset + Vector3.new(0, 8, 0), Vector3.new(0, -10, 0), params)
		if not edge or edge.Normal.Y < 0.95 or math.abs(edge.Position.Y - hit.Position.Y) > 0.5 then
			return nil
		end
	end
	return hit.Position
end
local candidates = {}
for x = -580, -490, 18 do
	for z = -94, -4, 18 do
		local point = floorAt(x, z, 461.8)
		if point then
			table.insert(candidates, point)
		end
	end
end
local chosen = {}
while #chosen < 20 do
	local best, clearance = nil, -1
	for index, point in candidates do
		local distance = math.huge
		for _, other in chosen do
			distance = math.min(distance, (point - other).Magnitude)
		end
		if distance > clearance then
			best = index
			clearance = distance
		end
	end
	assert(best and clearance >= 12, "Insufficient safe general spawn clearance")
	table.insert(chosen, table.remove(candidates, best))
end
local plans = { { folder = general, points = chosen } }
for _, team in { { name = "Blue", x = -640 }, { name = "Red", x = -436 } } do
	local points = {}
	for index = 0, 9 do
		local point = floorAt(team.x, -130 + index * 16, 416.3)
		assert(point, `Unsafe {team.name} spawn {index + 1}`)
		table.insert(points, point)
	end
	table.insert(plans, { folder = teams:WaitForChild(team.name), points = points })
end
local template = general:WaitForChild("Part")
assert(template:IsA("BasePart"), "General spawn template must be a BasePart")
for _, plan in plans do
	local existing = {}
	for _, child in plan.folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(existing, child)
		end
	end
	table.sort(existing, function(a, b)
		return a.Name < b.Name
	end)
	for index, point in plan.points do
		local marker = existing[index] or template:Clone()
		marker.Name = if index == 1 then "Part" else string.format("Spawn%02d", index)
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanTouch = false
		marker.CanQuery = false
		marker.Transparency = 1
		marker.CFrame = CFrame.lookAt(point, Vector3.new(-544, point.Y, -58))
		marker.Parent = plan.folder
	end
end
return { general = #chosen, perTeam = 10 }
