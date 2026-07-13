--!strict

-- Temporary diagnostics; all default off for real playtests.

return {
	-- Prints combat commands, sim events, and static sweep hits (with the part
	-- that was hit) on both client and server, tagged [C]/[S].
	CombatTrace = true,
	PhaseLabels = false,
	Trajectory = false,
	CollisionRadius = false,
	SelectedTarget = false,
	BounceNormals = false,
	PredictionGhost = false,
}
