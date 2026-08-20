--!strict

-- The interface every game mode implements. Modes are shared modules so the
-- pure rules are readable by MatchSim, tests, and client UI; the hooks are
-- invoked only on the server with a ModeContext of levers.

export type MatchRules = {
	MinPlayers: number,
	ScoreTarget: number,
	TimeCapSeconds: number,
	ResultsSeconds: number,
	IntermissionSeconds: number,
	StartingSeconds: number, -- arena countdown before combat inputs become active
	RespawnSeconds: number,
	-- When set, deaths respawn in synchronized waves on this cadence instead
	-- of individually after RespawnSeconds (GDD §4.2 TDM push/retreat rhythm).
	WaveRespawnSeconds: number?,
	SpawnInvulnSeconds: number,
	-- Who wins when the clock runs out, for modes where surviving to the cap is
	-- itself the win. Unset means the leading score takes it.
	TimeCapWinnerId: string?,
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
	-- Modes that move players between sides mid-match (infection) rather than
	-- being assigned once at the start.
	setPlayerTeam: (player: Player, teamId: string?) -> (),
	-- Ends the match now, naming the winner outright for outcomes that are not
	-- a score race.
	finishMatch: (winnerId: string?, reason: string) -> (),
}

export type GameMode = {
	id: string,
	displayName: string,
	rules: MatchRules,
	scoreScope: ScoreScope?,
	teams: { string }?,

	onMatchStart: (ctx: ModeContext) -> (),
	-- isFirstSpawn is true the first time a player spawns in the current
	-- match (including late joiners), false on respawns after deaths.
	onPlayerSpawned: (ctx: ModeContext, player: Player, isFirstSpawn: boolean) -> (),
	onElim: (ctx: ModeContext, sourceId: string?, targetId: string?) -> (),
	onMatchEnd: (ctx: ModeContext) -> (),
}

return {}
