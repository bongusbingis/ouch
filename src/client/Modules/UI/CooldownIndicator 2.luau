--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"))

-- Drives the Studio-authored Hud.DelayIndicator from the local character's
-- predicted primary-attack cooldown attributes.

local CooldownIndicator = {}

local connections: { RBXScriptConnection } = {}
local activeTween: Tween? = nil
local indicator: Frame? = nil
local previousCooldown = 0

local function fullSize(): UDim2
	local size = UI.Hud.DelayIndicator.FullSize
	return UDim2.new(size.xScale, size.xOffset, size.yScale, size.yOffset)
end

local function cancelTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

local function hide()
	cancelTween()
	local frame = indicator
	if frame then
		frame.Visible = false
	end
end

local function cooldownFor(character: Model): number
	local dodgeball = (character:GetAttribute("dbTc") :: number?) or 0
	local hammer = (character:GetAttribute("hmCd") :: number?) or 0
	return math.max(dodgeball, hammer)
end

local function startTween(duration: number)
	local frame = indicator
	if frame == nil then
		return
	end
	cancelTween()
	frame.Size = fullSize()
	frame.Visible = true
	local tween = TweenService:Create(frame, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, frame.Size.Y.Scale, frame.Size.Y.Offset),
	})
	activeTween = tween
	tween.Completed:Once(function(playbackState)
		if activeTween ~= tween then
			return
		end
		activeTween = nil
		if playbackState == Enum.PlaybackState.Completed then
			frame.Visible = false
		end
	end)
	tween:Play()
end

local function disconnectCharacter()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	previousCooldown = 0
	hide()
end

local function bindCharacter(character: Model)
	disconnectCharacter()

	local function refresh()
		local cooldown = cooldownFor(character)
		if cooldown > 0 and previousCooldown <= 0 then
			startTween(cooldown)
		elseif cooldown <= 0 and previousCooldown > 0 then
			hide()
		end
		previousCooldown = cooldown
	end

	table.insert(connections, character:GetAttributeChangedSignal("dbTc"):Connect(refresh))
	table.insert(connections, character:GetAttributeChangedSignal("hmCd"):Connect(refresh))
	refresh()
end

function CooldownIndicator.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local instance = playerGui:WaitForChild("Hud"):WaitForChild("DelayIndicator")
	assert(instance:IsA("Frame"), "[CooldownIndicator] PlayerGui.Hud.DelayIndicator must be a Frame")
	indicator = instance
	instance.AnchorPoint = Vector2.new(0.5, 1)
	instance.Position = UDim2.fromScale(0.5, 0.95)
	instance.Size = fullSize()
	instance.Visible = false

	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		bindCharacter(player.Character)
	end
end

return CooldownIndicator
