-- Reads authoritative match projections and owns only the custom scoreboard's open state and input lifecycle.
--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))
local Presentation =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation"))
local Model = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Models"):WaitForChild("MatchHUDModel")
)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
local MatchHUDClient = {}
local snapshot: any = Model.build({}, 0)
local listeners: { (any) -> () } = {}
local connection: RBXScriptConnection? = nil
local scoreboardOpen = false
local available = false
local action = "ArenaScoreboard"

local function same(a, b): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not same(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function update()
	local player = Players.LocalPlayer
	local state = ReplicatedStorage:FindFirstChild("MatchState")
	if state == nil then
		return
	end
	local modeId = state:GetAttribute("modeId")
	local mode = GameModes.Modes[modeId]
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
	local nextSnapshot = Model.build({
		phase = state:GetAttribute("phase"),
		title = if mode then mode.Title else "MATCH",
		timeRemaining = state:GetAttribute("timeRemaining"),
		scoreTarget = state:GetAttribute("scoreTarget"),
		teamMode = state:GetAttribute("scoreScope") == "Team",
		redScore = state:GetAttribute("TeamScore_Red"),
		blueScore = state:GetAttribute("TeamScore_Blue"),
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
	if same(nextSnapshot, snapshot) then
		return
	end
	snapshot = nextSnapshot
	for _, listener in table.clone(listeners) do
		pcall(listener, snapshot)
	end
end

local function setOpen(open: boolean)
	scoreboardOpen = open and available
	if scoreboardOpen then
		Combat.requestCursor(action)
	else
		Combat.releaseCursor(action)
	end
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
		local elapsed = 0
		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= Presentation.HUD.UpdateSeconds then
				elapsed = 0
				update()
			end
		end)
		ContextActionService:BindActionAtPriority(action, function(_, inputState)
			if not available or UserInputService:GetFocusedTextBox() then
				return Enum.ContextActionResult.Pass
			end
			if inputState == Enum.UserInputState.Begin then
				MatchHUDClient.toggleScoreboard()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 2, Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect)
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
			ContextActionService:UnbindAction(action)
			MatchHUDClient.setAvailable(false)
		end
	end
end

return MatchHUDClient
