-- Name: sb-match-time.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-match-time: sets the remaining time of the active match in seconds.
-- Created: 2026-07-15

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
