--!strict

-- Renders compact in-match FFA leaders or mirrored TDM team standings from
-- MatchState and each player's replicated MatchScore and TeamId attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveScoreboardModel = require(script.Parent.LiveScoreboardModel)
local ModeRegistry = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeRegistry")
)
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"))

local LiveScoreboardController = {}

type RowRefs = {
	root: Frame,
	rank: TextLabel,
	playerName: TextLabel,
	score: TextLabel,
	youPill: Frame,
	fill: Frame,
}

type TeamRefs = {
	root: Frame,
	teamName: TextLabel,
	score: TextLabel,
	target: TextLabel,
	fill: Frame,
	rows: { RowRefs },
}

type ViewRefs = {
	root: CanvasGroup,
	title: TextLabel,
	goal: TextLabel,
	ffa: Frame,
	ffaRows: { RowRefs },
	localRow: RowRefs,
	teams: Frame,
	teamSlots: { TeamRefs },
}

local started = false
local matchState: Instance? = nil
local refs: ViewRefs? = nil
local connections: { RBXScriptConnection } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local teamHighlights: { [Player]: Highlight } = {}

local TEAM_COLORS = UIConfig.Hud.LiveScoreboard.TeamColors

local function frameChild(parent: Instance, name: string): Frame
	local child = parent:WaitForChild(name)
	assert(child:IsA("Frame"), `[LiveScoreboardController] {parent.Name}.{name} must be a Frame`)
	return child
end

local function textChild(parent: Instance, name: string): TextLabel
	local child = parent:WaitForChild(name)
	assert(child:IsA("TextLabel"), `[LiveScoreboardController] {parent.Name}.{name} must be a TextLabel`)
	return child
end

local function resolveRow(row: Frame): RowRefs
	local bubble = frameChild(frameChild(row, "RankMount"), "Bubble")
	local progress = frameChild(row, "Progress")
	return {
		root = row,
		rank = textChild(bubble, "Rank"),
		playerName = textChild(row, "PlayerName"),
		score = textChild(row, "Score"),
		youPill = frameChild(row, "YouPill"),
		fill = frameChild(progress, "Fill"),
	}
end

local function resolveTeam(team: Frame): TeamRefs
	local rowHolder = frameChild(team, "Rows")
	local rows = {}
	for index = 1, UIConfig.Hud.LiveScoreboard.TeamRows do
		table.insert(rows, resolveRow(frameChild(rowHolder, `Row{index}`)))
	end
	return {
		root = team,
		teamName = textChild(team, "TeamName"),
		score = textChild(team, "Score"),
		target = textChild(team, "Target"),
		fill = frameChild(frameChild(team, "Progress"), "Fill"),
		rows = rows,
	}
end

local function resolveView(): ViewRefs
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local view = playerGui:WaitForChild("Hud"):WaitForChild("LiveScoreboard")
	assert(view:IsA("CanvasGroup"), "[LiveScoreboardController] Hud.LiveScoreboard must be a CanvasGroup")
	local shell = frameChild(view, "Shell")
	local header = frameChild(shell, "Header")
	local ffa = frameChild(shell, "FFA")
	local ffaRows = {}
	for index = 1, UIConfig.Hud.LiveScoreboard.FfaRows do
		table.insert(ffaRows, resolveRow(frameChild(ffa, `Row{index}`)))
	end
	local teams = frameChild(shell, "Teams")
	return {
		root = view,
		title = textChild(header, "Title"),
		goal = textChild(header, "Goal"),
		ffa = ffa,
		ffaRows = ffaRows,
		localRow = resolveRow(frameChild(ffa, "LocalRow")),
		teams = teams,
		teamSlots = {
			resolveTeam(frameChild(teams, "TeamA")),
			resolveTeam(frameChild(teams, "TeamB")),
		},
	}
end

local function entries(): { LiveScoreboardModel.Entry }
	local result = {}
	for _, player in Players:GetPlayers() do
		table.insert(result, {
			userId = player.UserId,
			displayName = player.DisplayName,
			score = (player:GetAttribute("MatchScore") :: number?) or 0,
			teamId = player:GetAttribute("TeamId") :: string?,
			isLocal = player == Players.LocalPlayer,
		})
	end
	return result
end

local function renderRow(row: RowRefs, entry: LiveScoreboardModel.RankedEntry?, target: number)
	row.root.Visible = entry ~= nil
	if entry == nil then
		return
	end
	row.rank.Text = tostring(entry.rank)
	row.playerName.Text = entry.displayName
	row.score.Text = tostring(entry.score)
	row.youPill.Visible = entry.isLocal
	row.fill.Size = UDim2.fromScale(math.clamp(entry.score / math.max(target, 1), 0, 1), 1)
end

local function renderFfa(view: ViewRefs, target: number)
	local model = LiveScoreboardModel.ffa(entries(), UIConfig.Hud.LiveScoreboard.FfaRows)
	view.ffa.Visible = true
	view.teams.Visible = false
	view.title.Text = "SCOREBOARD"
	view.goal.Text = `FIRST TO {target}`
	for index, row in view.ffaRows do
		renderRow(row, model.rows[index], target)
	end
	renderRow(view.localRow, model.localRow, target)
end

local function renderTeam(view: ViewRefs, target: number, teamIds: { string }, state: Instance)
	assert(#teamIds == 2, "[LiveScoreboardController] the in-match team HUD requires exactly two teams")
	local scores = {}
	for _, teamId in teamIds do
		scores[teamId] = (state:GetAttribute(`TeamScore_{teamId}`) :: number?) or 0
	end
	local model = LiveScoreboardModel.teams(entries(), teamIds, scores, UIConfig.Hud.LiveScoreboard.TeamRows)
	view.ffa.Visible = false
	view.teams.Visible = true
	view.title.Text = "TEAM SCORE"
	view.goal.Text = `FIRST TO {target}`
	for index, team in model.teams do
		local slot = view.teamSlots[index]
		slot.root.Visible = true
		slot.teamName.Text = string.upper(team.id)
		slot.score.Text = tostring(team.score)
		slot.target.Text = `/ {target}`
		slot.fill.Size = UDim2.fromScale(math.clamp(team.score / math.max(target, 1), 0, 1), 1)
		for rowIndex, row in slot.rows do
			renderRow(row, team.rows[rowIndex], target)
		end
	end
end

local function clearTeamHighlight(player: Player)
	local highlight = teamHighlights[player]
	if highlight then
		highlight:Destroy()
		teamHighlights[player] = nil
	end
end

local function renderTeamHighlights(active: boolean, isTeamMode: boolean)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local color = TEAM_COLORS[player:GetAttribute("TeamId") :: string]
		if not active or not isTeamMode or character == nil or color == nil then
			clearTeamHighlight(player)
			continue
		end
		local highlight = teamHighlights[player]
		if highlight == nil or highlight.Parent ~= character then
			clearTeamHighlight(player)
			highlight = Instance.new("Highlight")
			highlight.Name = "MatchTeamOutline"
			highlight.Adornee = character
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.FillTransparency = 0.92
			highlight.OutlineTransparency = 0.12
			highlight.Parent = character
			teamHighlights[player] = highlight
		end
		highlight.FillColor = color
		highlight.OutlineColor = color
	end
end

local function render()
	local view = refs
	local state = matchState
	if view == nil or state == nil then
		return
	end
	local active = state:GetAttribute("phase") == "Active"
	view.root.Visible = active
	if not active then
		renderTeamHighlights(false, false)
		return
	end

	local modeId = (state:GetAttribute("modeId") :: string?) or ""
	local mode = ModeRegistry.get(modeId) or ModeRegistry.default()
	local target = mode.rules.ScoreTarget
	renderTeamHighlights(active, mode.scoreScope == "Team")
	if mode.scoreScope == "Team" then
		renderTeam(view, target, mode.teams or {}, state)
	else
		renderFfa(view, target)
	end
end

local function disconnectPlayer(player: Player)
	clearTeamHighlight(player)
	local list = playerConnections[player]
	if list then
		for _, connection in list do
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end
end

local function connectPlayer(player: Player)
	disconnectPlayer(player)
	local list = {
		player:GetAttributeChangedSignal("MatchScore"):Connect(render),
		player:GetAttributeChangedSignal("TeamId"):Connect(render),
		player:GetPropertyChangedSignal("DisplayName"):Connect(render),
		player.CharacterAdded:Connect(function()
			task.defer(render)
		end),
	}
	playerConnections[player] = list
end

function LiveScoreboardController.start()
	if started then
		return
	end
	started = true
	refs = resolveView()
	matchState = ReplicatedStorage:WaitForChild("MatchState")

	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
	table.insert(
		connections,
		Players.PlayerAdded:Connect(function(player)
			connectPlayer(player)
			render()
		end)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			disconnectPlayer(player)
			render()
		end)
	)
	table.insert(
		connections,
		(matchState :: Instance).AttributeChanged:Connect(function(name)
			if name == "phase" or name == "modeId" or string.sub(name, 1, 10) == "TeamScore_" then
				render()
			end
		end)
	)
	render()
end

function LiveScoreboardController._resetForTest()
	for _, connection in connections do
		connection:Disconnect()
	end
	for player in playerConnections do
		disconnectPlayer(player)
	end
	started = false
	matchState = nil
	refs = nil
	connections = {}
	playerConnections = {}
	teamHighlights = {}
end

return LiveScoreboardController
