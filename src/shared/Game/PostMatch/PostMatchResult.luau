-- Description: Pure projection between the authoritative match and progression services and the post-match screen, building, formatting, and parsing result packets while leaving unavailable fields absent rather than fabricated.

--!strict

local PostMatchResult = {}

PostMatchResult.SchemaVersion = 1

export type Outcome = "Victory" | "Defeat" | "RoundOver"
export type Accent = "Cyan" | "Yellow" | "Pink" | "Purple"

export type Contestant = {
	playerId: string,
	userId: number,
	username: string,
	displayName: string,
	teamId: string?,
	colorId: string?,
	costumeId: string?,
	emoteId: string?,
	ballId: string?,
	hammerId: string?,
	contribution: number?,
}

export type ShowcaseEntry = Contestant & { placement: number, score: number }

export type ScoreEntry = {
	id: string,
	label: string,
	score: number,
	placement: number?,
}

export type GlobalResult = {
	schemaVersion: number,
	resultId: string,
	modeId: string,
	modeName: string,
	scoreScope: "Player" | "Team",
	winnerId: string?,
	reason: string,
	interactiveAt: number,
	endsAt: number,
	contestants: { Contestant },
	scores: { ScoreEntry },
}

export type PersonalSummary = {
	firstMatch: boolean?,
	rewardsPending: boolean?,
	won: boolean?,
	elims: number?,
	deaths: number?,
	catches: number?,
	baseXp: number?,
	baseBonks: number?,
	xpMultiplier: number?,
	bonksMultiplier: number?,
	xp: number?,
	bonks: number?,
	seasonXp: number?,
	seasonBefore: { [string]: any }?,
	seasonAfter: { [string]: any }?,
}

export type PartyMember = {
	userId: number,
	username: string,
	displayName: string,
	isLeader: boolean,
	isLocal: boolean,
	present: boolean,
}

export type Party = {
	partyId: string,
	leaderUserId: number,
	members: { PartyMember },
}

export type Stat = {
	id: string,
	label: string,
	value: number,
	highlight: boolean?,
}

export type Rewards = {
	matchXp: number,
	seasonXp: number?,
	bonks: number,
	baseXp: number?,
	baseBonks: number?,
	xpMultiplier: number?,
	bonksMultiplier: number?,
}

export type SeasonProgress = {
	seasonId: string,
	displayName: string,
	beforeXp: number,
	afterXp: number,
	beforeTier: number,
	afterTier: number,
	xpIntoTier: number,
	xpForNextTier: number,
}

export type Presentation = {
	eyebrow: string,
	title: string,
	detail: string?,
	accent: Accent,
}

export type ChallengeProgress = {
	id: string,
	label: string,
	current: number,
	target: number,
	complete: boolean?,
}

export type Unlock = {
	id: string,
	name: string,
	kind: string,
	thumbnail: string?,
}

export type PlayerResult = {
	schemaVersion: number,
	resultId: string,
	modeId: string,
	modeName: string,
	outcome: Outcome,
	firstMatch: boolean?,
	rewardsPending: boolean?,
	winnerId: string?,
	placement: number?,
	interactiveAt: number,
	endsAt: number,
	presentation: Presentation,
	scores: { ScoreEntry },
	personalStats: { Stat },
	podium: { ShowcaseEntry }?,
	personalAppearance: Contestant?,
	rewards: Rewards?,
	seasonProgress: SeasonProgress?,
	challenges: { ChallengeProgress }?,
	unlocks: { Unlock }?,
	party: Party?,
}

export type BuildInput = {
	resultId: string,
	modeId: string,
	modeName: string,
	scoreScope: "Player" | "Team",
	winnerId: string?,
	reason: string,
	interactiveAt: number,
	endsAt: number,
	contestants: { Contestant },
	scores: { [string]: number },
	teamIds: { string }?,
}

local function copyContestants(contestants: { Contestant }): { Contestant }
	local result = {}
	for _, contestant in contestants do
		table.insert(result, {
			playerId = contestant.playerId,
			userId = contestant.userId,
			username = contestant.username,
			displayName = contestant.displayName,
			teamId = contestant.teamId,
			colorId = contestant.colorId,
			emoteId = contestant.emoteId,
			ballId = contestant.ballId,
			hammerId = contestant.hammerId,
			contribution = contestant.contribution,
		})
	end
	table.sort(result, function(a, b)
		return a.userId < b.userId
	end)
	return result
end

local function contestantLabel(contestants: { Contestant }, id: string): string
	for _, contestant in contestants do
		if contestant.playerId == id then
			return contestant.displayName
		end
	end
	return string.upper(id)
end

local function orderedScores(input: BuildInput, contestants: { Contestant }): { ScoreEntry }
	local ids = {}
	local scores = table.clone(input.scores)
	if input.scoreScope == "Team" then
		for _, teamId in input.teamIds or {} do
			table.insert(ids, teamId)
		end
	else
		for _, contestant in contestants do
			table.insert(ids, contestant.playerId)
			if scores[contestant.playerId] == nil then
				scores[contestant.playerId] = contestant.contribution or 0
			end
		end
	end

	table.sort(ids, function(a, b)
		local aScore = scores[a] or 0
		local bScore = scores[b] or 0
		if aScore == bScore then
			return a < b
		end
		return aScore > bScore
	end)

	local result = {}
	local previousScore: number? = nil
	local placement = 0
	for index, id in ids do
		local score = scores[id] or 0
		if previousScore == nil or score ~= previousScore then
			placement = index
		end
		previousScore = score
		table.insert(result, {
			id = id,
			label = if input.scoreScope == "Team" then string.upper(id) else contestantLabel(contestants, id),
			score = score,
			placement = if input.scoreScope == "Player" then placement else nil,
		})
	end
	return result
end

function PostMatchResult.build(input: BuildInput): GlobalResult
	local contestants = copyContestants(input.contestants)
	return {
		schemaVersion = PostMatchResult.SchemaVersion,
		resultId = input.resultId,
		modeId = input.modeId,
		modeName = input.modeName,
		scoreScope = input.scoreScope,
		winnerId = input.winnerId,
		reason = input.reason,
		interactiveAt = input.interactiveAt,
		endsAt = input.endsAt,
		contestants = contestants,
		scores = orderedScores(input, contestants),
	}
end

function PostMatchResult.formatPlacement(placement: number): string
	local remainder100 = placement % 100
	if remainder100 >= 11 and remainder100 <= 13 then
		return `{placement}TH`
	end
	local suffix = if placement % 10 == 1
		then "ST"
		else if placement % 10 == 2 then "ND" else if placement % 10 == 3 then "RD" else "TH"
	return `{placement}{suffix}`
end

local function findContestant(result: GlobalResult, userId: number): Contestant?
	for _, contestant in result.contestants do
		if contestant.userId == userId then
			return contestant
		end
	end
	return nil
end

local function findPlacement(result: GlobalResult, playerId: string): number?
	for _, score in result.scores do
		if score.id == playerId then
			return score.placement
		end
	end
	return nil
end

local function scoreDetail(scores: { ScoreEntry }): string?
	if #scores < 2 then
		return nil
	end
	return `{scores[1].score}  -  {scores[2].score}`
end

local function presentation(result: GlobalResult, outcome: Outcome, placement: number?): Presentation
	if result.reason == "NoContest" then
		return {
			eyebrow = "ROUND ENDED",
			title = "LET'S FIND MORE PLAYERS",
			detail = "YOUR EARNED REWARDS ARE KEPT",
			accent = "Cyan",
		}
	end
	local accent: Accent = if outcome == "Victory" then "Yellow" else "Cyan"
	local eyebrow = if outcome == "Victory"
		then "VICTORY"
		else if outcome == "Defeat" then "ROUND OVER" else "MATCH COMPLETE"

	if result.modeId == "FFA" then
		return {
			eyebrow = eyebrow,
			title = if placement then `{PostMatchResult.formatPlacement(placement)} PLACE` else "ROUND OVER",
			detail = if result.winnerId and result.winnerId ~= ""
				then `{contestantLabel(result.contestants, result.winnerId)} TAKES THE WIN`
				else if result.scores[1]
						and result.scores[2]
						and result.scores[1].score == result.scores[2].score
					then "TIED ROUND"
					else "ROUND COMPLETE",
			accent = accent,
		}
	end

	local winner = result.winnerId
	if winner ~= nil and winner ~= "" then
		local title = if result.modeId == "Infection"
			then `{string.upper(winner)} WIN!`
			else `{string.upper(winner)} TEAM WINS!`
		return {
			eyebrow = eyebrow,
			title = title,
			detail = if result.modeId == "Infection" then nil else scoreDetail(result.scores),
			accent = if winner == "Blue"
				then "Cyan"
				else if winner == "Red" then "Pink" else if winner == "Infected" then "Purple" else accent,
		}
	end

	return {
		eyebrow = "MATCH COMPLETE",
		title = "WHAT A ROUND!",
		detail = scoreDetail(result.scores),
		accent = "Cyan",
	}
end

local function personalStats(summary: PersonalSummary?, placement: number?): { Stat }
	local stats = {}
	if summary then
		if summary.elims ~= nil then
			table.insert(stats, { id = "Eliminations", label = "ELIMINATIONS", value = summary.elims })
		end
		if summary.catches ~= nil then
			table.insert(stats, { id = "Catches", label = "CATCHES", value = summary.catches })
		end
		if summary.deaths ~= nil then
			table.insert(stats, { id = "Deaths", label = "TIMES BONKED", value = summary.deaths })
		end
	end
	if placement ~= nil then
		table.insert(stats, { id = "Placement", label = "PLACEMENT", value = placement })
	end
	local best: Stat? = nil
	for _, stat in stats do
		if stat.id ~= "Deaths" and stat.id ~= "Placement" and (best == nil or stat.value > (best :: Stat).value) then
			best = stat
		end
	end
	if best and best.value > 0 then
		best.highlight = true
	end
	return stats
end

local function rewards(summary: PersonalSummary?): Rewards?
	if summary == nil or summary.xp == nil or summary.bonks == nil then
		return nil
	end
	return {
		matchXp = summary.xp,
		seasonXp = summary.seasonXp,
		bonks = summary.bonks,
		baseXp = summary.baseXp,
		baseBonks = summary.baseBonks,
		xpMultiplier = summary.xpMultiplier,
		bonksMultiplier = summary.bonksMultiplier,
	}
end

local function seasonProgress(summary: PersonalSummary?): SeasonProgress?
	local before = if summary then summary.seasonBefore else nil
	local after = if summary then summary.seasonAfter else nil
	if before == nil or after == nil or after.active ~= true then
		return nil
	end
	return {
		seasonId = tostring(after.seasonId or ""),
		displayName = tostring(after.displayName or "SEASON"),
		beforeXp = tonumber(before.xp) or 0,
		afterXp = tonumber(after.xp) or 0,
		beforeTier = tonumber(before.tier) or 0,
		afterTier = tonumber(after.tier) or 0,
		xpIntoTier = tonumber(after.xpIntoTier) or 0,
		xpForNextTier = math.max(tonumber(after.xpForNextTier) or 1, 1),
	}
end

function PostMatchResult.podium(result: GlobalResult): { ShowcaseEntry }
	if result.reason == "NoContest" then
		return {}
	end
	local candidates = {}
	local scores = {}
	for _, entry in result.scores do
		scores[entry.id] = entry.score
	end
	for _, contestant in result.contestants do
		local score = if result.scoreScope == "Player" then scores[contestant.playerId] else contestant.contribution
		if score ~= nil and (result.scoreScope == "Player" or contestant.teamId == result.winnerId) then
			local entry: any = table.clone(contestant)
			entry.score = score
			table.insert(candidates, entry)
		end
	end
	table.sort(candidates, function(a, b)
		return if a.score == b.score then a.userId < b.userId else a.score > b.score
	end)
	local podium = {}
	local previous, rank = nil, 0
	for index = 1, math.min(#candidates, 3) do
		local entry = candidates[index]
		if entry.score ~= previous then
			rank = index
		end
		previous = entry.score
		entry.placement = rank
		table.insert(podium, entry)
	end
	return podium
end

function PostMatchResult.forPlayer(
	result: GlobalResult,
	userId: number,
	summary: PersonalSummary?,
	party: Party?
): PlayerResult?
	local contestant = findContestant(result, userId)
	if contestant == nil then
		return nil
	end
	local winnerId = result.winnerId
	local won = winnerId ~= nil
		and winnerId ~= ""
		and (winnerId == contestant.playerId or winnerId == contestant.teamId)
	local outcome: Outcome = if winnerId == nil or winnerId == ""
		then "RoundOver"
		else if won then "Victory" else "Defeat"
	local placement = if result.scoreScope == "Player" then findPlacement(result, contestant.playerId) else nil

	return {
		schemaVersion = PostMatchResult.SchemaVersion,
		resultId = result.resultId,
		modeId = result.modeId,
		modeName = result.modeName,
		outcome = outcome,
		firstMatch = if summary then summary.firstMatch else nil,
		rewardsPending = if summary then summary.rewardsPending else nil,
		winnerId = winnerId,
		placement = placement,
		interactiveAt = result.interactiveAt,
		endsAt = result.endsAt,
		presentation = presentation(result, outcome, placement),
		scores = table.clone(result.scores),
		personalStats = personalStats(summary, placement),
		podium = PostMatchResult.podium(result),
		personalAppearance = table.clone(contestant),
		rewards = rewards(summary),
		seasonProgress = seasonProgress(summary),
		party = party,
	}
end

local function validText(value: any, maximum: number): boolean
	return typeof(value) == "string" and #value > 0 and #value <= maximum
end

local function finiteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function optionalNumber(value: any): boolean
	return value == nil or finiteNumber(value)
end

local function copyAppearance(value: any): Contestant?
	if
		typeof(value) ~= "table"
		or not validText(value.playerId, 100)
		or not finiteNumber(value.userId)
		or value.userId % 1 ~= 0
		or not validText(value.username, 64)
		or not validText(value.displayName, 64)
		or (value.contribution ~= nil and (not finiteNumber(value.contribution) or value.contribution < 0))
	then
		return nil
	end
	local copied = {
		playerId = value.playerId,
		userId = value.userId,
		username = value.username,
		displayName = value.displayName,
		contribution = value.contribution,
	}
	for _, key in { "teamId", "colorId", "costumeId", "emoteId", "ballId", "hammerId" } do
		if value[key] ~= nil and value[key] ~= "" then
			if not validText(value[key], 100) then
				return nil
			end
			copied[key] = value[key]
		end
	end
	return copied
end

local function copyPodium(value: any): { ShowcaseEntry }?
	if typeof(value) ~= "table" or #value > 3 then
		return nil
	end
	local copied, seen = {}, {}
	for _, item in value do
		local entry: any = copyAppearance(item)
		if
			not entry
			or seen[entry.userId]
			or not finiteNumber(item.score)
			or item.score < 0
			or not finiteNumber(item.placement)
			or item.placement % 1 ~= 0
			or item.placement < 1
			or item.placement > 3
		then
			return nil
		end
		seen[entry.userId] = true
		entry.score = item.score
		entry.placement = item.placement
		table.insert(copied, entry)
	end
	return copied
end

local function copyPresentation(value: any): Presentation?
	if
		typeof(value) ~= "table"
		or not validText(value.eyebrow, 100)
		or not validText(value.title, 100)
		or (value.detail ~= nil and not validText(value.detail, 140))
		or (value.accent ~= "Cyan" and value.accent ~= "Yellow" and value.accent ~= "Pink" and value.accent ~= "Purple")
	then
		return nil
	end
	return {
		eyebrow = value.eyebrow,
		title = value.title,
		detail = value.detail,
		accent = value.accent,
	}
end

local function copyScores(value: any): { ScoreEntry }?
	if typeof(value) ~= "table" or #value > 100 then
		return nil
	end
	local result = {}
	for index = 1, #value do
		local entry = value[index]
		if
			typeof(entry) ~= "table"
			or not validText(entry.id, 100)
			or not validText(entry.label, 100)
			or not finiteNumber(entry.score)
			or (
				entry.placement ~= nil
				and (not finiteNumber(entry.placement) or entry.placement % 1 ~= 0 or entry.placement < 1)
			)
		then
			return nil
		end
		result[index] = {
			id = entry.id,
			label = entry.label,
			score = entry.score,
			placement = entry.placement,
		}
	end
	return result
end

local function copyStats(value: any): { Stat }?
	if typeof(value) ~= "table" or #value > 12 then
		return nil
	end
	local result = {}
	for index = 1, #value do
		local stat = value[index]
		if
			typeof(stat) ~= "table"
			or not validText(stat.id, 64)
			or not validText(stat.label, 100)
			or not finiteNumber(stat.value)
			or (stat.highlight ~= nil and typeof(stat.highlight) ~= "boolean")
		then
			return nil
		end
		result[index] = {
			id = stat.id,
			label = stat.label,
			value = stat.value,
			highlight = stat.highlight,
		}
	end
	return result
end

local function copyRewards(value: any): Rewards?
	if value == nil then
		return nil
	end
	if
		typeof(value) ~= "table"
		or not finiteNumber(value.matchXp)
		or value.matchXp < 0
		or not finiteNumber(value.bonks)
		or value.bonks < 0
		or not optionalNumber(value.seasonXp)
		or not optionalNumber(value.baseXp)
		or not optionalNumber(value.baseBonks)
		or not optionalNumber(value.xpMultiplier)
		or not optionalNumber(value.bonksMultiplier)
	then
		return nil
	end
	return {
		matchXp = value.matchXp,
		seasonXp = value.seasonXp,
		bonks = value.bonks,
		baseXp = value.baseXp,
		baseBonks = value.baseBonks,
		xpMultiplier = value.xpMultiplier,
		bonksMultiplier = value.bonksMultiplier,
	}
end

local function copySeasonProgress(value: any): SeasonProgress?
	if value == nil then
		return nil
	end
	if
		typeof(value) ~= "table"
		or not validText(value.seasonId, 100)
		or not validText(value.displayName, 100)
		or not finiteNumber(value.beforeXp)
		or not finiteNumber(value.afterXp)
		or not finiteNumber(value.beforeTier)
		or not finiteNumber(value.afterTier)
		or not finiteNumber(value.xpIntoTier)
		or not finiteNumber(value.xpForNextTier)
		or value.xpForNextTier <= 0
	then
		return nil
	end
	return {
		seasonId = value.seasonId,
		displayName = value.displayName,
		beforeXp = value.beforeXp,
		afterXp = value.afterXp,
		beforeTier = value.beforeTier,
		afterTier = value.afterTier,
		xpIntoTier = value.xpIntoTier,
		xpForNextTier = value.xpForNextTier,
	}
end

local function copyChallenges(value: any): { ChallengeProgress }?
	if value == nil then
		return nil
	end
	if typeof(value) ~= "table" or #value > 3 then
		return nil
	end
	local result = {}
	for index = 1, #value do
		local challenge = value[index]
		if
			typeof(challenge) ~= "table"
			or not validText(challenge.id, 100)
			or not validText(challenge.label, 100)
			or not finiteNumber(challenge.current)
			or not finiteNumber(challenge.target)
			or challenge.target <= 0
			or (challenge.complete ~= nil and typeof(challenge.complete) ~= "boolean")
		then
			return nil
		end
		result[index] = {
			id = challenge.id,
			label = challenge.label,
			current = challenge.current,
			target = challenge.target,
			complete = challenge.complete,
		}
	end
	return result
end

local function copyUnlocks(value: any): { Unlock }?
	if value == nil then
		return nil
	end
	if typeof(value) ~= "table" or #value > 3 then
		return nil
	end
	local result = {}
	for index = 1, #value do
		local unlock = value[index]
		if
			typeof(unlock) ~= "table"
			or not validText(unlock.id, 100)
			or not validText(unlock.name, 100)
			or not validText(unlock.kind, 64)
			or (unlock.thumbnail ~= nil and not validText(unlock.thumbnail, 200))
		then
			return nil
		end
		result[index] = {
			id = unlock.id,
			name = unlock.name,
			kind = unlock.kind,
			thumbnail = unlock.thumbnail,
		}
	end
	return result
end

local function copyParty(value: any): Party?
	if value == nil then
		return nil
	end
	if
		typeof(value) ~= "table"
		or not validText(value.partyId, 100)
		or not finiteNumber(value.leaderUserId)
		or value.leaderUserId % 1 ~= 0
		or value.leaderUserId <= 0
		or typeof(value.members) ~= "table"
		or #value.members == 0
		or #value.members > 16
	then
		return nil
	end
	local members = {}
	local hasLeader = false
	for index = 1, #value.members do
		local member = value.members[index]
		if
			typeof(member) ~= "table"
			or not finiteNumber(member.userId)
			or member.userId % 1 ~= 0
			or member.userId <= 0
			or not validText(member.username, 64)
			or not validText(member.displayName, 64)
			or typeof(member.isLeader) ~= "boolean"
			or typeof(member.isLocal) ~= "boolean"
			or typeof(member.present) ~= "boolean"
		then
			return nil
		end
		hasLeader = hasLeader or member.userId == value.leaderUserId
		members[index] = {
			userId = member.userId,
			username = member.username,
			displayName = member.displayName,
			isLeader = member.isLeader,
			isLocal = member.isLocal,
			present = member.present,
		}
	end
	if not hasLeader then
		return nil
	end
	return {
		partyId = value.partyId,
		leaderUserId = value.leaderUserId,
		members = members,
	}
end

function PostMatchResult.parse(value: any): (PlayerResult?, string?)
	if typeof(value) ~= "table" then
		return nil, "missing_payload"
	end
	if value.schemaVersion ~= PostMatchResult.SchemaVersion then
		return nil, "unsupported_schema"
	end
	if
		not validText(value.resultId, 100)
		or not validText(value.modeId, 32)
		or not validText(value.modeName, 64)
		or (value.outcome ~= "Victory" and value.outcome ~= "Defeat" and value.outcome ~= "RoundOver")
		or not finiteNumber(value.interactiveAt)
		or not finiteNumber(value.endsAt)
		or value.endsAt < value.interactiveAt
		or (value.winnerId ~= nil and not validText(value.winnerId, 100))
		or (value.placement ~= nil and (not finiteNumber(value.placement) or value.placement % 1 ~= 0 or value.placement < 1))
		or (value.firstMatch ~= nil and typeof(value.firstMatch) ~= "boolean")
		or (value.rewardsPending ~= nil and typeof(value.rewardsPending) ~= "boolean")
	then
		return nil, "invalid_payload"
	end

	local copiedPresentation = copyPresentation(value.presentation)
	local copiedScores = copyScores(value.scores)
	local copiedStats = copyStats(value.personalStats)
	local copiedRewards = copyRewards(value.rewards)
	local copiedSeason = copySeasonProgress(value.seasonProgress)
	local copiedChallenges = copyChallenges(value.challenges)
	local copiedUnlocks = copyUnlocks(value.unlocks)
	local copiedParty = copyParty(value.party)
	local copiedPodium = if value.podium ~= nil then copyPodium(value.podium) else nil
	local copiedAppearance = if value.personalAppearance ~= nil then copyAppearance(value.personalAppearance) else nil
	if
		copiedPresentation == nil
		or copiedScores == nil
		or copiedStats == nil
		or (value.rewards ~= nil and copiedRewards == nil)
		or (value.seasonProgress ~= nil and copiedSeason == nil)
		or (value.challenges ~= nil and copiedChallenges == nil)
		or (value.unlocks ~= nil and copiedUnlocks == nil)
		or (value.party ~= nil and copiedParty == nil)
		or (value.podium ~= nil and copiedPodium == nil)
		or (value.personalAppearance ~= nil and copiedAppearance == nil)
	then
		return nil, "invalid_payload"
	end

	return {
		schemaVersion = PostMatchResult.SchemaVersion,
		resultId = value.resultId,
		modeId = value.modeId,
		modeName = value.modeName,
		outcome = value.outcome,
		firstMatch = value.firstMatch,
		rewardsPending = value.rewardsPending,
		winnerId = value.winnerId,
		placement = value.placement,
		interactiveAt = value.interactiveAt,
		endsAt = value.endsAt,
		presentation = copiedPresentation,
		scores = copiedScores,
		personalStats = copiedStats,
		podium = copiedPodium,
		personalAppearance = copiedAppearance,
		rewards = copiedRewards,
		seasonProgress = copiedSeason,
		challenges = copiedChallenges,
		unlocks = copiedUnlocks,
		party = copiedParty,
	},
		nil
end

return table.freeze(PostMatchResult)
