--!strict

return {
	Name = "sb-device-class",
	Description = "Overrides the validated aim-assist device class for players.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players whose device class should change.",
		},
		{
			Type = "deviceClass",
			Name = "deviceClass",
			Description = "Mouse or Touch.",
		},
	},
}
