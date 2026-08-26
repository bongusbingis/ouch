-- Name: run-tests.luau
-- Author: Jack C.
-- Description: Headless test runner that refreshes the Rojo sourcemap, loads every shared spec module through the fake-instance loader, and exits nonzero on failure.
-- Created: 2026-07-12

--!strict

local process = require("@lune/process")
local Loader = require("./loader")

local sourcemap = process.exec("rojo", { "sourcemap", "arena.project.json", "-o", "sourcemap.json" })
if not sourcemap.ok then
	print("warning: rojo sourcemap failed, using existing sourcemap.json")
	print(sourcemap.stderr)
end

local root, load = Loader.build("sourcemap.json")
local tests = root.ReplicatedStorage.Shared.Tests
local TestKit = load(tests.TestKit)

local specNames = {}
for _, child in tests:GetChildren() do
	if string.match(child.Name, "%.spec$") then
		table.insert(specNames, child.Name)
	end
end
table.sort(specNames)

for _, name in specNames do
	print(`-- {name}`)
	load(tests[name])
end

local failures = TestKit.run()
process.exit(if failures == 0 then 0 else 1)
