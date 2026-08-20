--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapFeatures = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MapFeatures"))
local Volume = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("MapFeatures"):WaitForChild("Volume")
)
local MapFeatureKit = require(script.Parent.MapFeatureKit)
local MatchService = require(script.Parent.Parent.MatchService)

-- Authored kill volumes: entering one eliminates the player immediately. The
-- elimination is routed through MatchService so scoring, the combat feed, mode
-- hooks, and respawn all run exactly as they do for a dodgeball elimination.
--
-- MatchService ignores eliminations outside an Active match, so a player who
-- wanders into a zone between matches is left alone.

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
