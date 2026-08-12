--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Maps = require(Config:WaitForChild("Maps"))
local DataConfig = require(Config:WaitForChild("Data"))
local UIConfig = require(Config:WaitForChild("UI"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModeRegistry = require(Shared:WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeRegistry"))
local PlayerIds = require(Shared:WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("PlayerIds"))
local Network = require(Shared:WaitForChild("Network"))

-- Drives match phase, voting, respawn timing, combat feed, and results from
-- their replicated server-owned state.

local MatchHud = {}

type VoteOption = {
	button: TextButton,
	mode: TextLabel,
	map: TextLabel,
	count: TextLabel,
	gradient: UIGradient,
	outline: UIStroke,
	scale: UIScale,
	thumbnail: ImageLabel,
	previewFallback: Frame,
	previewHint: TextLabel,
	modeBacking: Frame,
	modeGradient: UIGradient,
	selected: TextLabel,
}

type FlowRefs = {
	respawn: TextLabel,
	tutorial: TextLabel,
	feed: { TextLabel },
	vote: Frame,
	voteTimer: TextLabel,
	voteProgress: Frame,
	options: { VoteOption },
	summary: Frame,
	summaryTitle: TextLabel,
	summaryStats: TextLabel,
	summaryRewards: TextLabel,
}

type Summary = {
	won: boolean,
	elims: number,
	deaths: number,
	catches: number,
	xp: number,
	cash: number,
	baseXp: number?,
	baseCash: number?,
	xpMultiplier: number?,
	cashMultiplier: number?,
}

type FeedEntry = {
	text: string,
	expiresAt: number,
}

local feedEntries: { FeedEntry } = {}
local latestSummary: Summary? = nil

local function childOfClass(parent: Instance, name: string, className: string): any
	local child = parent:WaitForChild(name)
	assert(child:IsA(className), `[MatchHud] {parent.Name}.{name} must be a {className}`)
	return child
end

local function resolveLabel(instance: Instance): TextLabel
	if instance:IsA("TextLabel") then
		return instance
	end
	local label = instance:FindFirstChildWhichIsA("TextLabel", true)
	assert(label, `[MatchHud] {instance:GetFullName()} must be or contain a TextLabel`)
	return label
end

local function resolveFlow(hud: Instance): FlowRefs
	local root = childOfClass(hud, "MatchFlow", "Frame") :: Frame
	local vote = childOfClass(root, "Vote", "Frame") :: Frame
	local optionsRoot = childOfClass(vote, "Options", "Frame") :: Frame
	local options = {}
	for index = 1, Maps.Voting.CandidateCount do
		local button = childOfClass(optionsRoot, `Option{index}`, "TextButton") :: TextButton
		local gradient = childOfClass(button, "ColorWash", "UIGradient") :: UIGradient
		table.insert(options, {
			button = button,
			mode = childOfClass(button, "Mode", "TextLabel") :: TextLabel,
			map = childOfClass(button, "Map", "TextLabel") :: TextLabel,
			count = childOfClass(button, "Count", "TextLabel") :: TextLabel,
			gradient = gradient,
			outline = childOfClass(button, "Outline", "UIStroke") :: UIStroke,
			scale = childOfClass(button, "Scale", "UIScale") :: UIScale,
			thumbnail = childOfClass(button, "Thumbnail", "ImageLabel") :: ImageLabel,
			previewFallback = childOfClass(button, "PreviewFallback", "Frame") :: Frame,
			previewHint = childOfClass(button, "PreviewHint", "TextLabel") :: TextLabel,
			modeBacking = childOfClass(button, "ModeBacking", "Frame") :: Frame,
			modeGradient = childOfClass(childOfClass(button, "ModeBacking", "Frame"), "ColorWash", "UIGradient") :: UIGradient,
			selected = childOfClass(button, "Selected", "TextLabel") :: TextLabel,
		})
	end
	local feedRoot = childOfClass(root, "CombatFeed", "Frame") :: Frame
	local feed = {}
	for index = 1, 3 do
		table.insert(feed, childOfClass(feedRoot, `Line{index}`, "TextLabel") :: TextLabel)
	end
	local summary = childOfClass(root, "Summary", "Frame") :: Frame
	return {
		respawn = childOfClass(root, "Respawn", "TextLabel") :: TextLabel,
		tutorial = childOfClass(root, "Tutorial", "TextLabel") :: TextLabel,
		feed = feed,
		vote = vote,
		voteTimer = childOfClass(vote, "Timer", "TextLabel") :: TextLabel,
		voteProgress = childOfClass(childOfClass(vote, "ProgressTrack", "Frame"), "ProgressFill", "Frame") :: Frame,
		options = options,
		summary = summary,
		summaryTitle = childOfClass(summary, "Title", "TextLabel") :: TextLabel,
		summaryStats = childOfClass(summary, "Stats", "TextLabel") :: TextLabel,
		summaryRewards = childOfClass(summary, "Rewards", "TextLabel") :: TextLabel,
	}
end

local function formatTime(seconds: number): string
	local whole = math.max(math.floor(seconds + 0.5), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function displayName(playerId: string?): string
	if playerId == nil or playerId == "" then
		return "Arena"
	end
	local player = PlayerIds.fromId(playerId)
	return if player then player.DisplayName else playerId
end

local function mapEntry(mapId: string): Maps.MapEntry?
	for _, entry in Maps.Pool do
		if entry.Id == mapId then
			return entry
		end
	end
	return nil
end

local function winnerText(winnerId: string): string
	return if winnerId == "" then "Tie game!" else `{displayName(winnerId)} wins!`
end

local function feedText(event: { [string]: any }): string
	local source = displayName(event.sourceId :: string?)
	local target = displayName(event.targetId :: string?)
	if event.kind == "BallCaught" then
		return `{source} caught {target}’s ball`
	elseif event.sourceId == nil then
		return `{target} was splatted`
	elseif event.projectileId ~= nil then
		return `{source} splatted {target}`
	end
	return `{source} bonked {target}`
end

function MatchHud.start()
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("Hud")
	local top = hud:WaitForChild("Top")
	local roundLabel = resolveLabel(top:WaitForChild("Round"))
	local timerLabel = resolveLabel(top:WaitForChild("Timer"))
	local flow = resolveFlow(hud)
	local matchState = ReplicatedStorage:WaitForChild("MatchState")
	local balls = Workspace:WaitForChild("Balls")
	assert(balls:IsA("Folder"), "[MatchHud] Workspace.Balls must be a Folder")
	local localPlayerId = PlayerIds.toId(localPlayer)

	for index, option in flow.options do
		local optionIndex = index
		option.button.Activated:Connect(function()
			Network.fireServer("SubmitMatchVote", optionIndex)
		end)
	end

	local function refreshVote()
		local phase = matchState:GetAttribute("phase")
		local open = matchState:GetAttribute("voteOpen") == true and phase == "Intermission"
		flow.vote.Visible = open
		local selected = localPlayer:GetAttribute("MatchVoteOption") :: number?
		for index, option in flow.options do
			local modeId = (matchState:GetAttribute(`Vote{index}ModeId`) :: string?) or ""
			local mapId = (matchState:GetAttribute(`Vote{index}MapId`) :: string?) or ""
			local count = (matchState:GetAttribute(`Vote{index}Count`) :: number?) or 0
			local candidateMode = ModeRegistry.get(modeId)
			local candidateMap = mapEntry(mapId)
			local available = candidateMode ~= nil and candidateMap ~= nil
			local thumbnail = if candidateMap then candidateMap.Thumbnail else ""
			local isSelected = selected == index
			option.button.Visible = available
			option.button.Active = available
			option.button.Selectable = available
			option.mode.Text = string.upper(modeId)
			option.map.Text = if candidateMap then candidateMap.DisplayName else mapId
			option.count.Text = if count == 0 then "BE FIRST" else if count == 1 then "1 VOTE" else `{count} VOTES`
			option.thumbnail.Image = thumbnail
			option.thumbnail.Visible = thumbnail ~= ""
			option.previewFallback.Visible = thumbnail == ""
			option.previewHint.Visible = thumbnail == ""
			option.selected.Visible = isSelected
			option.scale.Scale = if isSelected then 1.025 else 1
			option.outline.Color = if isSelected then UIConfig.Hud.MatchVote.Selected else Color3.fromRGB(29, 25, 38)
			option.outline.Thickness = if isSelected then 5 else 3.5
			option.gradient.Color = if isSelected
				then ColorSequence.new(Color3.fromRGB(205, 255, 172), Color3.fromRGB(75, 211, 147))
				else ColorSequence.new(Color3.fromRGB(255, 245, 209), Color3.fromRGB(237, 177, 105))
			local modeTheme = UIConfig.Hud.MatchVote.Modes[modeId]
			if modeTheme then
				option.modeBacking.BackgroundColor3 = modeTheme.Bottom
				option.modeGradient.Color = ColorSequence.new(modeTheme.Top, modeTheme.Bottom)
			end
		end
	end

	local function refreshSummary(phase: any)
		local summary = latestSummary
		flow.summary.Visible = phase == "Results" and summary ~= nil
		if summary == nil then
			return
		end
		flow.summaryTitle.Text = if summary.won then "VICTORY!" else "MATCH COMPLETE"
		flow.summaryStats.Text = `{summary.elims} ELIMS  •  {summary.catches} CATCHES  •  {summary.deaths} FALLS`
		-- Name the multiplier only when it actually changed the payout, so a
		-- boost the player paid for is visible at the moment it pays out.
		local xpText = `+{summary.xp} XP`
		if summary.xpMultiplier ~= nil and summary.xpMultiplier > 1 and summary.xp ~= summary.baseXp then
			xpText ..= ` ({summary.xpMultiplier}x)`
		end
		local cashText = `+{summary.cash} CASH`
		if summary.cashMultiplier ~= nil and summary.cashMultiplier > 1 and summary.cash ~= summary.baseCash then
			cashText ..= ` ({summary.cashMultiplier}x)`
		end
		flow.summaryRewards.Text = `{xpText}  •  {cashText}`
	end

	local function refresh()
		local phase = matchState:GetAttribute("phase")
		if phase == "Starting" then
			latestSummary = nil
		end
		local timeRemaining = (matchState:GetAttribute("timeRemaining") :: number?) or 0
		local winnerId = (matchState:GetAttribute("winnerId") :: string?) or ""
		local modeId = (matchState:GetAttribute("modeId") :: string?) or ""
		local currentMode = ModeRegistry.get(modeId) or ModeRegistry.default()

		if phase == "Starting" then
			roundLabel.Text = string.format("%s on deck", currentMode.displayName)
			timerLabel.Text = tostring(math.max(math.ceil(timeRemaining), 1))
		elseif phase == "Active" then
			roundLabel.Text = `First to {currentMode.rules.ScoreTarget}`
			timerLabel.Text = formatTime(timeRemaining)
		elseif phase == "Results" then
			roundLabel.Text = winnerText(winnerId)
			timerLabel.Text = "--:--"
		elseif phase == "Intermission" then
			roundLabel.Text = "Choose the next match"
			timerLabel.Text = formatTime(timeRemaining)
		else
			roundLabel.Text = "Waiting for players…"
			timerLabel.Text = "--:--"
		end
		refreshVote()
		refreshSummary(phase)
	end

	Network.on("CombatFeed", function(event)
		table.insert(feedEntries, 1, {
			text = feedText(event),
			expiresAt = os.clock() + 4,
		})
		while #feedEntries > #flow.feed do
			table.remove(feedEntries)
		end
	end)
	Network.on("MatchSummary", function(summary)
		latestSummary = summary :: Summary
		refreshSummary(matchState:GetAttribute("phase"))
	end)

	matchState.AttributeChanged:Connect(refresh)
	localPlayer:GetAttributeChangedSignal("MatchVoteOption"):Connect(refreshVote)
	RunService.RenderStepped:Connect(function()
		local tutorialVersion = localPlayer:GetAttribute("TutorialVersion") :: number?
		local tutorialActive = tutorialVersion ~= nil and tutorialVersion < DataConfig.TutorialVersion
		local phase = matchState:GetAttribute("phase")
		flow.tutorial.Visible = tutorialActive and (phase == "Starting" or phase == "Active")
		if flow.tutorial.Visible then
			local hasHeldBall = false
			for _, ball in balls:GetChildren() do
				if ball:IsA("BasePart") and ball:GetAttribute("hb") == localPlayerId then
					hasHeldBall = true
					break
				end
			end
			if phase == "Starting" then
				flow.tutorial.Text = "MOVE, AIM, AND PROTECT YOUR BALL"
			elseif hasHeldBall then
				flow.tutorial.Text = "AIM AND THROW • CATCH INCOMING BALLS"
			else
				flow.tutorial.Text = "RUN OVER A RESTING BALL TO PICK IT UP • TIME YOUR CATCH"
			end
		end

		local respawnAt = localPlayer:GetAttribute("MatchRespawnAt") :: number?
		local remaining = if respawnAt then respawnAt - Workspace:GetServerTimeNow() else 0
		flow.respawn.Visible = remaining > 0 and matchState:GetAttribute("phase") == "Active"
		if flow.respawn.Visible then
			flow.respawn.Text = string.format("RESPAWNING IN %.1f", math.max(remaining, 0))
		end

		if flow.vote.Visible then
			local voteEndsAt = (matchState:GetAttribute("voteEndsAt") :: number?) or 0
			local voteRemaining = math.max(voteEndsAt - Workspace:GetServerTimeNow(), 0)
			flow.voteTimer.Text = `{math.ceil(voteRemaining)} SEC`
			flow.voteProgress.Size = UDim2.fromScale(math.clamp(voteRemaining / Maps.Voting.DurationSeconds, 0, 1), 1)
		end

		local now = os.clock()
		for index, label in flow.feed do
			local entry = feedEntries[index]
			label.Visible = entry ~= nil and entry.expiresAt > now
			label.Text = if entry then entry.text else ""
		end
	end)
	refresh()
end

return MatchHud
