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
	{ Key = "Shop.Rotation.OfferCount", Type = "number", Minimum = 1, Maximum = 8 },
	{ Key = "Shop.Rotation.RotationSeconds", Type = "number", Minimum = 3600, Maximum = 2592000 },
	{ Key = "Shop.Featured.RotationSeconds", Type = "number", Minimum = 3600, Maximum = 2592000 },
	{ Key = "Shop.Featured.DiscountPercent", Type = "number", Minimum = 0, Maximum = 20 },
	{ Key = "Shop.Bundle.RotationSeconds", Type = "number", Minimum = 3600, Maximum = 2592000 },
	{ Key = "Crates.DodgeballCrate.BonksPrice", Type = "number", Minimum = 500, Maximum = 900 },
	{ Key = "Crates.HammerCrate.BonksPrice", Type = "number", Minimum = 500, Maximum = 900 },
	{ Key = "Crates.EffectsCrate.BonksPrice", Type = "number", Minimum = 500, Maximum = 900 },

	{ Key = "Matchmaking.PartyMaxPlayers", Type = "number", Minimum = 1, Maximum = 8 },
	{ Key = "Matchmaking.MatchTargetPlayers", Type = "number", Minimum = 1, Maximum = 100 },
	{ Key = "Matchmaking.QueueCandidateLimit", Type = "number", Minimum = 1, Maximum = 500 },
	{ Key = "Matchmaking.WorkerPollInterval", Type = "number", Minimum = 0.5, Maximum = 30 },
}

return table.freeze({
	Entries = table.freeze(entries),
	SimCritical = table.freeze({ Combat = true, AimAssist = true }),
	StateFolderName = "ConfigState",
	RevisionAttribute = "revision",
	RetrySeconds = 30,
	ResyncSeconds = 300,
})
