-- Name: CourseSequence.luau
-- Author: Jack C.
-- Description: Pure draw of the courses a Splashdown match plays, distinct while the roster of courses allows it and never repeating the previous pick when it must reuse one, with the random source injected.
-- Created: 2026-09-14

--!strict

local CourseSequence = {}

function CourseSequence.draw(courseIds: { string }, count: number, chooseIndex: (number) -> number): { string }
	assert(#courseIds > 0, "[CourseSequence] at least one course is required")
	assert(count % 1 == 0 and count >= 1, "[CourseSequence] count must be a positive integer")

	local pool = table.clone(courseIds)
	local sequence = {}
	for _ = 1, count do
		if #pool == 0 then
			pool = table.clone(courseIds)
			local previous = sequence[#sequence]
			if #pool > 1 and previous ~= nil then
				local index = table.find(pool, previous)
				if index then
					table.remove(pool, index)
				end
			end
		end
		local index = chooseIndex(#pool)
		assert(index % 1 == 0 and index >= 1 and index <= #pool, "[CourseSequence] chooser returned an invalid index")
		table.insert(sequence, table.remove(pool, index) :: string)
	end
	return sequence
end

return table.freeze(CourseSequence)
