--!strict

-- Map pool. AssetName references a folder under ReplicatedStorage.Assets.Maps
-- containing Scriptables (BallSpawns, PlayerSpawns) and Static. DisplayName
-- and Thumbnail are for match voting UI.

export type MapEntry = {
	Id: string,
	AssetName: string,
	DisplayName: string,
	Thumbnail: string,
	ModeIds: { string },
	RecoveryY: number,
	Enabled: boolean,
}

return {
	Voting = {
		CandidateCount = 3,
		DurationSeconds = 10,
	},
	Pool = {
		{
			Id = "TestMap",
			AssetName = "CombatTestArena",
			DisplayName = "Test Arena",
			Thumbnail = "",
			ModeIds = { "FFA", "TDM" },
			RecoveryY = -40,
			Enabled = true,
		},
		{
			Id = "ThePit",
			AssetName = "ThePit",
			DisplayName = "The Pit",
			Thumbnail = "",
			ModeIds = { "FFA" },
			RecoveryY = -40,
			Enabled = false,
		},
		{
			Id = "FoamCourt",
			AssetName = "FoamCourt",
			DisplayName = "Foam Court",
			Thumbnail = "",
			ModeIds = { "TDM" },
			RecoveryY = -40,
			Enabled = false,
		},
		{
			Id = "SkyBounce",
			AssetName = "SkyBounce",
			DisplayName = "Sky Bounce",
			Thumbnail = "",
			ModeIds = { "FFA", "TDM" },
			RecoveryY = -80,
			Enabled = false,
		},
	} :: { MapEntry },
}
