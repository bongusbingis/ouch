-- Builds and records a deployable copy without writing into the authored place directories.
--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local ReleaseArtifact = require("./release-artifact")

local args = table.clone(process.args)
if args[1] == "--" then
	table.remove(args, 1)
end
assert(
	#args == 2 and (args[1] == "arena" or args[1] == "lobby") and args[2] ~= "",
	"usage: lune run src/scripts/lune/build-place.luau <arena|lobby> <output-directory>"
)
local place, directory = args[1], args[2]
local project = `{place}.project.json`
assert(fs.isFile(project), `[build-place] missing {project}; run from the repository root`)

local bases = {}
for _, name in fs.readDir(`places/{place}`) do
	local path = `places/{place}/{name}`
	if string.match(name, "%.rbxl$") and fs.isFile(path) then
		table.insert(bases, path)
	end
end
assert(
	#bases == 1,
	`[build-place] expected exactly one Studio-authored places/{place}/*.rbxl, found {#bases}; import with ROBLOX_API_KEY set: bash src/scripts/shell/pull-places.sh {place}, then commit the Git LFS file`
)
local basePath = bases[1]
local baseBytes = fs.readFile(basePath)
assert(
	#baseBytes >= 10000 and string.sub(baseBytes, 1, 7) == "<roblox",
	`[build-place] {basePath} is not complete place data; run git lfs pull or import it with ROBLOX_API_KEY set: bash src/scripts/shell/pull-places.sh {place}`
)
local baseHash = serde.hash("sha256", baseBytes)

if not fs.isDir(directory) then
	fs.writeDir(directory)
end
local function physicalDirectory(path: string): string
	local result = process.exec("pwd", { "-P" }, { cwd = path })
	assert(result.ok, `[build-place] cannot resolve directory {path}: {result.stderr}`)
	return string.gsub(result.stdout, "%s+$", "")
end
directory = physicalDirectory(directory)
local authoredDirectory = physicalDirectory("places")
assert(
	directory ~= authoredDirectory and string.sub(directory, 1, #authoredDirectory + 1) ~= authoredDirectory .. "/",
	"[build-place] output directory must be outside places/"
)
for _, name in { "build.rbxl", "dist.rbxl", "manifest.json" } do
	assert(not fs.metadata(`{directory}/{name}`).exists, `[build-place] output already exists: {directory}/{name}`)
end

local function run(command: string, commandArgs: { string })
	local result = process.exec(command, commandArgs, { stdio = "inherit" })
	assert(result.ok, `[build-place] {command} failed with exit code {result.code}`)
end

run("rojo", { "build", project, "--output", `{directory}/build.rbxl` })
run("lune", {
	"run",
	"src/scripts/lune/merge-places.luau",
	project,
	basePath,
	`{directory}/build.rbxl`,
	`{directory}/dist.rbxl`,
})
local manifest = ReleaseArtifact.create(place, basePath, `{directory}/dist.rbxl`)
assert(manifest.baseSha256 == baseHash, "[build-place] authored base changed during the build")
fs.writeFile(`{directory}/manifest.json`, serde.encode("json", manifest, true) .. "\n")
print(`[build-place] {place} artifact {manifest.artifactSha256} from commit {manifest.commit}`)
