-- Fail fast on ambiguous layouts instead of silently losing sparse rows.
--!strict
local DoorRows = {}
function DoorRows.resolve(folder: Instance?): { { BasePart } }
	local rows: { [number]: { [number]: BasePart } } = {}
	local rowCount = 0
	if not folder then
		return {}
	end
	for _, part in folder:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local row, index = part:GetAttribute("DoorRow"), part:GetAttribute("DoorIndex")
		if row == nil and index == nil then
			continue
		end
		assert(typeof(row) == "number" and row >= 1 and row % 1 == 0, "[DoorRows] DoorRow must be a positive integer")
		assert(
			typeof(index) == "number" and index >= 1 and index % 1 == 0,
			"[DoorRows] DoorIndex must be a positive integer"
		)
		rows[row] = rows[row] or {}
		assert(rows[row][index] == nil, `[DoorRows] duplicate door {row}:{index}`)
		rows[row][index] = part
		rowCount = math.max(rowCount, row)
	end
	local ordered = {}
	for row = 1, rowCount do
		assert(rows[row], `[DoorRows] missing row {row}`)
		local count = 0
		for _ in rows[row] do
			count += 1
		end
		local doors = {}
		for index = 1, count do
			assert(rows[row][index], `[DoorRows] missing index {row}:{index}`)
			table.insert(doors, rows[row][index])
		end
		table.insert(ordered, doors)
	end
	return ordered
end
return DoorRows
