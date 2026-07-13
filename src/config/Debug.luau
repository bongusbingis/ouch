--!strict

-- Temporary diagnostics; all default off for real playtests.

return {
	-- Master gate for client-only debug geometry. The visualizer also requires
	-- RunService:IsStudio(), so these never render in normal live servers.
	StudioVisuals = false,
	VisualUpdateHz = 12,

	-- Console tracing. CollisionTrace is intentionally separate because sphere
	-- sweep hits can print hundreds of lines per second.
	CombatTrace = false,
	CollisionTrace = false,

	AimAssistCones = true,
	AimAssistTargetRange = true,
	ThrowOriginMaxOffset = true,
	PickupRadius = true,
	RecallRange = true,
	PhaseLabels = true,
	Trajectory = true,
	CollisionRadius = true,
	SelectedTarget = true,
	BounceNormals = true,
	PredictionGhost = true,
}
