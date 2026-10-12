--!strict

-- Collectible match coins (DEC-036). Spawn points are authored map content:
-- Scriptables.CoinSpawns, a Folder of BaseParts on each arena map.
return {
	-- Kill switch: false stops all coin spawning and pickups (no other change needed).
	Enabled = true,
	BonksPerCoin = 5,
	MatchCapBonks = 50, -- per player per match; counted before boosts
	MaxActive = 6,
	FirstSpawnDelay = 4, -- seconds after the match goes Active
	RespawnMin = 6,
	RespawnMax = 10,
	PickupRadius = 5, -- studs, measured to the character's HumanoidRootPart
	-- Optional ServerStorage child to clone per coin; absent means a built gold disc.
	Template = "CoinPickup",
	-- Key in Config.Infra.Audio.Gameplay; empty AssetIds means no sound.
	SoundId = "CoinPickup",
}
