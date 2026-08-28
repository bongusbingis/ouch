-- Name: sb-onboarding.luau
-- Author: Jack C.
-- Description: Cmdr definition for sb-onboarding: runs one of the onboarding developer commands against a player.
-- Created: 2026-08-27

--!strict

return {
	Name = "sb-onboarding",
	Description = "Runs an onboarding developer command (Reset, Force, StartAt, MarkCoreComplete, MarkCompleted, MarkSkipped, Finish, Status).",
	Group = "Splat Brawl | Onboarding",
	Args = {
		{
			Type = "string",
			Name = "command",
			Description = "Reset | Force | StartAt | MarkCoreComplete | MarkCompleted | MarkSkipped | Finish | Status",
		},
		{
			Type = "player",
			Name = "player",
			Description = "The player to act on.",
		},
		{
			Type = "string",
			Name = "step",
			Description = "Step id for StartAt or MarkSkipped: NormalThrow, Hammer, ChargedThrow, Practice.",
			Optional = true,
		},
	},
}
