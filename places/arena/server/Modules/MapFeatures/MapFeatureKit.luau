-- Name: MapFeatureKit.luau
-- Author: Jack C.
-- Description: The interface every authored map feature implements, naming the arena scriptables folder it drives and the optional per-player, per-world, and forget hooks the feature service calls.
-- Created: 2026-08-18

--!strict

export type Context = {
	instances: { Instance },
	now: number,
	deltaTime: number,
}

export type MapFeatureKit = {
	folderName: string,
	instanceClass: string?,
	tickPlayer: ((context: Context, player: Player, root: BasePart) -> ())?,
	tickWorld: ((context: Context) -> ())?,
	forget: ((player: Player?) -> ())?,
}

return {}
