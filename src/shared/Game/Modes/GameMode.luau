-- Description: The interface every game mode implements, pairing the pure match rules readable by the sim, tests, and UI with the server-only lifecycle hooks.

--!strict

export type MatchRules = {
	MinPlayers: number,
	MinParties: number?,
	-- ScoreTarget as resolved for the match in play. Before MatchService
	-- snapshots it this is the value at ReferencePlayers; see Config.Gameplay.Modes.
	ScoreTarget: number,
	ReferencePlayers: number?,
	MinScoreTarget: number?,
	MaxScoreTarget: number?,
	TimeCapSeconds: number,
	ResultsSeconds: number,
	IntermissionSeconds: number,
	StartingSeconds: number,
	RespawnSeconds: number,
	WaveRespawnSeconds: number?,
	SpawnInvulnSeconds: number,
	TimeCapWinnerId: string?,
	PreserveDodgeballs: boolean,
}

export type ScoreScope = "Player" | "Team"

export type ModeContext = {
	balls: {
		grantHeldBall: (player: Player) -> boolean,
		clearAll: () -> (),
	},
	getPlayers: () -> { Player },
	getPlayerTeam: (player: Player) -> string?,
	getPlayerById: (id: string) -> Player?,
	setPlayerTeam: (player: Player, teamId: string?) -> (),
	finishMatch: (winnerId: string?, reason: string) -> (),
}

-- A mode that defines teamScore owns its scoreboard outright: MatchService stops
-- counting eliminations into the score and recomputes every team from this
-- instead, whenever the roster or anyone's team changes. That is what lets a
-- mode whose score is a headcount rather than a kill count -- Infection -- show
-- a number that means something, without every other mode paying for it.
export type TeamScore = (ctx: ModeContext, teamId: string) -> number

-- statLabels names the per-player stats a mode reports on the results screen
-- in place of the combat trio; MatchService carries the values the mode's
-- server owner stamps through setContestantStats.
export type StatLabel = { id: string, label: string }

export type GameMode = {
	id: string,
	displayName: string,
	rules: MatchRules,
	resolveRules: () -> MatchRules,
	scoreScope: ScoreScope?,
	teams: { string }?,
	teamScore: TeamScore?,
	statLabels: { StatLabel }?,

	onMatchStart: (ctx: ModeContext) -> (),
	onPlayerSpawned: (ctx: ModeContext, player: Player, isFirstSpawn: boolean) -> (),
	onElim: (ctx: ModeContext, sourceId: string?, targetId: string?) -> (),
	-- Optional. MatchService calls this after it recomputes the scoreboard while
	-- a match is starting or active, i.e. whenever the roster or anyone's side
	-- changed, so a mode can end or repair a round that a player leaving left
	-- unwinnable. It must not assume an elimination happened.
	onRosterChanged: ((ctx: ModeContext) -> ())?,
	onMatchEnd: (ctx: ModeContext) -> (),
}

return {}
