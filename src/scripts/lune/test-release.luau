-- Exercises the real release scripts with in-memory files, child processes, and Open Cloud responses.
--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local commit = string.rep("a", 40)
local sources = {}
for _, name in { "release-artifact", "release-receipt", "release-places", "test-and-deploy" } do
	sources[name] = luau.compile(fs.readFile(`src/scripts/lune/{name}.luau`))
end
local passed = 0

local function loadScript(name: string, modules: any, log: (string) -> ()): any
	return luau.load(sources[name], {
		debugName = name,
		environment = {
			require = function(dependency: string)
				assert(modules[dependency], `unexpected dependency: {dependency}`)
				return modules[dependency]
			end,
			print = log,
		},
		injectGlobals = true,
	})()
end

local function fixture(): any
	local context: any = {
		files = {
			["wally.lock"] = "locked fixture dependencies",
			["src/scripts/cloud/RunTests.luau"] = "fixture payload",
		},
		events = {},
		logs = {},
		requests = 0,
		cloudStates = {},
		remoteCommit = commit,
		remoteAvailable = true,
		remoteChecks = {},
		onChild = nil,
	}
	local env = {
		ROBLOX_API_KEY = "fixture-key",
		ROBLOX_UNIVERSE_ID = "100",
		ARENA_PLACE_ID = "200",
		LOBBY_PLACE_ID = "300",
		GITHUB_SHA = commit,
		GITHUB_STEP_SUMMARY = "summary.md",
	}
	local placeNames = { ["200"] = "arena", ["300"] = "lobby" }
	local function log(message: string)
		table.insert(context.logs, message)
	end
	local modules: any = {
		["@lune/serde"] = serde,
		["@lune/fs"] = {
			isFile = function(path: string)
				return context.files[path] ~= nil
			end,
			readFile = function(path: string)
				assert(context.files[path], `missing fixture file: {path}`)
				return context.files[path]
			end,
			writeFile = function(path: string, bytes: string)
				context.files[path] = bytes
			end,
		},
		["@lune/task"] = {
			spawn = function(callback: () -> ())
				callback()
				return {}
			end,
			wait = function()
				error("unexpected fixture wait")
			end,
		},
		["@lune/net"] = {
			request = function(config: any)
				assert(config.method == "GET", "unexpected HTTP mutation")
				context.requests += 1
				local placeId = string.match(config.url, "/places/(%d+)/")
				assert(placeNames[placeId], "unexpected HTTP target")
				local body = if string.match(config.url, "/logs$")
					then {}
					else { state = context.cloudStates[placeId] or "COMPLETE" }
				return { ok = true, statusCode = 200, body = serde.encode("json", body) }
			end,
		},
	}
	local function argument(args: { string }, flag: string): string?
		local index = table.find(args, flag)
		return if index then args[index + 1] else nil
	end
	local function execute(command: string, args: { string }, options: any): any
		if command == "git" then
			if args[1] == "ls-remote" then
				assert(
					table.concat(args, ",") == "ls-remote,--exit-code,origin,refs/heads/prod",
					"unexpected remote check"
				)
				table.insert(context.remoteChecks, table.concat(context.events, ","))
				return {
					ok = context.remoteAvailable,
					code = if context.remoteAvailable then 0 else 128,
					stdout = context.remoteCommit .. "\trefs/heads/prod\n",
					stderr = if context.remoteAvailable then "" else "fixture remote unavailable",
				}
			end
			assert(args[1] == "rev-parse" and args[2] == "HEAD", "unexpected git command")
			return { ok = true, code = 0, stdout = commit .. "\n", stderr = "" }
		elseif command == "lune" then
			assert(args[1] == "run" and args[2] == "src/scripts/lune/test-and-deploy.luau", "unexpected child")
			local childArgs = { args[3], args[4], args[5] }
			local result = context.run("test-and-deploy", childArgs, options.env)
			if context.onChild then
				context.onChild(args[5], placeNames[options.env.ROBLOX_PLACE_ID], result)
			end
			return result
		end
		assert(command == "rbxcloud", `unexpected command: {command}`)
		local placeId = argument(args, "--place-id")
		local place = placeNames[placeId]
		assert(place and argument(args, "--universe-id") == env.ROBLOX_UNIVERSE_ID, "unexpected Roblox target")
		local body
		if args[1] == "experience" and args[2] == "publish" then
			local versionType = argument(args, "--version-type")
			assert(versionType == "saved" or versionType == "published", "unexpected upload type")
			table.insert(context.events, `{versionType}:{place}`)
			body = { versionNumber = if versionType == "saved" then 11 else 12 }
		else
			assert(args[1] == "luau" and args[2] == "execute", "unexpected Roblox command")
			assert(argument(args, "--version-id") == "11", "cloud task must test the uploaded saved version")
			table.insert(context.events, `test:{place}`)
			body = { path = `universes/{env.ROBLOX_UNIVERSE_ID}/places/{placeId}/luau-execution-session-tasks/fixture` }
		end
		return { ok = true, code = 0, stdout = serde.encode("json", body), stderr = "" }
	end
	modules["@lune/process"] = { exec = execute }
	modules["./release-artifact"] = loadScript("release-artifact", modules, log)
	modules["./release-receipt"] = loadScript("release-receipt", modules, log)
	context.receipt = modules["./release-receipt"]
	context.env = env

	function context.run(name: string, args: { string }, extraEnv: any): any
		local childModules = table.clone(modules)
		local childEnv = table.clone(env)
		for key, value in extraEnv or {} do
			childEnv[key] = value
		end
		local exitSignal = {}
		local code = 0
		childModules["@lune/process"] = {
			args = args,
			env = childEnv,
			exec = execute,
			exit = function(exitCode: number)
				code = exitCode
				error(exitSignal, 0)
			end,
		}
		local ok, err = pcall(loadScript, name, childModules, log)
		if not ok and err ~= exitSignal then
			code = 1
		end
		return { ok = code == 0, code = code, stdout = "", stderr = if err == exitSignal then "" else tostring(err) }
	end

	function context.deploy(place: string, mode: string?): any
		local args = { `out/place-{place}/dist.rbxl`, "src/scripts/cloud/RunTests.luau" }
		if mode then
			table.insert(args, mode)
		end
		return context.run("test-and-deploy", args, { ROBLOX_PLACE_ID = env[string.upper(place) .. "_PLACE_ID"] })
	end

	function context.release(): any
		return context.run("release-places", { "out", '["lobby","arena"]' })
	end

	for placeId, place in placeNames do
		local directory = `out/place-{place}`
		context.files[`places/{place}/{place}.rbxl`] = `{place} authored fixture bytes`
		context.files[`{directory}/dist.rbxl`] = `{place} merged fixture bytes`
		context.files[`{place}.project.json`] = serde.encode("json", { servePlaceIds = { tonumber(placeId) } })
		local manifest =
			modules["./release-artifact"].create(place, `places/{place}/{place}.rbxl`, `{directory}/dist.rbxl`)
		context.files[`{directory}/manifest.json`] = serde.encode("json", manifest)
	end
	return context
end

local function test(name: string, run: () -> ())
	run()
	passed += 1
	print(`PASS {name}`)
end

local function assertEvents(context: any, expected: string)
	local actual = table.concat(context.events, ",")
	assert(actual == expected, `expected events {expected}; got {actual}`)
end

test("all places are staged and tested before any publication", function()
	local context = fixture()
	local result = context.release()
	assert(result.ok, result.stderr)
	assertEvents(context, "saved:arena,test:arena,saved:lobby,test:lobby,published:arena,published:lobby")
	assert(#context.remoteChecks == 0, "manual releases must not require the prod remote")
end)

local function githubFixture(): any
	local context = fixture()
	context.env.GITHUB_ACTIONS = "true"
	context.env.GITHUB_REF = "refs/heads/prod"
	return context
end

test("GitHub releases verify prod HEAD before staging and once before publication", function()
	local context = githubFixture()
	local result = context.release()
	assert(result.ok, result.stderr)
	assertEvents(context, "saved:arena,test:arena,saved:lobby,test:lobby,published:arena,published:lobby")
	assert(#context.remoteChecks == 2, "the publication group must have exactly two remote checks")
	assert(context.remoteChecks[1] == "", "initial remote check ran after staging")
	assert(
		context.remoteChecks[2] == "saved:arena,test:arena,saved:lobby,test:lobby",
		"final remote check must precede all publications"
	)
end)

test("a stale GitHub rerun never stages or publishes", function()
	local context = githubFixture()
	context.remoteCommit = string.rep("b", 40)
	local result = context.release()
	assert(
		not result.ok and string.find(result.stderr, "refusing stale release", 1, true),
		"stale release was accepted"
	)
	assertEvents(context, "")
	assert(#context.remoteChecks == 1, "stale release continued after initial check")
end)

test("prod advancing during staging prevents every publication", function()
	local context = githubFixture()
	context.onChild = function(mode, place)
		if mode == "--stage-only" and place == "lobby" then
			context.remoteCommit = string.rep("b", 40)
		end
	end
	local result = context.release()
	assert(not result.ok and string.find(result.stderr, "refusing stale release", 1, true), "advanced prod was ignored")
	assertEvents(context, "saved:arena,test:arena,saved:lobby,test:lobby")
	assert(#context.remoteChecks == 2, "prod was not rechecked after staging")
end)

for _, afterStaging in { false, true } do
	local phase = if afterStaging then "after staging" else "before staging"
	test(`an unavailable prod remote aborts {phase}`, function()
		local context = githubFixture()
		context.remoteAvailable = afterStaging
		context.onChild = function(mode, place)
			if mode == "--stage-only" and place == "lobby" then
				context.remoteAvailable = false
			end
		end
		local result = context.release()
		assert(
			not result.ok and string.find(result.stderr, "cannot verify current prod HEAD", 1, true),
			"unverifiable prod was accepted"
		)
		assertEvents(context, if afterStaging then "saved:arena,test:arena,saved:lobby,test:lobby" else "")
	end)
end

test("GitHub releases refuse a branch other than prod", function()
	local context = githubFixture()
	context.env.GITHUB_REF = "refs/heads/main"
	assert(not context.release().ok, "non-prod workflow was accepted")
	assertEvents(context, "")
	assert(#context.remoteChecks == 0, "non-prod workflow reached the remote check")
end)

test("a failing second stage publishes no places", function()
	local context = fixture()
	context.cloudStates["300"] = "FAILED"
	assert(not context.release().ok, "failed cloud tests were accepted")
	assertEvents(context, "saved:arena,test:arena,saved:lobby,test:lobby")
	assert(not context.files["out/place-arena/dist.rbxl.published.json"], "first place was published")
end)

test("all receipts are verified before the first publication", function()
	local context = fixture()
	context.onChild = function(mode, place)
		if mode == "--stage-only" and place == "lobby" then
			local path = "out/place-lobby/dist.rbxl.tested.json"
			local evidence = serde.decode("json", context.files[path])
			evidence.state = "FAILED"
			context.files[path] = serde.encode("json", evidence)
		end
	end
	assert(not context.release().ok, "invalid second receipt was accepted")
	assertEvents(context, "saved:arena,test:arena,saved:lobby,test:lobby")
end)

for _, case in
	{
		{ field = "artifactSha256", value = string.rep("b", 64), message = "artifact hash" },
		{ field = "schemaVersion", value = 2, message = "manifest schema" },
		{ field = "commit", value = string.rep("b", 40), message = "commit" },
	}
do
	test(`invalid artifact {case.message} prevents staging`, function()
		local context = fixture()
		local path = "out/place-lobby/manifest.json"
		local manifest = serde.decode("json", context.files[path])
		manifest[case.field] = case.value
		context.files[path] = serde.encode("json", manifest)
		assert(not context.release().ok, "invalid artifact was accepted")
		assertEvents(context, "")
	end)
end

test("a mismatched target prevents staging", function()
	local context = fixture()
	context.env.LOBBY_PLACE_ID = "400"
	assert(not context.release().ok, "wrong target was accepted")
	assertEvents(context, "")
end)

test("a missing artifact prevents staging", function()
	local context = fixture()
	context.files["out/place-lobby/dist.rbxl"] = nil
	assert(not context.release().ok, "missing artifact was accepted")
	assertEvents(context, "")
end)

test("publish-tested reuses completed evidence without uploading or retesting a saved version", function()
	local context = fixture()
	assert(context.deploy("arena", "--stage-only").ok, "staging failed")
	assertEvents(context, "saved:arena,test:arena")
	local evidence = context.receipt.verify("out/place-arena/dist.rbxl", "100", "200")
	assert(evidence.savedVersionId == "11", "incorrect saved version evidence")
	local requests = context.requests
	context.events = {}
	assert(context.deploy("arena", "--publish-tested").ok, "tested publication failed")
	assertEvents(context, "published:arena")
	assert(context.requests == requests, "publish-tested reran cloud tests")
	local published = serde.decode("json", context.files["out/place-arena/dist.rbxl.published.json"])
	assert(published.publishedVersionId == "12" and published.savedVersionId == "11", "publication evidence changed")
end)

test("the default deploy mode still tests before publishing despite an existing receipt", function()
	local context = fixture()
	assert(context.deploy("arena", "--stage-only").ok, "staging failed")
	context.events = {}
	assert(context.deploy("arena").ok, "deployment failed")
	assertEvents(context, "saved:arena,test:arena,published:arena")
end)

for _, case in
	{
		{ field = "artifactSha256", value = string.rep("b", 64), label = "wrong hash" },
		{ field = "universeId", value = "999", label = "wrong universe" },
		{ field = "placeId", value = "300", label = "wrong place" },
		{ field = "schemaVersion", value = 2, label = "wrong schema" },
		{ field = "state", value = "FAILED", label = "failed tests" },
		{ field = "state", value = "PROCESSING", label = "unfinished tests" },
		{ field = "savedVersionId", value = "", label = "missing saved version" },
		{ field = "taskPath", value = "universes/999/places/200/tasks/fixture", label = "wrong task target" },
		{ field = "taskPath", value = "", label = "missing task" },
	}
do
	test(`publish-tested rejects evidence with {case.label}`, function()
		local context = fixture()
		assert(context.deploy("arena", "--stage-only").ok, "staging failed")
		local path = "out/place-arena/dist.rbxl.tested.json"
		local evidence = serde.decode("json", context.files[path])
		evidence[case.field] = case.value
		context.files[path] = serde.encode("json", evidence)
		context.events = {}
		assert(not context.deploy("arena", "--publish-tested").ok, "invalid receipt was accepted")
		assertEvents(context, "")
	end)
end

test("publish-tested rejects missing evidence", function()
	local context = fixture()
	assert(not context.deploy("arena", "--publish-tested").ok, "missing receipt was accepted")
	assertEvents(context, "")
end)

test("publish-tested rejects bytes changed since testing", function()
	local context = fixture()
	assert(context.deploy("arena", "--stage-only").ok, "staging failed")
	context.files["out/place-arena/dist.rbxl"] ..= "changed"
	context.events = {}
	assert(not context.deploy("arena", "--publish-tested").ok, "changed bytes were accepted")
	assertEvents(context, "")
end)

test("a failed retry invalidates an earlier successful receipt", function()
	local context = fixture()
	assert(context.deploy("arena", "--stage-only").ok, "staging failed")
	context.cloudStates["200"] = "FAILED"
	assert(not context.deploy("arena", "--stage-only").ok, "failed retry was accepted")
	context.events = {}
	assert(not context.deploy("arena", "--publish-tested").ok, "stale success authorized publication")
	assertEvents(context, "")
end)

test("the in-place cloud gate regression suite also passes headlessly", function()
	local sourcemap = process.exec("rojo", { "sourcemap", "arena.project.json" })
	assert(sourcemap.ok, sourcemap.stderr)
	local loaderModules = {
		["@lune/fs"] = {
			readFile = function(path: string)
				return if path == "fixture-sourcemap" then sourcemap.stdout else fs.readFile(path)
			end,
		},
		["@lune/luau"] = luau,
		["@lune/serde"] = serde,
	}
	local Loader = luau.load(fs.readFile("src/scripts/lune/loader.luau"), {
		environment = {
			require = function(name: string)
				assert(loaderModules[name], `unexpected loader dependency: {name}`)
				return loaderModules[name]
			end,
		},
		injectGlobals = true,
	})()
	local root, load = Loader.build("fixture-sourcemap")
	local implementation = luau.load(fs.readFile("Packages/testEZ.lua"), {
		environment = {
			script = root.ReplicatedStorage.Packages.testEZ,
			require = function(node: any)
				return node
			end,
		},
		injectGlobals = true,
	})()
	local TestEZ = { TestPlanner = load(implementation.TestPlanner), TestRunner = load(implementation.TestRunner) }
	local method = luau.load(fs.readFile("src/tests/Shared/CloudTestGate.spec.luau"), {
		environment = {
			game = root,
			script = root.ServerStorage.Tests.Shared["CloudTestGate.spec"],
			require = function(node: any)
				return if node == root.ReplicatedStorage.Packages.testEZ then TestEZ else load(node)
			end,
		},
		injectGlobals = true,
	})()
	local results = TestEZ.TestRunner.runPlan(TestEZ.TestPlanner.createPlan({
		{ method = method, path = { "CloudTestGate" }, pathStringForSorting = "cloudtestgate" },
	}))
	assert(
		results.successCount == 5 and results.failureCount == 0 and #results.errors == 0,
		table.concat(results.errors, "\n")
	)
end)

print(`{passed} release regressions passed`)
