--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapFeatures = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MapFeatures"))
local Volume = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("MapFeatures"):WaitForChild("Volume")
)
local MapFeatureKit = require(script.Parent.MapFeatureKit)

-- Launches a player along the pad's UpVector. Server-set velocity, the same
-- pattern as hammer knockback, which predicts cleanly. The per-player per-pad
-- cooldown stops a pad retriggering while the player is still overlapping it.
-- A pad may override the shared speed with a numeric "LaunchSpeed" attribute.

local BouncePads = {}

local cooldowns: { [Player]: { [BasePart]: number } } = {}

BouncePads.folderName = "BouncePads"

function BouncePads.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	local playerCooldowns = cooldowns[player]
	if playerCooldowns == nil then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end

	for _, pad in context.parts do
		if not Volume.contains(pad.CFrame, pad.Size, root.Position, MapFeatures.BouncePad.VerticalPadding) then
			continue
		end
		if context.now < (playerCooldowns[pad] or 0) then
			continue
		end
		playerCooldowns[pad] = context.now + MapFeatures.BouncePad.CooldownSeconds
		local speed = (pad:GetAttribute("LaunchSpeed") :: number?) or MapFeatures.BouncePad.LaunchSpeed
		root.AssemblyLinearVelocity = pad.CFrame.UpVector * speed
	end
end

function BouncePads.forget(player: Player?)
	if player then
		cooldowns[player] = nil
	else
		table.clear(cooldowns)
	end
end

return BouncePads
