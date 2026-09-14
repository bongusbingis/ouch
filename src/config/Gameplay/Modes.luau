--!strict

-- Per-mode match rules. Holds the tunable, per-mode leaves only; the shared
-- results and intermission timings stay owned by Interface.PostMatch and
-- Gameplay.GameModes, and structural flavour a mode owns (its time-cap winner)
-- is composed in that mode's resolveRules(). Each mode reads its table by
-- reference so a live override lands on the next match.
--
-- ScoreTarget is the value at ReferencePlayers, not a constant: matchmaking
-- deliberately produces rosters from 2 to MatchCapacity, and a target that does
-- not move with the roster fails at one end or the other. A personal target
-- (FFA) gets slower to reach as the roster shrinks and there is nobody to hit;
-- a pooled team target (TDM) gets faster as the roster grows because every
-- teammate's eliminations count toward it. Shared.Game.Modes.ScoreTarget does
-- the scaling, clamped to the Min/Max leaves below, and MatchService snapshots
-- the result once per match so a mid-match join cannot move the goalposts.
-- Omit ReferencePlayers to opt a mode out of scaling entirely.

return {
	FFA = {
		MinPlayers = 2,
		ScoreTarget = 15,
		ReferencePlayers = 10,
		MinScoreTarget = 6,
		MaxScoreTarget = 25,
		TimeCapSeconds = 300,
		StartingSeconds = 3,
		RespawnSeconds = 1,
		SpawnInvulnSeconds = 1.5,
		PreserveDodgeballs = true,
	},
	TDM = {
		MinPlayers = 2,
		MinParties = 2,
		ScoreTarget = 40,
		ReferencePlayers = 10,
		MinScoreTarget = 10,
		MaxScoreTarget = 80,
		TimeCapSeconds = 360,
		StartingSeconds = 3,
		RespawnSeconds = 1,
		WaveRespawnSeconds = 4.5,
		SpawnInvulnSeconds = 1.5,
		PreserveDodgeballs = true,
	},
	Infection = {
		MinPlayers = 2,
		-- No elimination target at all: the mode ends when the last survivor is
		-- converted or the clock runs out, so there is nothing to scale.
		ScoreTarget = math.huge,
		TimeCapSeconds = 180,
		StartingSeconds = 3,
		RespawnSeconds = 3,
		SpawnInvulnSeconds = 1.5,
		PreserveDodgeballs = true,
	},
}
