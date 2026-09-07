--!strict

local Items = {
	DodgeBall1 = {
		Category = "BallAssets",
		Rarity = "Common",
		DisplayName = "Bubblegum",
		Thumbnail = "",
		SplatColor = Color3.fromRGB(255, 102, 204),
		Visual = {
			Template = "Dodgeball",
			Color = Color3.fromRGB(255, 102, 204),
		},
	},
	DodgeBall2 = {
		Category = "BallAssets",
		Rarity = "Common",
		DisplayName = "Garden Green",
		Thumbnail = "",
		SplatColor = Color3.fromRGB(52, 142, 64),
		Visual = {
			Template = "Dodgeball",
			Color = Color3.fromRGB(52, 142, 64),
		},
	},
	DodgeBall3 = {
		Category = "BallAssets",
		Rarity = "Common",
		DisplayName = "Poolside Blue",
		Thumbnail = "",
		SplatColor = Color3.fromRGB(13, 105, 172),
		Visual = {
			Template = "Dodgeball",
			Color = Color3.fromRGB(13, 105, 172),
		},
	},
	DodgeBall4 = {
		Category = "BallAssets",
		Rarity = "Common",
		DisplayName = "Grape Soda",
		Thumbnail = "",
		SplatColor = Color3.fromRGB(98, 37, 209),
		Visual = {
			Template = "Dodgeball",
			Color = Color3.fromRGB(98, 37, 209),
		},
	},
	DodgeBall5 = {
		Category = "BallAssets",
		Rarity = "Common",
		DisplayName = "Cherry Red",
		Thumbnail = "",
		SplatColor = Color3.fromRGB(151, 0, 0),
		Visual = {
			Template = "Dodgeball",
			Color = Color3.fromRGB(151, 0, 0),
		},
	},
	DodgeBall6 = {
		Category = "BallAssets",
		Rarity = "Common",
		DisplayName = "Orange Pop",
		Thumbnail = "",
		SplatColor = Color3.fromRGB(255, 102, 0),
		Visual = {
			Template = "Dodgeball",
			Color = Color3.fromRGB(255, 102, 0),
		},
	},
	DodgeBall7 = {
		Category = "BallAssets",
		Rarity = "Common",
		DisplayName = "Snowball",
		Thumbnail = "",
		SplatColor = Color3.fromRGB(248, 248, 248),
		Visual = {
			Template = "Dodgeball",
			Color = Color3.fromRGB(248, 248, 248),
		},
	},
	DodgeBall8 = {
		Category = "BallAssets",
		Rarity = "Common",
		DisplayName = "Midnight",
		Thumbnail = "",
		SplatColor = Color3.fromRGB(17, 17, 17),
		Visual = {
			Template = "Dodgeball",
			Color = Color3.fromRGB(17, 17, 17),
		},
	},
	DodgeBall9 = {
		Category = "BallAssets",
		Rarity = "Common",
		DisplayName = "Lemon Drop",
		Thumbnail = "",
		SplatColor = Color3.fromRGB(255, 255, 0),
		Visual = {
			Template = "Dodgeball",
			Color = Color3.fromRGB(255, 255, 0),
		},
	},
	DodgeBall10 = {
		Category = "BallAssets",
		Rarity = "Rare",
		DisplayName = "Choco Chip",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 70587316032057,
				MetalnessMapId = 87116278307713,
				NormalMapId = 102776550401383,
				RoughnessMapId = 134483360804950,
			},
		},
	},
	DodgeBall11 = {
		Category = "BallAssets",
		Rarity = "Rare",
		DisplayName = "Caramel Swirl",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 102656904349307,
				MetalnessMapId = 104101639033239,
				NormalMapId = 140253493910071,
				RoughnessMapId = 89340300873941,
			},
		},
	},
	DodgeBall12 = {
		Category = "BallAssets",
		Rarity = "Rare",
		DisplayName = "Electric Blue",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 115896621697545,
				MetalnessMapId = 98059049247130,
				NormalMapId = 127271223919401,
				RoughnessMapId = 83028024890823,
			},
		},
	},
	DodgeBall13 = {
		Category = "BallAssets",
		Rarity = "Rare",
		DisplayName = "Arctic Swirl",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 91780976261127,
				MetalnessMapId = 98059049247130,
				NormalMapId = 122667227016555,
				RoughnessMapId = 71147476986886,
			},
		},
	},
	DodgeBall14 = {
		Category = "BallAssets",
		Rarity = "Rare",
		DisplayName = "Rainbow Ripple",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 106070073615722,
				MetalnessMapId = 136785502267461,
				NormalMapId = 133609981760364,
				RoughnessMapId = 74383115096724,
			},
		},
	},
	DodgeBall15 = {
		Category = "BallAssets",
		Rarity = "Rare",
		DisplayName = "Berry Shimmer",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 111781680500760,
				MetalnessMapId = 95531023703042,
				NormalMapId = 104340888420342,
				RoughnessMapId = 99180957039115,
			},
		},
	},
	DodgeBall16 = {
		Category = "BallAssets",
		Rarity = "Rare",
		DisplayName = "Silver Stitch",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 122292708681665,
				MetalnessMapId = 112058541037581,
				NormalMapId = 120429162013684,
				RoughnessMapId = 91062721413281,
			},
		},
	},
	DodgeBall17 = {
		Category = "BallAssets",
		Rarity = "Rare",
		DisplayName = "Magma Pop",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 122875560446107,
				MetalnessMapId = 114782608551658,
				NormalMapId = 135383229493098,
				RoughnessMapId = 118154635860820,
			},
		},
	},
	DodgeBall18 = {
		Category = "BallAssets",
		Rarity = "Rare",
		DisplayName = "Gingham Glow",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 124739599500011,
				MetalnessMapId = 136410319915557,
				NormalMapId = 139468687601728,
				RoughnessMapId = 112692469617287,
			},
		},
	},
	DodgeBall19 = {
		Category = "BallAssets",
		Rarity = "Legendary",
		DisplayName = "Watermelon",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 109592045367007,
				MetalnessMapId = 87116278307713,
				NormalMapId = 123595311578668,
				RoughnessMapId = 95560625063378,
			},
		},
	},
	DodgeBall20 = {
		Category = "BallAssets",
		Rarity = "Legendary",
		DisplayName = "Cotton Candy",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 101757542044438,
				MetalnessMapId = 104101639033239,
				NormalMapId = 118120529809566,
				RoughnessMapId = 100053612508463,
			},
		},
	},
	DodgeBall21 = {
		Category = "BallAssets",
		Rarity = "Legendary",
		DisplayName = "Frost Glow",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 132668409602719,
				MetalnessMapId = 123694837687011,
				NormalMapId = 123944398691141,
				RoughnessMapId = 129661462727044,
			},
		},
	},
	DodgeBall22 = {
		Category = "BallAssets",
		Rarity = "Legendary",
		DisplayName = "Side Eye",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 72243917934222,
				MetalnessMapId = 98059049247130,
				NormalMapId = 72596705483167,
				RoughnessMapId = 102237099321734,
			},
		},
	},
	DodgeBall23 = {
		Category = "BallAssets",
		Rarity = "Legendary",
		DisplayName = "Big Cheese",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 129562038562268,
				MetalnessMapId = 100371137853361,
				NormalMapId = 129920407825399,
				RoughnessMapId = 139672037127924,
			},
		},
	},
	DodgeBall24 = {
		Category = "BallAssets",
		Rarity = "Legendary",
		DisplayName = "Wild Spots",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 139254178904534,
				MetalnessMapId = 132925674939185,
				NormalMapId = 104168965252087,
				RoughnessMapId = 139899190009054,
			},
		},
	},
	DodgeBall25 = {
		Category = "BallAssets",
		Rarity = "Legendary",
		DisplayName = "Jade Marble",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 115500643124412,
				MetalnessMapId = 138665423813822,
				NormalMapId = 73375697111746,
				RoughnessMapId = 85920705815801,
			},
		},
	},
	DodgeBall26 = {
		Category = "BallAssets",
		Rarity = "Legendary",
		DisplayName = "Carbon Spin",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 80465756413340,
				MetalnessMapId = 114782608551658,
				NormalMapId = 76440844526998,
				RoughnessMapId = 83579277231421,
			},
		},
	},
	DodgeBall27 = {
		Category = "BallAssets",
		Rarity = "Legendary",
		DisplayName = "Flower Power",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 73109979988296,
				MetalnessMapId = 97355126204744,
				NormalMapId = 116910244775341,
				RoughnessMapId = 104573139150145,
			},
		},
	},
	DodgeBall28 = {
		Category = "BallAssets",
		Rarity = "Exclusive",
		DisplayName = "Golden Bloom",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 137710054432398,
				MetalnessMapId = 100968546294740,
				NormalMapId = 99967177968941,
				RoughnessMapId = 104065281498292,
			},
		},
	},
	DodgeBall29 = {
		Category = "BallAssets",
		Rarity = "Exclusive",
		DisplayName = "Puzzle Pop",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 96183276062153,
				MetalnessMapId = 82816443328566,
				NormalMapId = 118120529809566,
				RoughnessMapId = 136403411060377,
			},
		},
	},
	DodgeBall30 = {
		Category = "BallAssets",
		Rarity = "Exclusive",
		DisplayName = "Pool Party",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 117546812032096,
				MetalnessMapId = 85422369646943,
				NormalMapId = 123944398691141,
				RoughnessMapId = 78009839738612,
			},
		},
	},
	DodgeBall31 = {
		Category = "BallAssets",
		Rarity = "Exclusive",
		DisplayName = "Slime Time",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 74273147180404,
				MetalnessMapId = 126972988113708,
				NormalMapId = 91587439864028,
				RoughnessMapId = 114363735748036,
			},
		},
	},
	DodgeBall32 = {
		Category = "BallAssets",
		Rarity = "Exclusive",
		DisplayName = "Crimson Circuit",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 137107394631024,
				MetalnessMapId = 89552813976151,
				NormalMapId = 129920407825399,
				RoughnessMapId = 125952503732805,
			},
		},
	},
	DodgeBall33 = {
		Category = "BallAssets",
		Rarity = "Exclusive",
		DisplayName = "Woodland Roll",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 117621757652196,
				MetalnessMapId = 132925674939185,
				NormalMapId = 99924311920787,
				RoughnessMapId = 135492692399351,
			},
		},
	},
	DodgeBall34 = {
		Category = "BallAssets",
		Rarity = "Exclusive",
		DisplayName = "Confetti Camo",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 97585948453316,
				MetalnessMapId = 76824723232048,
				NormalMapId = 73375697111746,
				RoughnessMapId = 108692074825479,
			},
		},
	},
	DodgeBall35 = {
		Category = "BallAssets",
		Rarity = "Exclusive",
		DisplayName = "Neon Hex",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 120351955783051,
				MetalnessMapId = 98149370917053,
				NormalMapId = 95766884911209,
				RoughnessMapId = 139017288093553,
			},
		},
	},
	DodgeBall36 = {
		Category = "BallAssets",
		Rarity = "Exclusive",
		DisplayName = "Peppermint Twist",
		Thumbnail = "",
		Visual = {
			Template = "Dodgeball",
			SurfaceMaps = {
				ColorMapId = 117147605073759,
				MetalnessMapId = 109346280993686,
				NormalMapId = 116910244775341,
				RoughnessMapId = 90897299857674,
			},
		},
	},
}

return Items
