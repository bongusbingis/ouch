--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModeRegistry = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeRegistry")
)

-- Drives the Studio-authored top HUD (PlayerGui.Hud.Top.Round / .Timer) from
-- the replicated match state on ReplicatedStorage.MatchState.

local MatchHud = {}

local function resolveLabel(instance: Instance): TextLabel
	if instance:IsA("TextLabel") then
		return instance
	end
	local label = instance:FindFirstChildWhichIsA("TextLabel", true)
	assert(label, `[MatchHud] {instance:GetFullName()} must be or contain a TextLabel`)
	return label
end

local function formatTime(seconds: number): string
	local whole = math.max(math.floor(seconds + 0.5), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function winnerText(winnerId: string): string
	if winnerId == "" then
		return "It's a tie!"
	end
	local player = Players:GetPlayerByUserId(tonumber(winnerId) or 0)
	local name = if player then player.DisplayName else winnerId
	return `{name} wins!`
end

function MatchHud.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local top = playerGui:WaitForChild("Hud"):WaitForChild("Top")
	local roundLabel = resolveLabel(top:WaitForChild("Round"))
	local timerLabel = resolveLabel(top:WaitForChild("Timer"))
	local matchState = ReplicatedStorage:WaitForChild("MatchState")

	local function refresh()
		local phase = matchState:GetAttribute("phase")
		local timeRemaining = (matchState:GetAttribute("timeRemaining") :: number?) or 0
		local winnerId = (matchState:GetAttribute("winnerId") :: string?) or ""
		local modeId = (matchState:GetAttribute("modeId") :: string?) or ""
		local mode = ModeRegistry.get(modeId) or ModeRegistry.default()

		if phase == "Active" then
			roundLabel.Text = `First to {mode.rules.ScoreTarget}`
			timerLabel.Text = formatTime(timeRemaining)
		elseif phase == "Results" then
			roundLabel.Text = winnerText(winnerId)
			timerLabel.Text = "--:--"
		else
			roundLabel.Text = "Waiting for players…"
			timerLabel.Text = "--:--"
		end
	end

	matchState.AttributeChanged:Connect(refresh)
	refresh()
end

return MatchHud
