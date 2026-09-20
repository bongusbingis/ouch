--!strict

-- Aim-assist schema for the per-player AB engine (PlayerConfigService): unlike
-- LiveConfig's one global snapshot, these leaves resolve per player through
-- ConfigService:GetConfigForPlayerAsync, so an experience-config condition can
-- hold half the population at a different strength. Defaults apply when no
-- override does or the service is initially unavailable. A malformed present
-- value rejects the entire candidate and retains the last accepted projection.
--
-- Convention: <Feature>Enabled is a kill switch, <Feature>Strength a 0-1 scalar,
-- and Strength 0 behaves exactly like Enabled = false.

export type Entry = {
	Key: string,
	Type: "number" | "boolean",
	Default: any,
	Minimum: number?,
	Maximum: number?,
}

local entries: { Entry } = {
	-- Cone snap: the sim picks the best target inside the selection cone.
	{ Key = "ConeSnapEnabled", Type = "boolean", Default = true },
	{ Key = "ConeSnapStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },

	-- Biases the throw toward where a moving target will be, not where it is.
	{ Key = "LeadEnabled", Type = "boolean", Default = true },
	{ Key = "LeadStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },

	-- Adhesion is camera pull toward a target's movement; friction damps drag while
	-- over one. Separate scalars: different sensations, tuned apart.
	{ Key = "AdhesionEnabled", Type = "boolean", Default = true },
	{ Key = "AdhesionStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },
	{ Key = "FrictionEnabled", Type = "boolean", Default = true },
	{ Key = "FrictionStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },

	-- Melee assists.
	{ Key = "AutoFaceEnabled", Type = "boolean", Default = true },
	{ Key = "AutoFaceStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },
	{ Key = "LungeEnabled", Type = "boolean", Default = true },
	{ Key = "LungeStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },
}

-- Per-device multipliers on the resolved strength: a 0 keeps the assist inert for
-- that device regardless of config. Gamepad gets less than touch (a stick has
-- precision a thumb on glass does not).
local deviceScale = {
	Mouse = {
		ConeSnap = 1,
		Lead = 0,
		Adhesion = 0,
		Friction = 0,
		AutoFace = 0,
		Lunge = 0,
	},
	Touch = {
		ConeSnap = 1,
		Lead = 1,
		Adhesion = 1,
		Friction = 1,
		AutoFace = 1,
		Lunge = 1,
	},
	Gamepad = {
		ConeSnap = 1,
		Lead = 0.5,
		Adhesion = 0.6,
		Friction = 0.6,
		AutoFace = 0.5,
		Lunge = 0.5,
	},
}

-- Feature names, derived from the Strength entries so the list can never drift
-- from the entries above.
local features: { string } = {}
for _, entry in entries do
	local name = string.match(entry.Key, "^(.+)Strength$")
	if name then
		table.insert(features, name)
	end
end

local defaults: { [string]: any } = {}
for _, entry in entries do
	defaults[entry.Key] = entry.Default
end

return table.freeze({
	Entries = table.freeze(entries),
	Defaults = table.freeze(defaults),
	Features = table.freeze(features),
	DeviceScale = table.freeze(deviceScale),
	-- Folder created under each Player carrying that player's resolved values.
	FolderName = "AssistConfig",
	RevisionAttribute = "revision",
	-- Retry cadence when the config service is unavailable for a player.
	RetrySeconds = 30,
})
