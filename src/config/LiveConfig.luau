--!strict

-- Declares which Config leaves Roblox experience configs (ConfigService) may
-- override. A leaf that is not listed here can never be changed live, and every
-- listed leaf keeps its baked value whenever the config APIs are unavailable,
-- absent, or return a value that fails validation.
--
-- Key is both the Roblox config key and the path to the leaf:
-- "<Module>.<field>[.<field>...]". Modules in SimCritical are read by the
-- deterministic sim on both the predicting client and the authoritative server,
-- so their overrides are staged and adopted only at a match boundary.

export type Entry = {
	Key: string,
	Type: "number" | "boolean" | "string",
	Minimum: number?,
	Maximum: number?,
}

local GameModes = require(script.Parent:WaitForChild("Gameplay"):WaitForChild("GameModes"))

type Place = "arena" | "lobby"
local moduleDefinitions = {
	Combat = { path = { "Config", "Gameplay", "Combat" }, arena = true },
	AimAssist = { path = { "Config", "Gameplay", "AimAssist" }, arena = true },
	GameModes = { path = { "Config", "Gameplay", "GameModes" }, arena = true, lobby = true },
	MapFeatures = { path = { "Config", "Gameplay", "MapFeatures" }, arena = true },
	Modes = { path = { "Config", "Gameplay", "Modes" }, arena = true },
	Progression = { path = { "Config", "Progression", "Data" }, arena = true },
	Shop = { path = { "Config", "Economy", "Shop" }, arena = true, lobby = true },
	Crates = { path = { "Config", "Economy", "Crates" }, arena = true, lobby = true },
	Matchmaking = { path = { "Shared", "Matchmaking", "Config" }, lobby = true },
}

local entries: { Entry } = {
	{ Key = "Combat.Dodgeball.ThrowSpeed", Type = "number", Minimum = 10, Maximum = 1000 },
	{ Key = "Combat.Dodgeball.Gravity", Type = "number", Minimum = 0, Maximum = 500 },
	{ Key = "Combat.Dodgeball.ThrowCooldown", Type = "number", Minimum = 0, Maximum = 10 },
	{ Key = "Combat.Dodgeball.Charge.MaxSpeedScale", Type = "number", Minimum = 1, Maximum = 2 },
	{ Key = "Combat.Dodgeball.MaxFlightTime", Type = "number", Minimum = 0.1, Maximum = 30 },
	{ Key = "Combat.Dodgeball.WindupDuration", Type = "number", Minimum = 0, Maximum = 5 },
	{ Key = "Combat.Dodgeball.CatchDistance", Type = "number", Minimum = 0, Maximum = 50 },
	{ Key = "Combat.Dodgeball.CatchWindow", Type = "number", Minimum = 0, Maximum = 2 },
	{ Key = "Combat.Dodgeball.CatchCooldown", Type = "number", Minimum = 0, Maximum = 10 },
	{ Key = "Combat.Dodgeball.CatchConeDeg", Type = "number", Minimum = 0, Maximum = 360 },
	{ Key = "Combat.Dodgeball.KnockbackSpeed", Type = "number", Minimum = 0, Maximum = 500 },
	{ Key = "Combat.Dodgeball.HomingTurnRateDeg", Type = "number", Minimum = 0, Maximum = 360 },
	{ Key = "Combat.Dodgeball.HomingBreakAngleDeg", Type = "number", Minimum = 0, Maximum = 180 },
	{ Key = "Combat.Dodgeball.TargetSelectRange", Type = "number", Minimum = 0, Maximum = 1000 },
	{ Key = "Combat.Dodgeball.PickupRadius", Type = "number", Minimum = 0, Maximum = 50 },
	{ Key = "Combat.Dodgeball.BounceRestitution", Type = "number", Minimum = 0, Maximum = 1 },
	{ Key = "Combat.Dodgeball.SpawnCadence", Type = "number", Minimum = 0.1, Maximum = 120 },
	{ Key = "Combat.Hammer.Cooldown", Type = "number", Minimum = 0, Maximum = 10 },
	{ Key = "Combat.Hammer.ActiveDuration", Type = "number", Minimum = 0.01, Maximum = 5 },
	{ Key = "Combat.Hammer.MissRecovery", Type = "number", Minimum = 0, Maximum = 10 },
	{ Key = "Combat.Hammer.HitRecovery", Type = "number", Minimum = 0, Maximum = 10 },
	{ Key = "Combat.Hammer.MissStunDuration", Type = "number", Minimum = 0, Maximum = 10 },
	{ Key = "Combat.Hammer.Range", Type = "number", Minimum = 0, Maximum = 50 },
	{ Key = "Combat.Hammer.Width", Type = "number", Minimum = 0, Maximum = 50 },
	{ Key = "Combat.Hammer.Height", Type = "number", Minimum = 0, Maximum = 50 },
	{ Key = "Combat.Hammer.DashSpeed", Type = "number", Minimum = 0, Maximum = 300 },
	{ Key = "Combat.Hammer.KnockbackSpeed", Type = "number", Minimum = 0, Maximum = 500 },
	{ Key = "Combat.CharacterCapsule.Height", Type = "number", Minimum = 0.1, Maximum = 20 },
	{ Key = "Combat.CharacterCapsule.Radius", Type = "number", Minimum = 0.1, Maximum = 10 },

	{ Key = "AimAssist.Mouse.SelectionConeDeg", Type = "number", Minimum = 0, Maximum = 90 },
	{ Key = "AimAssist.Mouse.ValidationConeDeg", Type = "number", Minimum = 0, Maximum = 90 },
	{ Key = "AimAssist.Mouse.HomingTurnScale", Type = "number", Minimum = 0, Maximum = 5 },
	{ Key = "AimAssist.Mouse.MagnetismRadius", Type = "number", Minimum = 0, Maximum = 10 },
	{ Key = "AimAssist.Touch.SelectionConeDeg", Type = "number", Minimum = 0, Maximum = 90 },
	{ Key = "AimAssist.Touch.ValidationConeDeg", Type = "number", Minimum = 0, Maximum = 90 },
	{ Key = "AimAssist.Touch.HomingTurnScale", Type = "number", Minimum = 0, Maximum = 5 },
	{ Key = "AimAssist.Touch.MagnetismRadius", Type = "number", Minimum = 0, Maximum = 10 },
	{ Key = "AimAssist.Gamepad.SelectionConeDeg", Type = "number", Minimum = 0, Maximum = 90 },
	{ Key = "AimAssist.Gamepad.ValidationConeDeg", Type = "number", Minimum = 0, Maximum = 90 },
	{ Key = "AimAssist.Gamepad.HomingTurnScale", Type = "number", Minimum = 0, Maximum = 5 },
	{ Key = "AimAssist.Gamepad.MagnetismRadius", Type = "number", Minimum = 0, Maximum = 10 },

	{ Key = "GameModes.VoteDurationSeconds", Type = "number", Minimum = 3, Maximum = 60 },

	{ Key = "MapFeatures.JumpPad.BouncePower", Type = "number", Minimum = 0, Maximum = 500 },
	{ Key = "MapFeatures.JumpPad.FloatFactor", Type = "number", Minimum = 0, Maximum = 1 },
	{ Key = "MapFeatures.FoamPit.WalkSpeedScale", Type = "number", Minimum = 0.05, Maximum = 1 },

	-- Per-mode match rules. Each mode snapshots these at the match boundary, so an
	-- override lands on the next match, never mid-match. Infection.ScoreTarget is
	-- absent on purpose: it is math.huge (survival, not score, ends the mode).
	{ Key = "Modes.FFA.MinPlayers", Type = "number", Minimum = 2, Maximum = 100 },
	{ Key = "Modes.FFA.ScoreTarget", Type = "number", Minimum = 1, Maximum = 500 },
	{ Key = "Modes.FFA.TimeCapSeconds", Type = "number", Minimum = 30, Maximum = 1800 },
	{ Key = "Modes.FFA.StartingSeconds", Type = "number", Minimum = 0, Maximum = 30 },
	{ Key = "Modes.FFA.RespawnSeconds", Type = "number", Minimum = 0, Maximum = 30 },
	{ Key = "Modes.FFA.SpawnInvulnSeconds", Type = "number", Minimum = 0, Maximum = 10 },
	{ Key = "Modes.TDM.MinPlayers", Type = "number", Minimum = 2, Maximum = 100 },
	{ Key = "Modes.TDM.ScoreTarget", Type = "number", Minimum = 1, Maximum = 500 },
	{ Key = "Modes.TDM.TimeCapSeconds", Type = "number", Minimum = 30, Maximum = 1800 },
	{ Key = "Modes.TDM.StartingSeconds", Type = "number", Minimum = 0, Maximum = 30 },
	{ Key = "Modes.TDM.RespawnSeconds", Type = "number", Minimum = 0, Maximum = 30 },
	{ Key = "Modes.TDM.WaveRespawnSeconds", Type = "number", Minimum = 0, Maximum = 30 },
	{ Key = "Modes.TDM.SpawnInvulnSeconds", Type = "number", Minimum = 0, Maximum = 10 },
	{ Key = "Modes.Infection.MinPlayers", Type = "number", Minimum = 2, Maximum = 100 },
	{ Key = "Modes.Infection.TimeCapSeconds", Type = "number", Minimum = 30, Maximum = 1800 },
	{ Key = "Modes.Infection.StartingSeconds", Type = "number", Minimum = 0, Maximum = 30 },
	{ Key = "Modes.Infection.RespawnSeconds", Type = "number", Minimum = 0, Maximum = 30 },
	{ Key = "Modes.Infection.SpawnInvulnSeconds", Type = "number", Minimum = 0, Maximum = 10 },

	-- Match award rates: the faucet. These are the dominant term in earned Bonks/h
	-- and season XP/h, so they are the first thing to reach for when launch pacing
	-- is wrong in either direction -- too stingy and progression stalls, too generous
	-- and nothing is worth buying. ProgressionService reads these leaves per award,
	-- so an override lands on the next award without a restart.
	--
	-- MatchComplete and Win keep a minimum of 1: finishing a match must always pay
	-- something, or a player can complete the loop and see nothing happen. Elim and
	-- Catch may go to 0, which turns an action reward off without disabling the action.
	--
	-- Daily, quest and season grants are deliberately absent. Their reward tables are
	-- keyed by number (day index, definition index) and ConfigOverrides addresses
	-- paths by string segment only, so they are not reachable without changing that
	-- shared pure module. They are also the smaller term -- 1,625 Bonks per weekly
	-- daily cycle against 600-2,800 earned per hour of play.
	{ Key = "Progression.ProgressionXP.MatchComplete", Type = "number", Minimum = 1, Maximum = 200 },
	{ Key = "Progression.ProgressionXP.Win", Type = "number", Minimum = 1, Maximum = 500 },
	{ Key = "Progression.ProgressionXP.Elim", Type = "number", Minimum = 0, Maximum = 100 },
	{ Key = "Progression.ProgressionXP.Catch", Type = "number", Minimum = 0, Maximum = 100 },
	{ Key = "Progression.ProgressionBonks.MatchComplete", Type = "number", Minimum = 1, Maximum = 400 },
	{ Key = "Progression.ProgressionBonks.Win", Type = "number", Minimum = 1, Maximum = 500 },
	{ Key = "Progression.ProgressionBonks.Elim", Type = "number", Minimum = 0, Maximum = 100 },
	{ Key = "Progression.ProgressionBonks.Catch", Type = "number", Minimum = 0, Maximum = 100 },

	-- Shop A/B levers, tested at server granularity: Roblox hands different servers
	-- different snapshots (GetConfigAsync), so a whole server runs one variant and
	-- VariantId labels the result on every analytics row. (Per-player splits use the
	-- separate GetConfigForPlayerAsync path in PlayerAssist, not this.) The bounds
	-- are not cosmetic: every value in range keeps CrateConfig.spec's
	-- economic invariants (a crate open cheaper than the cheapest direct buy;
	-- direct buy beats the expected cost of chasing an item in a crate). Rarity
	-- DirectBonks/DupeBonks are absent on purpose -- a live override there could
	-- make crates strictly worse value than buying outright.
	{ Key = "Shop.VariantId", Type = "string" },
	{ Key = "Shop.Rotation.RotationSeconds", Type = "number", Minimum = 3600, Maximum = 2592000 },
	{ Key = "Shop.Featured.RotationSeconds", Type = "number", Minimum = 3600, Maximum = 2592000 },
	{ Key = "Shop.Featured.DiscountPercent", Type = "number", Minimum = 0, Maximum = 20 },
	{ Key = "Shop.Bundle.RotationSeconds", Type = "number", Minimum = 3600, Maximum = 2592000 },
	{ Key = "Crates.DodgeballCrate.BonksPrice", Type = "number", Minimum = 500, Maximum = 900 },
	{ Key = "Crates.HammerCrate.BonksPrice", Type = "number", Minimum = 500, Maximum = 900 },
	-- Floored below the weapon crates: the Effects pool is roughly a third of
	-- theirs, so it saturates into duplicates sooner and is priced to match.
	{ Key = "Crates.EffectsCrate.BonksPrice", Type = "number", Minimum = 300, Maximum = 900 },

	{ Key = "Matchmaking.PartyMaxPlayers", Type = "number", Minimum = 1, Maximum = 8 },
	{ Key = "Matchmaking.MatchTargetPlayers", Type = "number", Minimum = 1, Maximum = GameModes.MatchCapacity },
	{ Key = "Matchmaking.QueueCandidateLimit", Type = "number", Minimum = 1, Maximum = 500 },
	{ Key = "Matchmaking.WorkerPollInterval", Type = "number", Minimum = 0.5, Maximum = 30 },
}

local function moduleNames(place: Place?): { string }
	local names = {}
	local seen: { [string]: boolean } = {}
	for _, entry in entries do
		local name = string.match(entry.Key, "^([^.]+)%.")
		assert(name, `[LiveConfig] Invalid key: {entry.Key}`)
		local definition = moduleDefinitions[name]
		assert(definition, `[LiveConfig] Missing module definition: {name}`)
		if not seen[name] and (place == nil or definition[place]) then
			seen[name] = true
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

local function loadModules(place: Place): { [string]: any }
	local modules = {}
	for _, name in moduleNames(place) do
		local node = script.Parent.Parent
		for _, segment in moduleDefinitions[name].path do
			node = node:WaitForChild(segment)
		end
		modules[name] = require(node)
	end
	return modules
end

return table.freeze({
	Entries = table.freeze(entries),
	moduleNames = moduleNames,
	loadModules = loadModules,
	SimCritical = table.freeze({ Combat = true, AimAssist = true }),
	StateFolderName = "ConfigState",
	RevisionAttribute = "revision",
	RetrySeconds = 30,
	ResyncSeconds = 300,
})
