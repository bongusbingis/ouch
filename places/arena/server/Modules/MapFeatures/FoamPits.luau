--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapFeatures = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MapFeatures"))
local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local Volume = require(Shared:WaitForChild("MapFeatures"):WaitForChild("Volume"))
local MovementSpeedService = require(Shared:WaitForChild("Adapters"):WaitForChild("MovementSpeedService"))
local MapFeatureKit = require(script.Parent.MapFeatureKit)

-- Slows a player while their root is inside a pit volume. WalkSpeed is never
-- written directly: the slow is a named MovementSpeedService modifier, which is
-- the sole owner of WalkSpeed.

local FoamPits = {}

local MODIFIER = "foamPit"

local slowed: { [Player]: boolean } = {}

FoamPits.folderName = "FoamPits"

function FoamPits.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	local inPit = false
	for _, pit in context.parts do
		if Volume.contains(pit.CFrame, pit.Size, root.Position, MapFeatures.FoamPit.VerticalPadding) then
			inPit = true
			break
		end
	end

	if inPit and not slowed[player] then
		slowed[player] = true
		MovementSpeedService.setModifier(player, MODIFIER, MapFeatures.FoamPit.WalkSpeedScale)
	elseif not inPit and slowed[player] then
		slowed[player] = nil
		MovementSpeedService.clearModifier(player, MODIFIER)
	end
end

function FoamPits.forget(player: Player?)
	if player then
		if slowed[player] then
			slowed[player] = nil
			MovementSpeedService.clearModifier(player, MODIFIER)
		end
		return
	end
	for slowedPlayer in slowed do
		MovementSpeedService.clearModifier(slowedPlayer, MODIFIER)
	end
	table.clear(slowed)
end

return FoamPits
