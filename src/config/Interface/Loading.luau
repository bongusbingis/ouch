--!strict

return {
	ArenaWaitSeconds = 20,
	CriticalPreloadTimeoutSeconds = 12,
	CriticalInitializationTimeoutSeconds = 30,
	ArenaReadyRetrySeconds = 1,
	TeleportPresentationFallbackSeconds = 5,
	TeleportRetryAttempts = 5,
	TeleportRetryDelaySeconds = 1,
	TeleportFloodedDelaySeconds = 15,
	TeleportRecoveryNoticeSeconds = 30,
	LateVoteMinimumSeconds = 5,
	LateVoteMaximumExtensionSeconds = 10,
	TipDelaySeconds = 2.5,
	TipIntervalSeconds = 5,
	FadeSeconds = 0.2,
	Tips = {
		"HOLD THROW TO CHARGE A FASTER DODGEBALL.",
		"CATCH AN INCOMING DODGEBALL TO STEAL IT.",
		"A MISSED HAMMER SWING LEAVES YOU OPEN.",
		"KEEP MOVING - POSITIONING WINS FIGHTS.",
	},
	CriticalContentIds = {
		"rbxassetid://10051822476",
		"rbxassetid://136021539696619",
		"rbxassetid://94748581468730",
		"rbxassetid://124751224634629",
		"rbxassetid://78333957912633",
		"rbxassetid://72382658",
	},
	CriticalPreloadTag = "CriticalPreload",
}
