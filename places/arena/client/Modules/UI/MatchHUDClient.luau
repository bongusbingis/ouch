-- Reads authoritative match projections and owns only the custom scoreboard's open state and input lifecycle.
--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))
local Model = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Models"):WaitForChild("MatchHUDModel")
)
local ModeRegistry = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeRegistry")
)

-- Hold Tab / ButtonSelect (Input.Hints.Scores); the Scores button shows the same binding.
local SCORES_BINDING =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Input")).Hints.Scores
local MatchHUDClient = {}
local snapshot: any = Model.build({}, 0)
local listeners: { (any) -> () } = {}
local connection: RBXScriptConnection? = nil
local focusConnection: RBXScriptConnection? = nil
local textFocusConnection: RBXScriptConnection? = nil
local eventConnections: { RBXScriptConnection } = {}
local characterConnections: { RBXScriptConnection } = {}
local memberConnections: { [Player]: RBXScriptConnection } = {}
local scoreboardOpen = false
local available = false
local action = "ArenaScoreboard"
local pendingUpdate = false

local function update()
	local player = Players.LocalPlayer
	local state = ReplicatedStorage:FindFirstChild("MatchState")
	if state == nil then
		return
	end
	local modeId = state:GetAttribute("modeId")
	local mode = GameModes.Modes[modeId]
	-- Team identity comes from the mode's own roster, not from two hardcoded
	-- attribute names: a mode whose sides are Survivors and Infected has to reach
	-- the HUD as those, and every team-scoped element reads them from here.
	local teams = nil
	if state:GetAttribute("scoreScope") == "Team" then
		local definition = if typeof(modeId) == "string" then ModeRegistry.get(modeId) else nil
		local teamIds = if definition then definition.teams else nil
		if teamIds then
			teams = {}
			for _, teamId in teamIds do
				table.insert(teams, { id = teamId, score = state:GetAttribute(`TeamScore_{teamId}`) or 0 })
			end
		end
	end
	local character = player.Character
	local players = {}
	for _, member in Players:GetPlayers() do
		if member:GetAttribute("ArenaRoundEligible") == true then
			local head = if member.Character then member.Character:FindFirstChild("Head") else nil
			table.insert(players, {
				userId = member.UserId,
				displayName = member.DisplayName,
				score = member:GetAttribute("MatchScore") or 0,
				teamId = member:GetAttribute("TeamId"),
				isLocal = member == player,
				alive = member.Character ~= nil and member.Character:GetAttribute("CombatAlive") ~= false,
				head = if head and head:IsA("BasePart") then head else nil,
			})
		end
	end
	snapshot = Model.build({
		phase = state:GetAttribute("phase"),
		title = if mode then mode.Title else "MATCH",
		timeRemaining = state:GetAttribute("timeRemaining"),
		scoreTarget = state:GetAttribute("scoreTarget"),
		scoreLabel = GameModes.ScoreLabel(modeId),
		combat = GameModes.IsCombat(modeId),
		teams = teams,
		score = player:GetAttribute("MatchScore"),
		teamId = player:GetAttribute("TeamId"),
		eligible = player:GetAttribute("ArenaRoundEligible"),
		rewardsRecovery = player:GetAttribute("RewardsRecoveryPending") == true,
		alive = character ~= nil and character:GetAttribute("CombatAlive") ~= false,
		respawnAt = player:GetAttribute("MatchRespawnAt"),
		spawnProtected = character ~= nil and character:GetAttribute("minv") == true,
		opponentDeadline = state:GetAttribute("opponentDeadline"),
		players = players,
		scoreboardOpen = scoreboardOpen,
	}, Workspace:GetServerTimeNow())
	for _, listener in table.clone(listeners) do
		pcall(listener, snapshot)
	end
end

local function scheduleUpdate()
	if pendingUpdate then
		return
	end
	pendingUpdate = true
	task.defer(function()
		pendingUpdate = false
		update()
	end)
end

local function hookMember(member: Player)
	if memberConnections[member] then
		return
	end
	memberConnections[member] = member.AttributeChanged:Connect(function(name)
		if
			name == "MatchScore"
			or name == "TeamId"
			or name == "ArenaRoundEligible"
			or name == "RewardsRecoveryPending"
			or name == "MatchRespawnAt"
		then
			scheduleUpdate()
		end
	end)
end

local function unhookMember(member: Player)
	local conn = memberConnections[member]
	if conn then
		conn:Disconnect()
		memberConnections[member] = nil
	end
end

local function hookCharacter(character: Model?)
	for _, conn in characterConnections do
		conn:Disconnect()
	end
	table.clear(characterConnections)
	if character == nil then
		return
	end
	table.insert(characterConnections, character:GetAttributeChangedSignal("CombatAlive"):Connect(scheduleUpdate))
	table.insert(characterConnections, character:GetAttributeChangedSignal("minv"):Connect(scheduleUpdate))
end

local function attachMatchState(state: Folder)
	table.insert(eventConnections, state.AttributeChanged:Connect(scheduleUpdate))
end

-- The board is a hold-to-view overlay: it never asks for the cursor, so the
-- player keeps moving and aiming while they glance at it.
local function setOpen(open: boolean)
	scoreboardOpen = open and available
	update()
end

function MatchHUDClient.setAvailable(value: boolean)
	available = value
	if not available and scoreboardOpen then
		setOpen(false)
	end
end

function MatchHUDClient.toggleScoreboard()
	setOpen(not scoreboardOpen)
end

function MatchHUDClient.closeScoreboard()
	setOpen(false)
end

function MatchHUDClient.getSnapshot(): any
	return snapshot
end

function MatchHUDClient.subscribe(callback: (any) -> ()): () -> ()
	table.insert(listeners, callback)
	if connection == nil then
		local timerElapsed = 0
		connection = RunService.Heartbeat:Connect(function(dt)
			timerElapsed += dt
			if timerElapsed >= 1.0 then
				timerElapsed = 0
				update()
			end
		end)

		local player = Players.LocalPlayer
		table.insert(
			eventConnections,
			player.CharacterAdded:Connect(function(char)
				hookCharacter(char)
				scheduleUpdate()
			end)
		)
		table.insert(
			eventConnections,
			player.CharacterRemoving:Connect(function()
				hookCharacter(nil)
				scheduleUpdate()
			end)
		)
		hookCharacter(player.Character)

		for _, member in Players:GetPlayers() do
			hookMember(member)
		end
		table.insert(
			eventConnections,
			Players.PlayerAdded:Connect(function(member)
				hookMember(member)
				scheduleUpdate()
			end)
		)
		table.insert(
			eventConnections,
			Players.PlayerRemoving:Connect(function(member)
				unhookMember(member)
				scheduleUpdate()
			end)
		)

		local matchState = ReplicatedStorage:FindFirstChild("MatchState")
		if matchState and matchState:IsA("Folder") then
			attachMatchState(matchState)
		end
		table.insert(
			eventConnections,
			ReplicatedStorage.ChildAdded:Connect(function(child)
				if child.Name == "MatchState" and child:IsA("Folder") then
					attachMatchState(child)
					scheduleUpdate()
				end
			end)
		)

		ContextActionService:BindActionAtPriority(action, function(_, inputState)
			-- A release must close the board even if chat gained focus while held.
			if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
				setOpen(false)
				return if available then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
			end
			if not available or UserInputService:GetFocusedTextBox() then
				return Enum.ContextActionResult.Pass
			end
			if inputState == Enum.UserInputState.Begin then
				setOpen(true)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 2, SCORES_BINDING.Keyboard, SCORES_BINDING.Gamepad)

		focusConnection = UserInputService.WindowFocusReleased:Connect(function()
			setOpen(false)
		end)
		textFocusConnection = UserInputService.TextBoxFocused:Connect(function()
			setOpen(false)
		end)
	end

	update()
	callback(snapshot)

	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
		if #listeners == 0 and connection then
			connection:Disconnect()
			connection = nil
			if focusConnection then
				focusConnection:Disconnect()
				focusConnection = nil
			end
			if textFocusConnection then
				textFocusConnection:Disconnect()
				textFocusConnection = nil
			end
			for _, conn in eventConnections do
				conn:Disconnect()
			end
			table.clear(eventConnections)
			for _, conn in characterConnections do
				conn:Disconnect()
			end
			table.clear(characterConnections)
			for _, conn in memberConnections do
				conn:Disconnect()
			end
			table.clear(memberConnections)
			ContextActionService:UnbindAction(action)
			MatchHUDClient.setAvailable(false)
		end
	end
end

return MatchHUDClient
