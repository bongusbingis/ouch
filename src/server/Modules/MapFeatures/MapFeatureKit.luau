--!strict

-- The interface every authored map feature implements. Adding a feature (fans,
-- jump pads, moving obstacles) means one module satisfying this type plus a
-- MapFeatureRegistry entry — MapFeatureService, the arena, and the match
-- lifecycle do not change.
--
-- folderName is the folder under Workspace.Assets.Arena.Scriptables whose direct
-- BasePart children this kit drives. The service discovers those parts, keeps
-- them current as the folder changes, and drives the hooks below each Heartbeat.

export type Context = {
	parts: { BasePart },
	now: number,
	deltaTime: number,
}

export type MapFeatureKit = {
	folderName: string,
	-- Per-Heartbeat per-alive-player update. The common shape: react to a player
	-- being inside one of this kit's parts.
	tickPlayer: ((context: Context, player: Player, root: BasePart) -> ())?,
	-- Per-Heartbeat update independent of players, for features that move or
	-- animate their own parts. Optional.
	tickWorld: ((context: Context) -> ())?,
	-- Drop any per-player state this kit accumulated. Called when a player
	-- leaves and when the kit is unbound.
	forget: ((player: Player?) -> ())?,
}

return {}
