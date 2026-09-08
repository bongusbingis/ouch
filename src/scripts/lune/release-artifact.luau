-- Records build provenance and verifies the exact merged bytes handed to deployment.
--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

export type Manifest = {
	schemaVersion: number,
	place: string,
	commit: string,
	project: string,
	basePath: string,
	baseSha256: string,
	artifactSha256: string,
	wallyLockSha256: string,
}

local ReleaseArtifact = {}

local function validate(manifest: any): Manifest
	assert(type(manifest) == "table", "[release-artifact] manifest must be an object")
	assert(manifest.schemaVersion == 1, "[release-artifact] unsupported manifest schema")
	assert(manifest.place == "arena" or manifest.place == "lobby", "[release-artifact] invalid place")
	assert(manifest.project == `{manifest.place}.project.json`, "[release-artifact] project does not match place")
	assert(
		type(manifest.commit) == "string"
			and (#manifest.commit == 40 or #manifest.commit == 64)
			and string.match(manifest.commit, "^[0-9a-f]+$") ~= nil,
		"[release-artifact] invalid commit"
	)
	assert(
		type(manifest.basePath) == "string"
			and string.match(manifest.basePath, `^places/{manifest.place}/[^/]+%.rbxl$`) ~= nil,
		"[release-artifact] base path does not match place"
	)
	for _, field in { "baseSha256", "artifactSha256", "wallyLockSha256" } do
		local value = manifest[field]
		assert(
			type(value) == "string" and #value == 64 and string.match(value, "^[0-9a-f]+$") ~= nil,
			`[release-artifact] invalid {field}`
		)
	end
	return manifest :: Manifest
end

function ReleaseArtifact.hashFile(path: string): string
	assert(fs.isFile(path), `[release-artifact] missing file: {path}`)
	return serde.hash("sha256", fs.readFile(path))
end

function ReleaseArtifact.create(place: string, basePath: string, artifactPath: string): Manifest
	local revision = process.exec("git", { "rev-parse", "HEAD" })
	assert(revision.ok, `[release-artifact] cannot read commit: {revision.stderr}`)
	return validate({
		schemaVersion = 1,
		place = place,
		commit = string.gsub(revision.stdout, "%s+$", ""),
		project = `{place}.project.json`,
		basePath = basePath,
		baseSha256 = ReleaseArtifact.hashFile(basePath),
		artifactSha256 = ReleaseArtifact.hashFile(artifactPath),
		wallyLockSha256 = ReleaseArtifact.hashFile("wally.lock"),
	})
end

function ReleaseArtifact.verify(directory: string, expectedPlace: string?, expectedCommit: string?): Manifest
	local path = `{directory}/manifest.json`
	assert(fs.isFile(path), `[release-artifact] missing manifest: {path}`)
	local manifest = validate(serde.decode("json", fs.readFile(path)))
	assert(expectedPlace == nil or manifest.place == expectedPlace, "[release-artifact] unexpected place")
	assert(expectedCommit == nil or manifest.commit == expectedCommit, "[release-artifact] unexpected commit")
	assert(
		ReleaseArtifact.hashFile(`{directory}/dist.rbxl`) == manifest.artifactSha256,
		"[release-artifact] merged artifact hash mismatch"
	)
	assert(
		ReleaseArtifact.hashFile("wally.lock") == manifest.wallyLockSha256,
		"[release-artifact] dependency lock hash mismatch"
	)
	return manifest
end

return ReleaseArtifact
