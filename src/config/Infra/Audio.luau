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
				-- "rbxassetid://1847683499",
				-- "rbxassetid://137827158863747",
				-- "rbxassetid://1845149698",
				-- "rbxassetid://1847683526",
				"rbxassetid://103042163423595",
			},
			Volume = 1,
			FadeInSeconds = 0.8,
		},
		Lobby = {
			AssetId = "rbxassetid://100890928902177",
			Volume = 1,
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
		DefaultElimination = {
			Scope = "World",
			Volume = 1.6,
			AssetIds = {
				"rbxassetid://173818824",
			},
		},
		ClangElimination = {
			Scope = "World",
			Volume = 1.6,
			AssetIds = {
				"rbxassetid://139535360137391",
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
		-- Coin pickup ("Coin Collect", 0.87 s, Creator Store free audio).
		CoinPickup = {
			Scope = "Local",
			Volume = 1,
			AssetIds = { "rbxassetid://135483737426662" },
		},
		OnboardingStepStart = {
			Scope = "Local",
			Volume = 0.5,
			AssetIds = { "rbxassetid://117503154823137" },
		},
		OnboardingStepSuccess = {
			Scope = "Local",
			Volume = 0.8,
			AssetIds = { "rbxassetid://122835655736085" },
		},
		OnboardingDummyLaunch = {
			Scope = "World",
			Volume = 1.5,
			AssetIds = {
				"rbxassetid://123922570136163",
				"rbxassetid://135468135163946",
			},
		},
		OnboardingHint = {
			Scope = "Local",
			Volume = 0.45,
			AssetIds = { "rbxassetid://117503154823137" },
		},
		OnboardingCoreComplete = {
			Scope = "Local",
			Volume = 0.9,
			AssetIds = { "rbxassetid://124993589864467" },
		},
		OnboardingCelebration = {
			Scope = "Local",
			Volume = 0.85,
			AssetIds = { "rbxassetid://9120681039" },
		},
		OnboardingReveal = {
			Scope = "Local",
			Volume = 0.6,
			AssetIds = { "rbxassetid://117503154823137" },
		},
	},

	Effects = {
		MatchStart = {
			AssetId = "rbxassetid://122835655736085",
			Volume = 0.32,
			MaxLifetimeSeconds = 4,
		},
		FinalSeconds = {
			AssetId = "rbxassetid://117503154823137",
			Volume = 0.16,
			Threshold = 5,
			MaxLifetimeSeconds = 1,
		},
		MatchEndWhistle = {
			AssetId = "rbxassetid://9120681039",
			Volume = 0.24,
			MaxLifetimeSeconds = 15,
		},
	},
}
