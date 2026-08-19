--!strict

return {
	Name = "sb-match-time",
	Description = "Sets the remaining time of the active match in seconds.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "number",
			Name = "seconds",
			Description = "Non-negative seconds remaining.",
		},
	},
}
