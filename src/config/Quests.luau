--!strict

export type Reward = {
	kind: "Bonks" | string,
	amount: number?,
	itemId: string?,
}

export type QuestTrack = {
	kind: string,
	modeId: string?,
}

export type QuestDefinition = {
	id: string,
	title: string,
	goal: number,
	steps: number,
	reward: Reward,
	track: QuestTrack,
}

local Quests = {
	DailyCount = 3,
	Progress = {
		FillColor = Color3.fromRGB(154, 233, 91),
		EmptyColor = Color3.fromRGB(255, 255, 255),
		MaxSteps = 5,
	},
	Button = {
		EnabledColor = { r = 0.38, g = 0.72, b = 0.2 },
		DisabledColor = { r = 0.48, g = 0.48, b = 0.48 },
		ClaimedColor = { r = 0.35, g = 0.35, b = 0.35 },
		Position = { x = 0.555, y = 0.842 },
		Size = { x = 0.259, y = 0.224 },
	},
	Definitions = {
		{
			id = "elims_5",
			title = "Get 5 eliminations",
			goal = 5,
			steps = 5,
			reward = { kind = "Bonks", amount = 150 },
			track = { kind = "Elim" },
		},
		{
			id = "catches_3",
			title = "Catch 3 dodgeballs",
			goal = 3,
			steps = 3,
			reward = { kind = "Bonks", amount = 125 },
			track = { kind = "Catch" },
		},
		{
			id = "matches_2",
			title = "Play 2 matches",
			goal = 2,
			steps = 2,
			reward = { kind = "Bonks", amount = 100 },
			track = { kind = "MatchPlayed" },
		},
		{
			id = "wins_1",
			title = "Win a match",
			goal = 1,
			steps = 1,
			reward = { kind = "Bonks", amount = 200 },
			track = { kind = "Win" },
		},
		{
			id = "ffa_wins_1",
			title = "Win a FFA match",
			goal = 1,
			steps = 1,
			reward = { kind = "Bonks", amount = 225 },
			track = { kind = "ModeWin", modeId = "FFA" },
		},
		{
			id = "tdm_wins_1",
			title = "Win a TDM match",
			goal = 1,
			steps = 1,
			reward = { kind = "Bonks", amount = 225 },
			track = { kind = "ModeWin", modeId = "TDM" },
		},
		{
			id = "dodgeball_elims_3",
			title = "Get 3 dodgeball eliminations",
			goal = 3,
			steps = 3,
			reward = { kind = "Bonks", amount = 175 },
			track = { kind = "DodgeballElim" },
		},
		{
			id = "hammer_elims_3",
			title = "Get 3 hammer eliminations",
			goal = 3,
			steps = 3,
			reward = { kind = "Bonks", amount = 175 },
			track = { kind = "HammerElim" },
		},
		{
			id = "hammer_hits_5",
			title = "Hit 5 players with the hammer",
			goal = 5,
			steps = 5,
			reward = { kind = "Bonks", amount = 150 },
			track = { kind = "HammerHit" },
		},
		{
			id = "throws_10",
			title = "Throw 10 dodgeballs",
			goal = 10,
			steps = 10,
			reward = { kind = "Bonks", amount = 125 },
			track = { kind = "BallThrow" },
		},
	} :: { QuestDefinition },
}

return Quests
