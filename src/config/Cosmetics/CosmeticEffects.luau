--!strict

-- Cosmetic VFX categories. Each category is a folder of authored particle
-- templates (and/or registered script effects) under
-- Assets.Cosmetics.Effects.<FolderName>, bound to the simulation events that
-- fire it and to the cosmetic slot that selects which effect a player shows.
-- Adding an effect category is one entry here plus the Studio folder; the shared
-- factory and the client driver never change.

export type Trigger = {
	Event: string,
	-- Optional extra predicate on the event, so one sim event kind can be split
	-- between categories (a dodgeball Elim carries a projectileId; a hammer Elim
	-- does not, and fires HammerHit instead).
	Match: ((event: { [string]: any }) -> boolean)?,
}

export type CategoryDef = {
	FolderName: string,
	Slot: string,
	DefaultEffectId: string,
	DefaultEmitCount: number,
	-- Event fields the driver reads: who acted (their equipped effect plays) and
	-- where the effect is located.
	OwnerField: string,
	PositionField: string,
	Triggers: { Trigger },
}

local Categories: { [string]: CategoryDef } = {
	Impact = {
		FolderName = "Impact",
		Slot = "ImpactEffectAssets",
		DefaultEffectId = "DefaultImpact",
		DefaultEmitCount = 5,
		OwnerField = "sourceId",
		PositionField = "position",
		Triggers = {
			{
				Event = "Elim",
				Match = function(event)
					return event.projectileId ~= nil
				end,
			},
			{ Event = "HammerHit" },
		},
	},
}

return {
	Categories = Categories,
}
