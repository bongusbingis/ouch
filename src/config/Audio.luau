--!strict

-- Client audio asset ids, mix defaults, and transition timing.

return {
	Mix = {
		MasterVolume = 1,
		MusicVolume = 1,
		EffectsVolume = 1,
	},
	Music = {
		FadeOutSeconds = 0.65,
		Match = {
			Tracks = {
				"rbxassetid://1847683499",
				"rbxassetid://137827158863747",
				"rbxassetid://1845149698",
				"rbxassetid://1847683526",
				"rbxassetid://131711369956795",
			},
			Volume = 0.18,
			FadeInSeconds = 0.8,
		},
		Lobby = {
			AssetId = "rbxassetid://100890928902177",
			Volume = 0.08,
			FadeInSeconds = 1,
		},
	},
	Effects = {
		MatchEndWhistle = {
			AssetId = "rbxassetid://9120681039",
			Volume = 0.24,
			MaxLifetimeSeconds = 15,
		},
	},
}
