--!strict

-- Map pool. AssetName references a folder under ReplicatedStorage.Assets.Maps
-- containing Scriptables (BallSpawns, PlayerSpawns) and Static. DisplayName
-- and Thumbnail are for UI rendering (map voting later).

export type MapEntry = {
	Id: string,
	AssetName: string,
	DisplayName: string,
	Thumbnail: string,
}

return {
	Pool = {
		{
			Id = "TestMap",
			AssetName = "CombatTestArena",
			DisplayName = "Test Arena",
			Thumbnail = "",
		},
	} :: { MapEntry },
}
