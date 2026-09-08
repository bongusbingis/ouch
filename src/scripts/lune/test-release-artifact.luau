-- Exercises release provenance checks in memory without changing authored places.
--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local commit = string.rep("a", 40)
local source = luau.compile(fs.readFile("src/scripts/lune/release-artifact.luau"))
local passed = 0

local function fixture(): (any, { [string]: string }, any)
	local files = {
		["places/arena/arena.rbxl"] = "authored source bytes",
		["out/dist.rbxl"] = "merged artifact bytes",
		["wally.lock"] = "locked dependencies",
	}
	local modules = {
		["@lune/fs"] = {
			isFile = function(path: string)
				return files[path] ~= nil
			end,
			readFile = function(path: string)
				assert(files[path], `missing fixture file: {path}`)
				return files[path]
			end,
		},
		["@lune/process"] = {
			exec = function(command: string, args: { string })
				assert(command == "git" and args[1] == "rev-parse" and args[2] == "HEAD", "unexpected command")
				return { ok = true, stdout = commit .. "\n", stderr = "" }
			end,
		},
		["@lune/serde"] = serde,
	}
	local artifact = luau.load(source, {
		debugName = "release-artifact",
		environment = {
			require = function(name: string)
				assert(modules[name], `unexpected module: {name}`)
				return modules[name]
			end,
		},
		injectGlobals = true,
	})()
	local manifest = artifact.create("arena", "places/arena/arena.rbxl", "out/dist.rbxl")
	files["out/manifest.json"] = serde.encode("json", manifest)
	return artifact, files, manifest
end

local function test(name: string, run: () -> ())
	run()
	passed += 1
	print(`PASS {name}`)
end

local function rejects(run: () -> (), message: string)
	local ok, err = pcall(run)
	assert(not ok and string.find(tostring(err), message, 1, true), `expected rejection containing: {message}`)
end

test("verified artifact retains its commit and source hashes", function()
	local artifact, files, manifest = fixture()
	local verified = artifact.verify("out", "arena", commit)
	assert(verified.commit == commit, "commit changed")
	assert(verified.baseSha256 == serde.hash("sha256", files["places/arena/arena.rbxl"]), "base hash changed")
	assert(verified.artifactSha256 == manifest.artifactSha256, "artifact hash changed")
end)

test("verification does not require the original authored base", function()
	local artifact, files = fixture()
	files["places/arena/arena.rbxl"] = nil
	assert(artifact.verify("out", "arena", commit).place == "arena", "place changed")
end)

test("changed merged bytes are rejected", function()
	local artifact, files = fixture()
	files["out/dist.rbxl"] ..= "changed"
	rejects(function()
		artifact.verify("out", "arena", commit)
	end, "merged artifact hash mismatch")
end)

test("changed dependency lock is rejected", function()
	local artifact, files = fixture()
	files["wally.lock"] ..= "changed"
	rejects(function()
		artifact.verify("out", "arena", commit)
	end, "dependency lock hash mismatch")
end)

for _, case in
	{
		{ place = "lobby", commit = commit, message = "unexpected place" },
		{ place = "arena", commit = string.rep("b", 40), message = "unexpected commit" },
	}
do
	test(case.message .. " is rejected", function()
		local artifact = fixture()
		rejects(function()
			artifact.verify("out", case.place, case.commit)
		end, case.message)
	end)
end

for _, case in
	{
		{ field = "schemaVersion", value = 2, message = "unsupported manifest schema" },
		{ field = "project", value = "lobby.project.json", message = "project does not match place" },
		{ field = "basePath", value = "places/lobby/lobby.rbxl", message = "base path does not match place" },
		{ field = "artifactSha256", value = "invalid", message = "invalid artifactSha256" },
	}
do
	test(case.message .. " is rejected", function()
		local artifact, files, manifest = fixture()
		manifest[case.field] = case.value
		files["out/manifest.json"] = serde.encode("json", manifest)
		rejects(function()
			artifact.verify("out", "arena", commit)
		end, case.message)
	end)
end

for _, path in { "out/manifest.json", "out/dist.rbxl", "wally.lock" } do
	test(`missing {path} is rejected`, function()
		local artifact, files = fixture()
		files[path] = nil
		rejects(function()
			artifact.verify("out", "arena", commit)
		end, "missing")
	end)
end

print(`{passed} release artifact regressions passed`)
