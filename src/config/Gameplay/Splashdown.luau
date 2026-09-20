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
	-- The final seven (HANDOFF.md section 12.1, the replacement transaction of
	-- 2026-09-16): the six declarative rebuild courses in route order plus the
	-- hardened Summit Splash. The eight superseded legacy IDs are gone from this
	-- registry entirely -- six of their parked models were destroyed at the same
	-- swap and CrossCurrent never had one. Every id here has a promoted template
	-- under ReplicatedStorage.Assets.Maps.Splashdown and an Intro.Courses entry
	-- in Config.Interface.SplashdownIntro; SplashdownIntroModel.spec asserts the
	-- second of those, so the two lists move together.
	CourseOrder = {
		"BallBarrage",
		"WhirlpoolWaltz",
		"DoorDash",
		--"TumbleTunnels",
		--"TiptoeTrials",
		"PistonPeak",
		--"SummitSplash",
	},
	Courses = {
		BallBarrage = {
			DisplayName = "BALL BARRAGE",
			Difficulty = 3,
			ParSeconds = 75,
			CapSeconds = 180,
			CloseWindowSeconds = 60,
		},
		WhirlpoolWaltz = {
			DisplayName = "WHIRLPOOL WALTZ",
			Difficulty = 3,
			ParSeconds = 75,
			CapSeconds = 180,
			CloseWindowSeconds = 60,
			-- HANDOFF section 6: "Whirlpool Waltz uses 3/1; no other course has
			-- doors" besides Door Dash. Its spec places exactly one row of three
			-- door slabs (DoorRow 1, DoorIndex 1..3), which is what
			-- SplashdownCourses.resolve checks this block against.
			Doors = { PerRow = 3, BreakablePerRow = 1 },
		},
		DoorDash = {
			DisplayName = "DOOR DASH",
			-- HANDOFF 12.1's difficulty list for the final seven is 3, 3, 2, 3, 3, 4
			-- plus Summit's existing 3, so Door Dash is the one 2 in the set.
			Difficulty = 2,
			ParSeconds = 75,
			CapSeconds = 180,
			CloseWindowSeconds = 60,
			-- HANDOFF section 6: "Three Door Dash rows use PerRow 5/BreakablePerRow 2
			-- for the whole course." SplashdownCourses.resolve asserts every resolved
			-- row holds exactly PerRow slabs once this block exists.
			--Doors = { PerRow = 5, BreakablePerRow = 2 },
		},
		-- TumbleTunnels = {
		-- 	DisplayName = "TUMBLE TUNNELS",
		-- 	Difficulty = 3,
		-- 	CapSeconds = 180,
		-- 	CloseWindowSeconds = 60,
		-- 	-- HANDOFF section 6: "Three Door Dash rows use PerRow 5/BreakablePerRow 2
		-- 	-- for the whole course." SplashdownCourses.resolve asserts every resolved
		-- 	-- row holds exactly PerRow slabs once this block exists.
		-- 	Doors = { PerRow = 5, BreakablePerRow = 2 },
		-- },
		-- TumbleTunnels = {
		-- 	DisplayName = "TUMBLE TUNNELS",
		-- 	Difficulty = 3,
		-- 	ParSeconds = 75,
		-- 	CapSeconds = 180,
		-- 	CloseWindowSeconds = 60,
		-- },
		-- TiptoeTrials = {
		-- 	DisplayName = "TIPTOE TRIALS",
		-- 	Difficulty = 3,
		-- 	ParSeconds = 75,
		-- 	CapSeconds = 180,
		-- 	CloseWindowSeconds = 60,
		-- },
		PistonPeak = {
			DisplayName = "PISTON PEAK",
			-- HANDOFF 12.1's difficulty list for the final seven is 3, 3, 2, 3, 3, 4 and
			-- Summit's existing 3, so Piston Peak is the one 4 in the set.
			Difficulty = 4,
			ParSeconds = 75,
			CapSeconds = 180,
			CloseWindowSeconds = 60,
			-- The only active course with rising liquid. Course configuration owns the
			-- schedule; the authored hazard carries the explicit marker and matching
			-- validation fields. Section 7.6's seed of
			-- 60 studs drowned the Y 12 and Y 24 checkpoints, so it is lowered to 38:
			-- the flood stops at world-local Y +8, four studs under the lowest pad, and
			-- finishes rising at 115 s against the 180-second cap.
			LavaRise = {
				MaxHeight = 38,
				RiseStudsPerSecond = 38 / 95,
				StartDelaySeconds = 20,
				PauseWaypoints = "",
			},
		},
		-- Summit remains parked until its template is re-promoted. If re-enabled,
		-- its liquid schedule must use the same explicit fields as PistonPeak.
		-- SummitSplash = {
		-- 	DisplayName = "SUMMIT SPLASH",
		-- 	Difficulty = 3,
		-- 	ParSeconds = 115,
		-- 	CapSeconds = 210,
		-- 	CloseWindowSeconds = 45,
		-- 	LavaRise = { Studs = 60, DelaySeconds = 20, Seconds = 140 },
		-- },
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
