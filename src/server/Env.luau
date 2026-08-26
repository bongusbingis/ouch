-- Name: Env.luau
-- Author: Jack C.
-- Description: Per-environment server constants: the data store key, the lobby place players return to, and who may open the developer console.
-- Created: 2026-07-12

return {
	PrimaryDataKey = "STAGING_005",
	LobbyPlaceId = 130584867985467,
	Cmdr = {
		Enabled = true,
		AllowStudio = true,
		AllowCreator = true,
		UserIds = {},
	},
}
