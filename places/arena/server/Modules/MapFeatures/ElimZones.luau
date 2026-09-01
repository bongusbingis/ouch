-- Name: ElimZones.luau
-- Author: Jack C.
-- Description: Map feature kit for out-of-bounds volumes: eliminates any player whose root enters an authored elimination zone, routing through the match service so scoring and respawn stay in one place.
-- Created: 2026-08-18

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapFeatures = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MapFeatures"))
local Volume = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("MapFeatures"):WaitForChild("Volume")
)
local MapFeatureKit = require(script.Parent.MapFeatureKit)
local MatchService = require(script.Parent.Parent.MatchService)

local ElimZones = {}

ElimZones.folderName = "ElimZones"

function ElimZones.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	for _, instance in context.instances do
		local zone = instance :: BasePart
		if Volume.contains(zone.CFrame, zone.Size, root.Position, MapFeatures.ElimZone.VerticalPadding) then
			MatchService.eliminate(player)
			return
		end
	end
end

return ElimZones
