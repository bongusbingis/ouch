-- Name: merge-places.luau
-- Author: Jack C.
-- Description: Merges the Studio-authored place with the Rojo-built one into a deployable artifact, replacing every Rojo-mapped tree in a copy of the base place while never writing the base file itself.
-- Created: 2026-07-16

--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

type Mapping = { string }

local function usageError(message: string): never
	print(`error: {message}`)
	print("usage: lune run src/scripts/lune/merge-places.luau <project.json> <base.rbxl> <build.rbxl> <out.rbxl>")
	return process.exit(1)
end

local args = table.clone(process.args)
if args[1] == "--" then
	table.remove(args, 1)
end
if #args ~= 4 then
	usageError(`expected 4 arguments, got {#args}`)
end
local projectPath, basePath, buildPath, outputPath = args[1], args[2], args[3], args[4]

for _, path in { projectPath, basePath, buildPath } do
	if not fs.isFile(path) then
		usageError(`missing input file: {path}`)
	end
end

local function collectMappings(node: { [string]: any }, prefix: Mapping, into: { Mapping })
	for key, child in node do
		if string.sub(key, 1, 1) == "$" or typeof(child) ~= "table" then
			continue
		end
		local path = table.clone(prefix)
		table.insert(path, key)
		if child["$path"] ~= nil then
			table.insert(into, path)
		else
			collectMappings(child, path, into)
		end
	end
end

local project = serde.decode("json", fs.readFile(projectPath))
assert(typeof(project.tree) == "table", `[merge-places] {projectPath} has no tree`)
assert(project.tree["$className"] == "DataModel", "[merge-places] project tree must be a DataModel (place project)")

local mappings: { Mapping } = {}
collectMappings(project.tree, {}, mappings)
assert(#mappings > 0, "[merge-places] project tree has no $path mappings")

local basePlace = roblox.deserializePlace(fs.readFile(basePath))
local buildPlace = roblox.deserializePlace(fs.readFile(buildPath))

local function pathString(path: Mapping): string
	return table.concat(path, ".")
end

local function resolve(dataModel: roblox.DataModel, path: Mapping, depth: number): roblox.Instance?
	local current: any = dataModel:GetService(path[1])
	for index = 2, depth do
		current = current and current:FindFirstChild(path[index])
	end
	return current
end

for _, path in mappings do
	assert(#path >= 2, `[merge-places] mapping a whole service ({pathString(path)}) is not supported`)
	local source = resolve(buildPlace, path, #path)
	assert(source ~= nil, `[merge-places] rojo build is missing {pathString(path)}`)

	local baseParent: any = basePlace:GetService(path[1])
	local adopted = false
	for index = 2, #path - 1 do
		local nextNode = baseParent:FindFirstChild(path[index])
		if nextNode == nil then
			local container = resolve(buildPlace, path, index)
			assert(container ~= nil, `[merge-places] rojo build is missing container {path[index]}`)
			local clone = (container :: any):Clone()
			clone.Parent = baseParent
			print(`merged {pathString(path)} (adopted container {path[index]} from build)`)
			adopted = true
			break
		end
		baseParent = nextNode
	end
	if adopted then
		continue
	end

	local leafName = path[#path]
	local stale = baseParent:FindFirstChild(leafName)
	if stale ~= nil then
		stale:Destroy()
	end
	local clone = (source :: any):Clone()
	clone.Parent = baseParent
	print(`merged {pathString(path)}{if stale then " (replaced stale copy)" else ""}`)
end

fs.writeFile(outputPath, roblox.serializePlace(basePlace))
print(`wrote {outputPath}`)
