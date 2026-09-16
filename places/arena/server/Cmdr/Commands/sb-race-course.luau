-- Description: Cmdr definition for sb-race-course: names the course the next Splashdown round runs on.

--!strict

return {
	Name = "sb-race-course",
	Description = "Names the course the next Splashdown round runs on (BallBarrage, WhirlpoolWaltz, DoorDash, TumbleTunnels, TiptoeTrials, PistonPeak, SummitSplash).",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "string",
			Name = "course",
			Description = "Course id from Config.Gameplay.Splashdown.CourseOrder.",
		},
	},
}
