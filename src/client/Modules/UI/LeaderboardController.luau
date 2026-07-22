--!strict

-- Renders the top five replicated post-match standings and opens the
-- breakdown when MatchState enters Results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ElementFactory = require(script.Parent.Elements.ElementFactory)
local LeaderboardStandings = require(script.Parent.LeaderboardStandings)
local TextSizer = require(script.Parent.TextSizer)
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"))

local LeaderboardController = {}

local BADGE_IMAGES = {
	"rbxassetid://99467401523835",
	"rbxassetid://95580680941340",
	"rbxassetid://109094401709272",
	"rbxassetid://128688142572243",
	"rbxassetid://134936559641075",
}

local started = false
local holder: ScrollingFrame? = nil
local statusLabel: TextLabel? = nil
local matchState: Instance? = nil
local activePlayers: any = Players
local activeMenuManager: any = nil
local handles: { any } = {}
local connections: { RBXScriptConnection } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local lastPhase: any = nil

local function resolveMenuManager(): any
	return require(script.Parent.MenuManager)
end

local function resolveView(): (ScrollingFrame, TextLabel)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local view =
		playerGui:WaitForChild("MainGui"):WaitForChild("BaseClip"):WaitForChild("Views"):WaitForChild("Leaderboard")
	assert(view:IsA("CanvasGroup"), "[LeaderboardController] Views.Leaderboard must be a CanvasGroup")
	local holderInstance = view:WaitForChild("Holder")
	local statusInstance = view:WaitForChild("Status")
	assert(
		holderInstance:IsA("ScrollingFrame"),
		"[LeaderboardController] Views.Leaderboard.Holder must be a ScrollingFrame"
	)
	assert(statusInstance:IsA("TextLabel"), "[LeaderboardController] Views.Leaderboard.Status must be a TextLabel")
	return holderInstance, statusInstance
end

local function textChild(parent: Instance, name: string): TextLabel
	local child = parent:WaitForChild(name)
	assert(child:IsA("TextLabel"), `[LeaderboardController] LeaderboardRow.{name} must be a TextLabel`)
	return child
end

local function destroyRows()
	for _, handle in handles do
		handle:destroy()
	end
	table.clear(handles)
end

local function elimsFor(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local elims = if leaderstats then leaderstats:FindFirstChild("Elims") else nil
	return if elims and elims:IsA("IntValue") then elims.Value else 0
end

local function entries(): { LeaderboardStandings.Entry }
	local result = {}
	for _, player in activePlayers:GetPlayers() do
		table.insert(result, {
			userId = player.UserId,
			displayName = player.DisplayName,
			score = (player:GetAttribute("MatchScore") :: number?) or 0,
			elims = elimsFor(player),
		})
	end
	return LeaderboardStandings.sorted(result)
end

local function mountRow(entry: LeaderboardStandings.Entry, rank: number)
	local template = ElementFactory.resolveTemplate("LeaderboardRow", "ImageLabel") :: ImageLabel
	local row, handle = ElementFactory.cloneMount(template, holder :: ScrollingFrame)
	row.Name = `LeaderboardRow_{entry.userId}`
	row.LayoutOrder = rank
	row.Rotation = 0
	row.Visible = true

	local badge = row:WaitForChild("RankBadge")
	assert(badge:IsA("ImageLabel"), "[LeaderboardController] LeaderboardRow.RankBadge must be an ImageLabel")
	badge.Image = BADGE_IMAGES[rank]
	badge.Rotation = 0
	local playerName = textChild(row, "PlayerName")
	local scoreCaption = textChild(row, "ScoreCaption")
	local score = textChild(row, "Score")
	local elims = textChild(row, "Elims")
	for _, label in { playerName, scoreCaption, score, elims } do
		label.FontFace = UIConfig.Text.DefaultFont
		label.TextScaled = false
	end
	playerName.Text = entry.displayName
	score.Text = tostring(entry.score)
	elims.Text = `{entry.elims} elims`
	handle:add(TextSizer.bind(playerName, playerName, { minSize = 13, maxSize = 23, padding = { x = 4, y = 2 } }))
	handle:add(TextSizer.bind(scoreCaption, scoreCaption, { minSize = 9, maxSize = 14, padding = { x = 4, y = 2 } }))
	handle:add(TextSizer.bind(score, score, { minSize = 14, maxSize = 24, padding = { x = 4, y = 2 } }))
	handle:add(TextSizer.bind(elims, elims, { minSize = 10, maxSize = 17, padding = { x = 4, y = 2 } }))
	table.insert(handles, handle)
end

local function render()
	destroyRows()
	local state = matchState
	if state == nil or holder == nil or statusLabel == nil then
		return
	end
	if state:GetAttribute("phase") ~= "Results" then
		statusLabel.Text = "Results appear after each match"
		return
	end

	local standings = entries()
	statusLabel.Text = if #standings == 0 then "No match results" else "Final standings"
	for rank = 1, math.min(#standings, #BADGE_IMAGES) do
		mountRow(standings[rank], rank)
	end
end

local function disconnectPlayer(player: Player)
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
	local list = {}
	playerConnections[player] = list
	table.insert(list, player:GetAttributeChangedSignal("MatchScore"):Connect(render))

	local function connectElims(leaderstats: Instance)
		local elims = leaderstats:FindFirstChild("Elims")
		if elims and elims:IsA("IntValue") then
			table.insert(list, elims.Changed:Connect(render))
		end
		table.insert(
			list,
			leaderstats.ChildAdded:Connect(function(child)
				if child.Name == "Elims" and child:IsA("IntValue") then
					table.insert(list, child.Changed:Connect(render))
					render()
				end
			end)
		)
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		connectElims(leaderstats)
	end
	table.insert(
		list,
		player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				connectElims(child)
				render()
			end
		end)
	)
end

local function onPhaseChanged()
	local state = matchState
	if state == nil then
		return
	end
	local phase = state:GetAttribute("phase")
	render()
	if phase == "Results" and lastPhase ~= "Results" and not activeMenuManager.isOpen("Leaderboard") then
		activeMenuManager.open("Leaderboard")
	end
	lastPhase = phase
end

function LeaderboardController.start()
	if started then
		return
	end
	started = true
	activeMenuManager = resolveMenuManager()
	holder, statusLabel = resolveView()
	matchState = ReplicatedStorage:WaitForChild("MatchState")

	for _, player in activePlayers:GetPlayers() do
		connectPlayer(player)
	end
	table.insert(
		connections,
		activePlayers.PlayerAdded:Connect(function(player)
			connectPlayer(player)
			render()
		end)
	)
	table.insert(
		connections,
		activePlayers.PlayerRemoving:Connect(function(player)
			disconnectPlayer(player)
			render()
		end)
	)
	table.insert(connections, (matchState :: Instance):GetAttributeChangedSignal("phase"):Connect(onPhaseChanged))
	onPhaseChanged()
end

function LeaderboardController._resetForTest()
	for _, connection in connections do
		connection:Disconnect()
	end
	for player in playerConnections do
		disconnectPlayer(player)
	end
	destroyRows()
	started = false
	holder = nil
	statusLabel = nil
	matchState = nil
	activePlayers = Players
	activeMenuManager = nil
	connections = {}
	playerConnections = {}
	lastPhase = nil
end

return LeaderboardController
