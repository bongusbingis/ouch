-- Name: sb-match-restart.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-match-restart: restarts the match, optionally with a specific mode.
-- Created: 2026-07-15

--!strict

return {
	Name = "sb-match-restart",
	Description = "Restarts the match, optionally with a specific mode.",
	Group = "Splat Brawl | Gameplay",
	Args = {
		{
			Type = "modeId",
			Name = "mode",
			Description = "Mode to use. Omit to keep the current mode.",
			Optional = true,
		},
	},
}
