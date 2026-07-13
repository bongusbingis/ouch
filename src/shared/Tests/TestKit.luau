--!strict

-- Minimal describe/it/expect framework, pure Luau so specs run headlessly
-- under Lune (TestEZ's instance-walking bootstrap can't). Specs require this
-- module directly and register suites as a side effect; the runner calls run().

export type Expectation = {
	toEqual: (self: Expectation, expected: any) -> (),
	toBeNear: (self: Expectation, expected: number, epsilon: number?) -> (),
	toBeTruthy: (self: Expectation) -> (),
	toBeNil: (self: Expectation) -> (),
}

type TestResult = { name: string, err: string? }

local TestKit = {}

local results: { TestResult } = {}
local nameStack: { string } = {}

local function fullName(leaf: string): string
	if #nameStack == 0 then
		return leaf
	end
	return table.concat(nameStack, " / ") .. " / " .. leaf
end

function TestKit.describe(name: string, body: () -> ())
	table.insert(nameStack, name)
	local ok, err = pcall(body)
	table.remove(nameStack)
	if not ok then
		table.insert(results, { name = fullName(name), err = `describe block errored: {err}` })
	end
end

function TestKit.it(name: string, body: () -> ())
	local ok, err = pcall(body)
	table.insert(results, { name = fullName(name), err = if ok then nil else tostring(err) })
end

function TestKit.expect(value: any): Expectation
	local expectation = {}

	function expectation.toEqual(_, expected: any)
		if value ~= expected then
			error(`expected {tostring(expected)}, got {tostring(value)}`, 2)
		end
	end

	function expectation.toBeNear(_, expected: number, epsilon: number?)
		local eps = epsilon or 1e-5
		if typeof(value) ~= "number" or math.abs(value - expected) > eps then
			error(`expected {expected} ±{eps}, got {tostring(value)}`, 2)
		end
	end

	function expectation.toBeTruthy(_)
		if not value then
			error(`expected truthy, got {tostring(value)}`, 2)
		end
	end

	function expectation.toBeNil(_)
		if value ~= nil then
			error(`expected nil, got {tostring(value)}`, 2)
		end
	end

	return expectation :: Expectation
end

-- Prints a summary and returns the failure count.
function TestKit.run(): number
	local failures = 0
	for _, result in results do
		if result.err then
			failures += 1
			print(`  FAIL {result.name}`)
			print(`       {result.err}`)
		else
			print(`  ok   {result.name}`)
		end
	end
	print(`{#results} tests, {failures} failures`)
	return failures
end

return TestKit
