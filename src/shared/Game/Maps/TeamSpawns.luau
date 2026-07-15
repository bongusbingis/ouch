--!strict

-- Splits a map's flat spawn-point set into contiguous per-team groups along
-- the horizontal axis of greatest spread — the map cut in half (or into N
-- slices for N teams). Teams are assigned low-to-high in the order given.
-- Pure so the partition math is headlessly testable.

local TeamSpawns = {}

local function component(position: vector, useX: boolean): number
	return if useX then position.x else position.z
end

function TeamSpawns.split(positions: { vector }, teams: { string }): { [string]: { number } }
	assert(#teams > 0, "[TeamSpawns] no teams to assign")
	assert(#positions >= #teams, "[TeamSpawns] fewer spawn points than teams")

	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	for _, position in positions do
		minX = math.min(minX, position.x)
		maxX = math.max(maxX, position.x)
		minZ = math.min(minZ, position.z)
		maxZ = math.max(maxZ, position.z)
	end
	local splitOnX = (maxX - minX) >= (maxZ - minZ)

	local order = table.create(#positions)
	for index = 1, #positions do
		order[index] = index
	end
	table.sort(order, function(a, b)
		local pa, pb = positions[a], positions[b]
		local primaryA, primaryB = component(pa, splitOnX), component(pb, splitOnX)
		if primaryA ~= primaryB then
			return primaryA < primaryB
		end
		local secondaryA, secondaryB = component(pa, not splitOnX), component(pb, not splitOnX)
		if secondaryA ~= secondaryB then
			return secondaryA < secondaryB
		end
		return a < b
	end)

	local base = #positions // #teams
	local extra = #positions % #teams
	local assignments: { [string]: { number } } = {}
	local cursor = 1
	for teamIndex, teamId in teams do
		local count = base + (if teamIndex <= extra then 1 else 0)
		local group = table.create(count)
		for _ = 1, count do
			table.insert(group, order[cursor])
			cursor += 1
		end
		assignments[teamId] = group
	end
	return assignments
end

return TeamSpawns
