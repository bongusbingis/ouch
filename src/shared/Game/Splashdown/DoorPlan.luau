-- Name: DoorPlan.luau
-- Author: Jack C.
-- Description: Pure choice of which doors in each row of a Knock Knock course break away, a fixed number per row with the random source injected, so a round's door plan is decided once on the server and never readable from the client.
-- Created: 2026-09-14

--!strict

local DoorPlan = {}

export type Rows = { { string } }

function DoorPlan.choose(rows: Rows, breakablePerRow: number, chooseIndex: (number) -> number): { [string]: boolean }
	assert(breakablePerRow % 1 == 0 and breakablePerRow >= 0, "[DoorPlan] breakablePerRow must be a whole number")
	local plan: { [string]: boolean } = {}
	for _, row in rows do
		local pool = table.clone(row)
		for _ = 1, math.min(breakablePerRow, #pool) do
			local index = chooseIndex(#pool)
			assert(index % 1 == 0 and index >= 1 and index <= #pool, "[DoorPlan] chooser returned an invalid index")
			plan[table.remove(pool, index) :: string] = true
		end
	end
	return plan
end

return table.freeze(DoorPlan)
