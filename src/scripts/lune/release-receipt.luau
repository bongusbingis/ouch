-- Binds cloud test evidence to the exact artifact and Roblox target allowed to publish.
--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Artifact = require("./release-artifact")

local Receipt = {}

export type Evidence = {
	schemaVersion: number,
	universeId: string,
	placeId: string,
	artifactSha256: string,
	savedVersionId: string,
	state: string,
	taskPath: string?,
	publishedVersionId: string?,
}

function Receipt.write(path: string, evidence: Evidence)
	fs.writeFile(path, serde.encode("json", evidence, true) .. "\n")
end

function Receipt.verify(placeFile: string, universeId: string, placeId: string): Evidence
	local evidence = serde.decode("json", fs.readFile(placeFile .. ".tested.json"))
	assert(type(evidence) == "table" and evidence.schemaVersion == 1, "[release] invalid test evidence schema")
	assert(evidence.state == "COMPLETE", "[release] artifact has no completed cloud test evidence")
	assert(evidence.universeId == universeId and evidence.placeId == placeId, "[release] test target does not match")
	assert(evidence.artifactSha256 == Artifact.hashFile(placeFile), "[release] artifact changed since cloud tests")
	assert(
		type(evidence.savedVersionId) == "string" and string.match(evidence.savedVersionId, "^[1-9]%d*$"),
		"[release] missing saved version ID"
	)
	assert(
		type(evidence.taskPath) == "string"
			and string.sub(evidence.taskPath, 1, #`universes/{universeId}/places/{placeId}/`)
				== `universes/{universeId}/places/{placeId}/`,
		"[release] missing or mismatched cloud task path"
	)
	return evidence :: Evidence
end

return Receipt
