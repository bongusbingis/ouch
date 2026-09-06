-- Name: DebugPostMatchData.luau
-- Author: Jack C.
-- Description: Studio story fixtures for the post-match screen, providing complete result packets for every scenario without touching a production service or profile data.
-- Created: 2026-08-25

--!strict

local DebugPostMatchData = {}
local CLEAR = table.freeze({})

export type Scenario = {
	name: string,
	result: any,
	localMemberIndex: number?,
	statusState: ("Interactive" | "PlayAgain" | "Returning")?,
	requesting: boolean?,
	pendingAction: ("PlayAgain" | "CancelPlayAgain" | "ReturnToLobby" | "LeaveParty")?,
	error: string?,
}

local function members(count: number)
	local result = {}
	local names = { "YOU", "ALEX", "SAM", "MILO" }
	for index = 1, count do
		table.insert(result, {
			userId = index,
			username = names[index],
			displayName = names[index],
			isLeader = index == 1,
			isLocal = index == 1,
			present = true,
		})
	end
	return result
end

local function base(overrides: { [string]: any }?): any
	local result = {
		schemaVersion = 1,
		resultId = "debug-result",
		modeId = "TDM",
		modeName = "Team Deathmatch",
		outcome = "Victory",
		winnerId = "Blue",
		interactiveAt = 0,
		endsAt = 1e9,
		presentation = {
			eyebrow = "VICTORY",
			title = "BLUE TEAM WINS!",
			detail = "25  -  18",
			accent = "Cyan",
		},
		scores = {
			{ id = "Blue", label = "BLUE", score = 25 },
			{ id = "Red", label = "RED", score = 18 },
		},
		personalStats = {
			{ id = "Eliminations", label = "ELIMINATIONS", value = 11, highlight = true },
			{ id = "Catches", label = "CATCHES", value = 4 },
			{ id = "Deaths", label = "TIMES BONKED", value = 3 },
		},
		rewards = {
			matchXp = 850,
			seasonXp = 850,
			bonks = 120,
		},
		seasonProgress = {
			seasonId = "debug",
			displayName = "DEBUG SEASON",
			beforeXp = 3200,
			afterXp = 4050,
			beforeTier = 16,
			afterTier = 17,
			xpIntoTier = 50,
			xpForNextTier = 1000,
		},
		party = {
			partyId = "debug-party",
			leaderUserId = 1,
			members = members(4),
		},
	}
	for key, value in overrides or {} do
		result[key] = if value == CLEAR then nil else value
	end
	result.podium = {}
	local styles = { "ShowtimeTwirl", "ShowtimeFlex", "ShowtimeBounce" }
	for index = 1, 3 do
		local score = result.scores[index]
		local entry = {
			playerId = tostring(index),
			userId = index,
			username = ({ "YOU", "ALEX", "SAM" })[index],
			displayName = ({ "YOU", "ALEX", "SAM" })[index],
			emoteId = styles[index],
			placement = index,
			score = ({ 11, 8, 6 })[index],
		}
		if result.modeId == "FFA" and score then
			entry.playerId = score.id
			entry.userId = tonumber(score.id) or index
			entry.displayName = score.label
			entry.placement = score.placement or index
			entry.score = score.score
		end
		if entry.placement <= 3 then
			table.insert(result.podium, entry)
		end
	end
	result.personalAppearance =
		{ playerId = "1", userId = 1, username = "YOU", displayName = "YOU", emoteId = "ShowtimeTwirl" }
	return result
end

function DebugPostMatchData.scenarios(): { Scenario }
	local tdmDefeat = base({
		resultId = "tdm-defeat",
		outcome = "Defeat",
		winnerId = "Red",
		presentation = {
			eyebrow = "ROUND OVER",
			title = "RED TEAM WINS!",
			detail = "25  -  18",
			accent = "Pink",
		},
	})
	local ffaFirst = base({
		resultId = "ffa-first",
		modeId = "FFA",
		modeName = "Free For All",
		winnerId = "1",
		placement = 1,
		presentation = { eyebrow = "VICTORY", title = "1ST PLACE", detail = "YOU TAKE THE WIN", accent = "Yellow" },
		scores = {
			{ id = "1", label = "YOU", score = 15, placement = 1 },
			{ id = "2", label = "ALEX", score = 12, placement = 2 },
			{ id = "3", label = "SAM", score = 9, placement = 3 },
		},
	})
	local ffaSixth = base({
		resultId = "ffa-sixth",
		modeId = "FFA",
		modeName = "Free For All",
		outcome = "Defeat",
		winnerId = "2",
		placement = 6,
		presentation = { eyebrow = "ROUND OVER", title = "6TH PLACE", detail = "ALEX TAKES THE WIN", accent = "Cyan" },
		scores = {
			{ id = "2", label = "ALEX", score = 15, placement = 1 },
			{ id = "3", label = "SAM", score = 12, placement = 2 },
			{ id = "1", label = "YOU", score = 7, placement = 6 },
		},
	})
	local survivors = base({
		resultId = "infection-survivors",
		modeId = "Infection",
		modeName = "Infection",
		winnerId = "Survivors",
		presentation = { eyebrow = "VICTORY", title = "SURVIVORS WIN!", accent = "Yellow" },
		scores = {
			{ id = "Survivors", label = "SURVIVORS", score = 1 },
			{ id = "Infected", label = "INFECTED", score = 0 },
		},
	})
	local infected = base({
		resultId = "infection-infected",
		modeId = "Infection",
		modeName = "Infection",
		winnerId = "Infected",
		presentation = { eyebrow = "ROUND OVER", title = "INFECTED WIN!", accent = "Purple" },
		scores = {
			{ id = "Infected", label = "INFECTED", score = 1 },
			{ id = "Survivors", label = "SURVIVORS", score = 0 },
		},
	})
	local noRewards = base({ resultId = "no-rewards", rewards = CLEAR, seasonProgress = CLEAR })
	local rewardsPending = base({
		resultId = "rewards-pending",
		rewards = CLEAR,
		seasonProgress = CLEAR,
		rewardsPending = true,
	})
	local boostedRewards = base({
		resultId = "boosted-rewards",
		rewards = {
			matchXp = 1275,
			seasonXp = 1275,
			bonks = 240,
			baseXp = 850,
			baseBonks = 120,
			xpMultiplier = 1.5,
			bonksMultiplier = 2,
		},
	})
	local tie = base({
		resultId = "tie",
		outcome = "RoundOver",
		winnerId = CLEAR,
		presentation = { eyebrow = "MATCH COMPLETE", title = "WHAT A ROUND!", detail = "20  -  20", accent = "Cyan" },
		scores = {
			{ id = "Blue", label = "BLUE", score = 20 },
			{ id = "Red", label = "RED", score = 20 },
		},
	})
	local noParty = base({ resultId = "no-party", party = CLEAR })
	local longParty = base({
		resultId = "long-party",
		party = {
			partyId = "debug-long-party",
			leaderUserId = 1,
			members = {
				{
					userId = 1,
					username = "MarshmallowCaptain",
					displayName = "MarshmallowCaptain",
					isLeader = true,
					isLocal = true,
					present = true,
				},
				{
					userId = 2,
					username = "BouncyCastleHero",
					displayName = "BouncyCastleHero",
					isLeader = false,
					isLocal = false,
					present = true,
				},
				{
					userId = 3,
					username = "InflatableChampion",
					displayName = "InflatableChampion",
					isLeader = false,
					isLocal = false,
					present = true,
				},
				{
					userId = 4,
					username = "DodgeballSuperstar",
					displayName = "DodgeballSuperstar",
					isLeader = false,
					isLocal = false,
					present = true,
				},
			},
		},
	})
	local solo = base({
		resultId = "solo-party",
		party = { partyId = "debug-solo", leaderUserId = 1, members = members(1) },
	})

	return {
		{ name = "TDM VICTORY / PARTY 4", result = base({ resultId = "tdm-victory" }) },
		{ name = "TDM DEFEAT", result = tdmDefeat },
		{ name = "FFA 1ST", result = ffaFirst },
		{ name = "FFA 6TH", result = ffaSixth },
		{ name = "SURVIVORS WIN", result = survivors },
		{ name = "INFECTED WIN", result = infected },
		{ name = "NO REWARDS", result = noRewards },
		{ name = "REWARDS PENDING", result = rewardsPending },
		{ name = "BOOSTS / TIER UP", result = boostedRewards },
		{ name = "TIED ROUND", result = tie },
		{ name = "NO PARTY PROJECTION", result = noParty },
		{ name = "LONG PARTY NAMES", result = longParty },
		{
			name = "FUTURE CHALLENGE",
			result = base({
				resultId = "future-challenge",
				challenges = {
					{ id = "hits", label = "DODGEBALL HITS", current = 18, target = 20 },
				},
			}),
		},
		{
			name = "FUTURE UNLOCK",
			result = base({
				resultId = "future-unlock",
				unlocks = {
					{ id = "bubble-hammer", name = "BUBBLE HAMMER", kind = "Cosmetic" },
				},
			}),
		},
		{
			name = "MAX FUTURE PROGRESS",
			result = base({
				resultId = "max-future-progress",
				challenges = {
					{ id = "hits", label = "DODGEBALL HITS", current = 18, target = 20 },
					{ id = "catches", label = "CATCH THREE BALLS", current = 2, target = 3 },
					{ id = "wins", label = "WIN TWO ROUNDS", current = 1, target = 2 },
				},
				unlocks = {
					{ id = "bubble-hammer", name = "BUBBLE HAMMER", kind = "Cosmetic" },
					{ id = "star-ball", name = "STAR BALL", kind = "Cosmetic" },
					{ id = "confetti", name = "CONFETTI IMPACT", kind = "Cosmetic" },
				},
			}),
		},
		{ name = "PARTY OF ONE", result = solo },
		{ name = "PARTY MEMBER", result = base({ resultId = "party-member" }), localMemberIndex = 2 },
		{
			name = "PARTY MEMBER LEAVING",
			result = base({ resultId = "party-member-leaving" }),
			localMemberIndex = 2,
			statusState = "Interactive",
			requesting = true,
			pendingAction = "LeaveParty",
		},
		{
			name = "REQUEST ERROR",
			result = base({ resultId = "request-error" }),
			error = "request_failed",
		},
		{
			name = "PARTY RETURNING",
			result = base({ resultId = "party-returning" }),
			statusState = "Returning",
		},
		{ name = "FIRST MATCH", result = base({ resultId = "first-match", firstMatch = true }) },
	}
end

return table.freeze(DebugPostMatchData)
