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
			Volume = 0, --0.18,
			FadeInSeconds = 0.8,
		},
		Lobby = {
			AssetId = "rbxassetid://100890928902177",
			Volume = 0.08,
			FadeInSeconds = 1,
		},
	},
	-- Gameplay one-shots, spawned in code from these ids rather than authored as
	-- templates. AssetIds is picked from at random each time, so a list of one is
	-- simply a sound with no variance.
	--
	-- Scope decides how it reaches the player: "World" positions it at the event
	-- so distance and direction apply, "Local" plays it flat for this client only,
	-- for anything that should read as personal feedback rather than a world
	-- sound. Adding a local cue later is a Scope change here, not new code.
	Gameplay = {
		HammerElimination = {
			Scope = "World",
			Volume = 1.6,
			AssetIds = {
				"rbxassetid://122682383632262",
				"rbxassetid://87679579947858",
				"rbxassetid://134712572791297",
				"rbxassetid://92196646571002",
			},
		},
		HammerSwing = {
			Scope = "World",
			Volume = 1.45,
			AssetIds = {
				"rbxassetid://137298186656357",
				"rbxassetid://93854325647161",
				"rbxassetid://137964779511233",
			},
		},
		JumpPadBounce = {
			Scope = "World",
			Volume = 1.5,
			AssetIds = {
				"rbxassetid://123922570136163",
				"rbxassetid://135468135163946",
				"rbxassetid://6746569988",
			},
		},
		DodgeballElimination = {
			Scope = "World",
			Volume = 1.6,
			AssetIds = {
				"rbxassetid://173818824",
				"rbxassetid://6509749580",
				"rbxassetid://139905654761878",
			},
		},
		DodgeballThrow = {
			Scope = "World",
			Volume = 1.45,
			AssetIds = {
				"rbxassetid://94573137804285",
				"rbxassetid://129467477219437",
				"rbxassetid://101808428209321",
			},
		},
		DodgeballBounce = {
			Scope = "World",
			Volume = 1.4,
			AssetIds = {
				"rbxassetid://8254244321",
				"rbxassetid://8254243230",
				"rbxassetid://8254243751",
			},
		},
		ElimZoneFall = {
			Scope = "World",
			Volume = 1.6,
			AssetIds = {
				"rbxassetid://93903966058481",
			},
		},
		OnboardingEnemyKilled = {
			Scope = "Local",
			Volume = 1,
			AssetIds = {
				"rbxassetid://18835016448",
			},
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
