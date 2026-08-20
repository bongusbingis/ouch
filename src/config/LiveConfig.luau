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

	{ Key = "Matchmaking.PartyMaxPlayers", Type = "number", Minimum = 1, Maximum = 8 },
	{ Key = "Matchmaking.MatchTargetPlayers", Type = "number", Minimum = 1, Maximum = 100 },
	{ Key = "Matchmaking.QueueCandidateLimit", Type = "number", Minimum = 1, Maximum = 500 },
	{ Key = "Matchmaking.WorkerPollInterval", Type = "number", Minimum = 0.5, Maximum = 30 },
	{ Key = "Matchmaking.TeleportRetryAttempts", Type = "number", Minimum = 1, Maximum = 10 },
	{ Key = "Matchmaking.TeleportFloodedDelay", Type = "number", Minimum = 1, Maximum = 120 },
}

return table.freeze({
	Entries = table.freeze(entries),
	SimCritical = table.freeze({ Combat = true, AimAssist = true }),
	StateFolderName = "ConfigState",
	RevisionAttribute = "revision",
	RetrySeconds = 30,
	ResyncSeconds = 300,
})
