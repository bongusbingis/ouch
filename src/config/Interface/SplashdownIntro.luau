--!strict
-- Authored, stationary camera compositions in course space (relative to MapOrigin).
-- Each course gets an establishing shot, an obstacle detail, and a finish reveal.
-- Keep these positions alongside the layouts in author-splashdown-courses.luau.
return {
	CutFadeSeconds = 0.16,
	ReferenceAspect = 16 / 9,
	MaxFieldOfView = 95,
	Courses = {
		-- Approximate compositions from the measured course geometry (HANDOFF.md
		-- section 11), not yet dialed in against an actual Studio capture; revisit
		-- once the fixed-camera pass (section 8.6) runs for these two courses.
		BallBarrage = {
			Description = "Three Big Balls wait over open water. Bounce your way across, then hammer through to the finish!",
			Shots = {
				{ Eye = { -60, 260, 60 }, Look = { -60, 0, 60 }, FieldOfView = 72 },
				{ Eye = { -40, 60, 130 }, Look = { -40, 10, 90 }, FieldOfView = 60 },
				{ Eye = { -100, 40, -40 }, Look = { -140, 0, -56 }, FieldOfView = 62 },
			},
		},
		WhirlpoolWaltz = {
			Description = "Spiral down through the ride decks and doorways, and don't slip off the spinning platforms!",
			Shots = {
				{ Eye = { 0, 280, 0 }, Look = { 0, 20, 0 }, FieldOfView = 74 },
				{ Eye = { 140, 70, 100 }, Look = { 80, 20, 60 }, FieldOfView = 60 },
				{ Eye = { 90, 50, -40 }, Look = { 40, 5, -10 }, FieldOfView = 62 },
			},
		},
		DoorDash = {
			Description = "Five doors, three rows, and only two of each row give way. Pick a lane and dash!",
			Shots = {
				{ Eye = { -40, 300, 40 }, Look = { 0, 10, 0 }, FieldOfView = 74 },
				-- Down the corridor's own axis and UNDER its roof: the door rows are the
				-- shot, and an overhead angle would only show the roof that stops them
				-- being climbed.
				{ Eye = { -238, 27, 56 }, Look = { -150, 22, 56 }, FieldOfView = 62 },
				{ Eye = { -10, 55, -105 }, Look = { -60, 18, -42 }, FieldOfView = 60 },
			},
		},
		TiltTrip = {
			Description = "Keep your balance on tilting decks and dodge the swinging obstacles. Next stop: the finish!",
			Shots = {
				{ Eye = { 0, 240, 305 }, Look = { 0, 0, -5 }, FieldOfView = 72 },
				{ Eye = { -65, 60, 155 }, Look = { -175, 0, 30 }, FieldOfView = 62 },
				{ Eye = { 30, 70, 110 }, Look = { -35, 0, 235 }, FieldOfView = 60 },
			},
		},
		CrossCurrent = {
			Description = "Race over and under the crossing! Slip past sliding walls and swinging bonks to reach the finish.",
			Shots = {
				{ Eye = { 30, 255, 300 }, Look = { 0, 10, 0 }, FieldOfView = 72 },
				{ Eye = { 120, 100, 60 }, Look = { 0, 20, 0 }, FieldOfView = 64 },
				{ Eye = { -90, 65, -85 }, Look = { -200, 0, 0 }, FieldOfView = 60 },
			},
		},
		Downpour = {
			Description = "Dodge the paddle wheels and bumpers, then take the slide to the finish. Wheee!",
			Shots = {
				{ Eye = { 0, 255, 300 }, Look = { 0, 10, 0 }, FieldOfView = 72 },
				{ Eye = { -30, 85, -85 }, Look = { 30, 24, -200 }, FieldOfView = 62 },
				{ Eye = { 115, 55, 125 }, Look = { 0, -12, 65 }, FieldOfView = 64 },
			},
		},
		WhirlPool = {
			Description = "Dodge the spinners, ride the fans, and race to the finish. Try not to get bonked!",
			Shots = {
				{ Eye = { 150, 150, 310 }, Look = { 0, 0, 40 }, FieldOfView = 62 },
				{ Eye = { -100, 48, 172 }, Look = { 0, 8, 118 }, FieldOfView = 56 },
				{ Eye = { 110, 68, -155 }, Look = { 0, 4, -266 }, FieldOfView = 58 },
			},
		},
		DiscJockey = {
			Description = "Hop across spinning discs, then bounce to the finish. Miss a beat? That's a splash!",
			Shots = {
				{ Eye = { 0, 230, 290 }, Look = { 0, 0, -5 }, FieldOfView = 70 },
				{ Eye = { -75, 60, -70 }, Look = { -60, 0, -160 }, FieldOfView = 60 },
				{ Eye = { 95, 65, 112 }, Look = { 200, 12, 212 }, FieldOfView = 58 },
			},
		},
		KnockKnock = {
			Description = "Some doors break. Some doors bonk. Find a way through and dash to the finish!",
			Shots = {
				{ Eye = { -155, 170, 290 }, Look = { 0, 0, 5 }, FieldOfView = 64 },
				{ Eye = { 94, 42, 226 }, Look = { 0, 8, 155 }, FieldOfView = 58 },
				{ Eye = { -108, 70, -170 }, Look = { 0, 0, -267 }, FieldOfView = 60 },
			},
		},
		BumperBay = {
			Description = "Dodge bumpers and swinging hammers. Keep your footing and beat the bonks to the finish!",
			Shots = {
				{ Eye = { 0, 235, 315 }, Look = { 0, 0, -10 }, FieldOfView = 70 },
				{ Eye = { 105, 55, -64 }, Look = { 0, 8, -160 }, FieldOfView = 60 },
				{ Eye = { -82, 70, 108 }, Look = { -190, 12, 211 }, FieldOfView = 60 },
			},
		},
		SummitSplash = {
			Description = "The lava's rising! Climb the winding course and reach the top before your toes get toasted!",
			Shots = {
				{ Eye = { 210, 245, 205 }, Look = { 0, 0, 0 }, FieldOfView = 72 },
				{ Eye = { -66, 60, -140 }, Look = { -180, -4, -113 }, FieldOfView = 62 },
				{ Eye = { 100, 90, 100 }, Look = { 0, 24, 0 }, FieldOfView = 58 },
			},
		},
	},
}
