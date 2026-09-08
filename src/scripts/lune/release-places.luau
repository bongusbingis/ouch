-- Releases one commit: verify all artifacts, test all affected places, then publish the tested bytes.
--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Artifact = require("./release-artifact")
local Receipt = require("./release-receipt")

local args = process.args
assert(#args == 2, "usage: lune run src/scripts/lune/release-places.luau <artifact-directory> <places-json>")
local selected = serde.decode("json", args[2])
assert(type(selected) == "table" and #selected > 0 and #selected <= 2, "[release] expected one or two places")
local places: { string } = {}
local seen: { [string]: boolean } = {}
for key, place in selected do
	assert(type(key) == "number" and key >= 1 and key <= #selected, "[release] places must be an array")
	assert(place == "arena" or place == "lobby", "[release] invalid place")
	assert(not seen[place], "[release] duplicate place")
	seen[place] = true
	table.insert(places, place)
end
table.sort(places)

local function requireEnv(name: string): string
	local value = process.env[name]
	assert(value and value ~= "", `[release] {name} is required`)
	return value
end

requireEnv("ROBLOX_API_KEY")
local universeId = requireEnv("ROBLOX_UNIVERSE_ID")
local revision = process.exec("git", { "rev-parse", "HEAD" })
assert(revision.ok, "[release] cannot resolve release commit")
local commit = string.gsub(revision.stdout, "%s+$", "")
assert(
	not process.env.GITHUB_SHA or process.env.GITHUB_SHA == commit,
	"[release] checkout does not match workflow commit"
)

local function assertCurrentProductionHead()
	if process.env.GITHUB_ACTIONS ~= "true" then
		return
	end
	assert(process.env.GITHUB_REF == "refs/heads/prod", "[release] GitHub releases must run from the prod branch")
	local remote = process.exec("git", { "ls-remote", "--exit-code", "origin", "refs/heads/prod" })
	assert(remote.ok, "[release] cannot verify current prod HEAD")
	local remoteCommit = string.match(remote.stdout, "^([0-9a-f]+)%s+refs/heads/prod%s*$")
	assert(remoteCommit == commit, "[release] refusing stale release: this commit is no longer prod HEAD")
end

local function summary(message: string)
	print(message)
	local path = process.env.GITHUB_STEP_SUMMARY
	if path then
		local previous = if fs.isFile(path) then fs.readFile(path) else ""
		fs.writeFile(path, previous .. message .. "\n\n")
	end
end

type Target = { place: string, placeId: string, directory: string, file: string }
local targets: { Target } = {}
for _, place in places do
	local placeId = requireEnv(string.upper(place) .. "_PLACE_ID")
	local directory = `{args[1]}/place-{place}`
	local manifest = Artifact.verify(directory, place, commit)
	local project = serde.decode("json", fs.readFile(manifest.project))
	assert(
		type(project.servePlaceIds) == "table"
			and #project.servePlaceIds == 1
			and tostring(project.servePlaceIds[1]) == placeId,
		`[release] {place} target does not match {manifest.project}`
	)
	table.insert(targets, { place = place, placeId = placeId, directory = directory, file = `{directory}/dist.rbxl` })
end

summary(`Release commit: {commit}`)

local function run(target: Target, mode: string)
	Artifact.verify(target.directory, target.place, commit)
	local result = process.exec("lune", {
		"run",
		"src/scripts/lune/test-and-deploy.luau",
		target.file,
		"src/scripts/cloud/RunTests.luau",
		mode,
	}, {
		env = { ROBLOX_PLACE_ID = target.placeId },
		stdio = "inherit",
	})
	if not result.ok then
		if mode == "--stage-only" then
			summary(`Failed staging {target.place}; this release published no places.`)
		else
			summary(`Publication failed for {target.place}; check retained version evidence before retrying.`)
		end
		if result.code == 2 then
			print("::warning::Roblox Open Cloud remained busy after retries. Re-run the release job.")
		end
		process.exit(result.code)
	end
end

assertCurrentProductionHead()
for _, target in targets do
	run(target, "--stage-only")
end
for _, target in targets do
	local evidence = Receipt.verify(target.file, universeId, target.placeId)
	summary(
		`{target.place}: saved version {evidence.savedVersionId} passed cloud tests; SHA-256 {evidence.artifactSha256}`
	)
end
assertCurrentProductionHead()
for _, target in targets do
	run(target, "--publish-tested")
	local evidence = serde.decode("json", fs.readFile(target.file .. ".published.json"))
	summary(`{target.place}: published version {evidence.publishedVersionId}`)
end
