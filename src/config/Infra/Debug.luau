--!strict

-- Temporary diagnostics; all default off for real playtests.

return {
	StudioVisuals = false,
	VisualUpdateHz = 12,

	CombatTrace = false,
	CollisionTrace = false,

	AutoGrantAllItemsInStudio = false,
	AnalyticsVerbose = false,

	AimAssistCones = true,
	AimAssistTargetRange = true,
	ThrowOriginMaxOffset = true,
	PickupRadius = true,
	Trajectory = true,
	CollisionRadius = true,
	SelectedTarget = true,
	BounceNormals = true,
	PredictionGhost = true,

	-- Procedural pose layer. All off by default; turn on with StudioVisuals to
	-- tune the values in Config.ThrowPose against what you can see.
	-- Aim direction from the shoulder, and the arm IK target and elbow pole the
	-- solver is actually using.
	PoseAimVector = true,
	PoseIKTarget = true,
	PoseElbowPole = true,
	-- The authoritative launch point, which should stay rock steady relative to
	-- the character while the throw animation plays. If this drifts with the
	-- hand, the release socket is on an animated part.
	PoseReleaseOrigin = true,
	-- The wind-up spot the hand pauses at, drawn whether or not it is currently
	-- the active target, so it can be positioned without holding charge.
	PoseWindupAnchor = true,
	-- Mirrors Config.ThrowPose into Workspace.ThrowPoseTuning as Value objects
	-- so the pose can be dialled in during a test session. Edits apply on the
	-- next frame and are NOT saved -- copy what you like back into the config.
	-- Needs StudioVisuals on as well.
	ThrowPoseTuner = true,
	-- Prints state, charge and IK weight. Text rather than geometry, so it is
	-- separate from the drawing flags above.
	PoseStateReadout = true,

	CosmeticVFXGallery = false,

	-- Studio-only lobby combat/cosmetics test session. Press Q while playtesting
	-- the lobby to spawn onto the baseplate with stationary respawning dummies,
	-- both weapons, and the arena overlay menu, so equipped cosmetics can be
	-- iterated on without entering the arena. Gated to Studio and never runs live.
	LobbyCombatTest = true,

	-- Tap-corner gesture that lets a dev/tester end the active match solo and
	-- declare themselves the winner, for exercising the post-match flow
	-- without a second player. Gated server-side by DevSoloPlay.canUse.
	DevMatchSkip = {
		Enabled = true,
		CornerScale = 0.15,
		TapCount = 10,
		TapWindowSeconds = 1.25,
	},

	-- Adds a handful of non-persisted example settings (both toggle variants,
	-- every slider mode, a disabled row, and a Lobby-only row) to the real
	-- Settings menu so every control mode can be exercised without real
	-- settings existing yet. Never written to a player's profile.
	SettingsShowExamples = true,
}
