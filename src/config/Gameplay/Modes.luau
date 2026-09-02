--!strict

-- Per-mode match rules. Holds the tunable, per-mode leaves only; the shared
-- results and intermission timings stay owned by Interface.PostMatch and
-- Gameplay.GameModes, and structural flavour a mode owns (its time-cap winner)
-- is composed in that mode's resolveRules(). Each mode reads its table by
-- reference so a live override lands on the next match.

return {
	FFA = {
		MinPlayers = 1,
		ScoreTarget = 15,
		TimeCapSeconds = 300,
		StartingSeconds = 3,
		RespawnSeconds = 1,
		SpawnInvulnSeconds = 1.5,
		PreserveDodgeballs = true,
	},
	TDM = {
		MinPlayers = 1,
		ScoreTarget = 40,
		TimeCapSeconds = 360,
		StartingSeconds = 3,
		RespawnSeconds = 1,
		WaveRespawnSeconds = 4.5,
		SpawnInvulnSeconds = 1.5,
		PreserveDodgeballs = true,
	},
	Infection = {
		MinPlayers = 2,
		ScoreTarget = math.huge,
		TimeCapSeconds = 180,
		StartingSeconds = 3,
		RespawnSeconds = 3,
		SpawnInvulnSeconds = 1.5,
		PreserveDodgeballs = true,
	},
}
