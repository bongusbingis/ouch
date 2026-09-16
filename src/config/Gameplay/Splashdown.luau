--!strict

-- Splashdown race tunables. Courses carry their own cap and close window
-- because difficulty differs: a spiral climb with rising lava needs longer than
-- a straight sprint. Everything the courses share lives at the top level.
-- Units are studs and seconds.
return {
	RoundCount = 3,
	IntroSeconds = 9,
	-- Course-only responses. Arena brawl hazards keep their existing tuning.
	HazardResponse = {
		Rotor = { Speed = 48, UpwardSpeed = 20, HoldSeconds = 0.24 },
		Bumper = { Speed = 54, UpwardSpeed = 22, HoldSeconds = 0.26 },
		HammerSpeed = 58,
		MaceSpeed = 54,
		RollerSpeed = 48,
		SlidingWallSpeed = 44,
	},
	CountdownSeconds = 3,
	RoundResultsSeconds = 6,
	-- Between the splash and standing on the checkpoint pad again.
	RespawnDelaySeconds = 0.8,
	HazardVerticalPadding = 2,
	-- Below this downward speed (studs/s) a lava hit skips the camera pan-down
	-- cue: a course where lava rises up to meet a standing racer shouldn't
	-- play the same "falling in" cinematic as a racer plunging into it.
	LavaCamera = { MinFallSpeed = 40 },
	-- A root this far below the course floor counts as lost to the void.
	VoidDepthStuds = 80,
	-- Checkpoint and finish triggers are matched on the root, with this much
	-- vertical slack so a jump through an arch still counts.
	TriggerVerticalPadding = 4,
	-- Points for first place equal the queue capacity, so a full lobby's winner
	-- always scores the same number; last place scores 1 and a DNF scores 0.
	PointsForFirst = 30,
	-- A DNF is charged the round cap in the cumulative-time tiebreak.
	CourseOrder = {
		"WhirlPool",
		"DiscJockey",
		"KnockKnock",
		"BumperBay",
		"SummitSplash",
		"TiltTrip",
		"CrossCurrent",
		"Downpour",
	},
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
			ParSeconds = 115,
			CapSeconds = 210,
			CloseWindowSeconds = 45,
			LavaRise = { Studs = 60, DelaySeconds = 20, Seconds = 140 },
		},
		TiltTrip = {
			DisplayName = "TILT TRIP",
			Difficulty = 2,
			ParSeconds = 120,
			CapSeconds = 210,
			CloseWindowSeconds = 45,
		},
		CrossCurrent = {
			DisplayName = "CROSS CURRENT",
			Difficulty = 3,
			ParSeconds = 145,
			CapSeconds = 240,
			CloseWindowSeconds = 55,
		},
		Downpour = {
			DisplayName = "DOWNPOUR",
			Difficulty = 2,
			ParSeconds = 115,
			CapSeconds = 210,
			CloseWindowSeconds = 45,
		},
	},
	-- Every course carries its own invisible boundary ring, wider than the
	-- arena's, so a racer stays inside the bowl without hitting a wall on the
	-- outer decks; walls are the arena's authored boundary piece re-placed on
	-- this radius.
	Boundary = { Radius = 390, Segments = 24 },
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
	Splash = {
		ParticleBurst = 40,
		Lifetime = 1.6,
	},
}
