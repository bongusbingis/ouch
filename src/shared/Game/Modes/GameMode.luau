-- Name: GameMode.luau
-- Author: Jack C.
-- Description: The interface every game mode implements, pairing the pure match rules readable by the sim, tests, and UI with the server-only lifecycle hooks.
-- Created: 2026-07-13

--!strict

export type MatchRules = {
	MinPlayers: number,
	ScoreTarget: number,
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

export type GameMode = {
	id: string,
	displayName: string,
	rules: MatchRules,
	scoreScope: ScoreScope?,
	teams: { string }?,

	onMatchStart: (ctx: ModeContext) -> (),
	onPlayerSpawned: (ctx: ModeContext, player: Player, isFirstSpawn: boolean) -> (),
	onElim: (ctx: ModeContext, sourceId: string?, targetId: string?) -> (),
	onMatchEnd: (ctx: ModeContext) -> (),
}

return {}
