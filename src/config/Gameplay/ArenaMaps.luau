-- Description: Arena PvP maps offered on the ballot. Template names a Folder under ServerStorage.ArenaMaps holding the arena contract; the default map is the one authored live in Workspace.Assets.Arena at boot.

--!strict

-- Template names a Folder under ServerStorage.ArenaMaps holding the arena contract
-- (Map, MapOrigin, PlayerSpawns, TeamSpawns/Red+Blue, Scriptables). The default map
-- is the one authored live in Workspace.Assets.Arena at boot; its parking folder is
-- created at runtime. ThumbnailId "" = placeholder art (same sentinel as GameModes).
-- Accent is a T.Colors key, so this config needs no UI import. Optional VoteCamera
-- overrides UI.VoteCamera Distance/Height for that map.
local maps = {
	Bowl = {
		Enabled = true,
		DisplayName = "CANDY BOWL",
		ShortName = "BOWL",
		Template = "Bowl",
		ThumbnailId = "",
		SortOrder = 1,
		Accent = "Pink",
	},
	SecondMap = {
		Enabled = true,
		DisplayName = "BAMBOO ISLE",
		ShortName = "ISLE",
		Template = "SecondMap",
		ThumbnailId = "",
		SortOrder = 2,
		Accent = "Lime",
		VoteCamera = table.freeze({ Distance = 300, Height = 120 }), -- tune in SM-LENS
	},
}

local order = {}
for mapId, definition in maps do
	table.freeze(definition)
	if definition.Enabled then
		table.insert(order, mapId)
	end
end
table.sort(order, function(first, second)
	return maps[first].SortOrder < maps[second].SortOrder
end)

return table.freeze({
	DefaultMapId = "Bowl",
	SwapSettleSeconds = 1.5,
	Maps = table.freeze(maps),
	Order = table.freeze(order),
})
