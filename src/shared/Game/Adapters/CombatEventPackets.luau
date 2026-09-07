-- Copies only the bounded combat-event schema; singleton batches retain the existing wire format.
--!strict

local Packets = {}
local strings = { "kind", "projectileId", "playerId", "sourceId", "targetId" }
local numbers = { "tick", "magnitude" }
local vectors = { "position", "normal", "direction" }

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function Packets.encode(events: { any }): { { any } }
	local batches = {}
	for _, event in events do
		if event.kind == "Elim" then
			continue
		end
		local copied = {}
		local valid = type(event.kind) == "string"
		for _, key in strings do
			local value = event[key]
			if value ~= nil then
				if type(value) ~= "string" or #value > 64 then
					valid = false
				else
					copied[key] = value
				end
			end
		end
		for _, key in numbers do
			local value = event[key]
			if value ~= nil then
				if type(value) ~= "number" or not finite(value) then
					valid = false
				else
					copied[key] = value
				end
			end
		end
		for _, key in vectors do
			local value = event[key]
			if value ~= nil then
				local kind = typeof(value)
				if
					(kind ~= "vector" and kind ~= "Vector3")
					or not (finite(value.x) and finite(value.y) and finite(value.z))
				then
					valid = false
				else
					copied[key] = value
				end
			end
		end
		if valid then
			table.insert(batches, { copied })
		end
	end
	return batches
end

return Packets
