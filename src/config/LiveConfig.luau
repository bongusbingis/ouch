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

	-- Shop A/B levers. Roblox hands different servers different config snapshots,
	-- so varying these is the experiment; VariantId is what makes the result
	-- readable, because it is stamped on every shop analytics row.
	--
	-- The bounds are not cosmetic. CrateConfig.spec pins two economic invariants
	-- -- a crate open must cost less than the cheapest direct buy, and direct buy
	-- must beat the expected cost of chasing an item in a crate -- and those are
	-- checked against baked values only. Every combination inside these ranges
	-- still satisfies both at the price actually charged, discount included.
	-- Rarity DirectBonks/DupeBonks are deliberately absent: they sit on the other
	-- side of both invariants, and a live override there could silently make
	-- crates strictly worse value than buying outright.
	{ Key = "Shop.VariantId", Type = "string" },
	{ Key = "Shop.Rotation.OfferCount", Type = "number", Minimum = 1, Maximum = 8 },
	{ Key = "Shop.Rotation.RotationSeconds", Type = "number", Minimum = 3600, Maximum = 2592000 },
	{ Key = "Shop.Featured.RotationSeconds", Type = "number", Minimum = 3600, Maximum = 2592000 },
	{ Key = "Shop.Featured.DiscountPercent", Type = "number", Minimum = 0, Maximum = 20 },
	{ Key = "Shop.Bundle.RotationSeconds", Type = "number", Minimum = 3600, Maximum = 2592000 },
	{ Key = "Crates.DodgeballCrate.BonksPrice", Type = "number", Minimum = 500, Maximum = 1000 },
	{ Key = "Crates.HammerCrate.BonksPrice", Type = "number", Minimum = 500, Maximum = 1000 },
	{ Key = "Crates.EffectsCrate.BonksPrice", Type = "number", Minimum = 500, Maximum = 1000 },

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
