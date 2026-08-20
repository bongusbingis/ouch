--!strict

-- Per-player assist tuning. Separate from LiveConfig on purpose: LiveConfig
-- installs one global snapshot into the shared config tables, which cannot
-- express "this player is in the B bucket". These leaves are resolved per
-- player through ConfigService:GetConfigForPlayerAsync, so a Roblox experience
-- config condition can hold half the population at a different strength.
--
-- Every entry is a plain scalar with a declared type and range, validated by the
-- same pure rules LiveConfig uses. Defaults here are what a player gets when no
-- override applies, when the config service is unavailable, or when a value
-- fails validation.
--
-- Convention: <Feature>Enabled is a kill switch, <Feature>Strength is a 0-1
-- scalar, and Strength 0 must behave exactly like Enabled = false.

export type Entry = {
	Key: string,
	Type: "number" | "boolean",
	Default: any,
	Minimum: number?,
	Maximum: number?,
}

local entries: { Entry } = {
	-- Existing cone snap: the sim picking the best target inside the selection
	-- cone. Off for mouse, which never needed it.
	{ Key = "ConeSnapEnabled", Type = "boolean", Default = true },
	{ Key = "ConeSnapStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },

	-- Biases the throw toward where a moving target will be, not where it is.
	{ Key = "LeadEnabled", Type = "boolean", Default = true },
	{ Key = "LeadStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },

	-- Camera pull that follows a target's angular movement, and drag damping
	-- while over one. Separate scalars: they are different sensations and want
	-- to be tuned apart.
	{ Key = "AdhesionEnabled", Type = "boolean", Default = true },
	{ Key = "AdhesionStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },
	{ Key = "FrictionEnabled", Type = "boolean", Default = true },
	{ Key = "FrictionStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },

	-- Melee, Phase 3.
	{ Key = "AutoFaceEnabled", Type = "boolean", Default = true },
	{ Key = "AutoFaceStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },
	{ Key = "LungeEnabled", Type = "boolean", Default = true },
	{ Key = "LungeStrength", Type = "number", Default = 1, Minimum = 0, Maximum = 1 },
}

-- Per-device multipliers applied on top of the resolved strength. This is the
-- gate that keeps mouse and keyboard untouched: a 0 here means the assist is
-- inert for that device no matter what the player's config says.
--
-- Gamepad gets adhesion and friction at a lower strength than touch: a stick
-- has analogue precision a thumb dragging on glass does not, so it needs less.
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
