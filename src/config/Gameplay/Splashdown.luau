--!strict

-- Splashdown race tunables. Courses carry their own cap and close window
-- because difficulty differs: a spiral climb with rising lava needs longer than
-- a straight sprint. Everything the five courses share lives at the top level.
-- Units are studs and seconds.
return {
	RoundCount = 3,
	IntroSeconds = 5,
	CountdownSeconds = 3,
	RoundResultsSeconds = 6,
	-- Between the splash and standing on the checkpoint pad again.
	RespawnDelaySeconds = 0.8,
	HazardVerticalPadding = 2,
	-- A root this far below the course floor counts as lost to the void.
	VoidDepthStuds = 80,
	-- Checkpoint and finish triggers are matched on the root, with this much
	-- vertical slack so a jump through an arch still counts.
	TriggerVerticalPadding = 4,
	-- Points for first place equal the queue capacity, so a full lobby's winner
	-- always scores the same number; last place scores 1 and a DNF scores 0.
	PointsForFirst = 30,
	-- A DNF is charged the round cap in the cumulative-time tiebreak.
	CourseOrder = { "WhirlPool", "DiscJockey", "KnockKnock", "BumperBay", "SummitSplash" },
	Courses = {
		WhirlPool = {
			DisplayName = "WHIRL POOL",
			Difficulty = 1,
			ParSeconds = 60,
			CapSeconds = 120,
			CloseWindowSeconds = 30,
		},
		DiscJockey = {
			DisplayName = "DISC JOCKEY",
			Difficulty = 2,
			ParSeconds = 70,
			CapSeconds = 135,
			CloseWindowSeconds = 30,
		},
		KnockKnock = {
			DisplayName = "KNOCK KNOCK",
			Difficulty = 2,
			ParSeconds = 70,
			CapSeconds = 135,
			CloseWindowSeconds = 30,
			Doors = { PerRow = 5, BreakablePerRow = 2 },
		},
		BumperBay = {
			DisplayName = "BUMPER BAY",
			Difficulty = 3,
			ParSeconds = 85,
			CapSeconds = 150,
			CloseWindowSeconds = 35,
		},
		SummitSplash = {
			DisplayName = "SUMMIT SPLASH",
			Difficulty = 3,
			ParSeconds = 95,
			CapSeconds = 180,
			CloseWindowSeconds = 40,
			LavaRise = { Studs = 60, DelaySeconds = 20, Seconds = 140 },
		},
	},
	-- Where the authored course templates live and what the live one is called.
	TemplatesPath = { "Assets", "Maps", "Splashdown" },
	ActiveCourseName = "SplashdownCourse",
	StateFolderName = "SplashdownState",
	SnapshotValueName = "Snapshot",
	Attributes = {
		Checkpoint = "RaceCheckpoint",
		FinishTime = "RaceFinishTime",
		Splashes = "RaceSplashes",
		RoundPoints = "RaceRoundPoints",
	},
	Intro = {
		-- Camera flyover during the intro: a slow orbit above the course centre.
		Distance = 320,
		Height = 180,
		RotationSpeedDeg = 9,
		BlurSize = 0,
	},
	Splash = {
		ParticleBurst = 40,
		Lifetime = 1.6,
	},
}
