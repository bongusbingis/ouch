--!strict

local MapFeatureKit = require(script.Parent.MapFeatureKit)
local JumpPads = require(script.Parent.JumpPads)
local ElimZones = require(script.Parent.ElimZones)
local FoamPits = require(script.Parent.FoamPits)

-- Registration order is iteration order; keep it deterministic and explicit.
-- A kit's folderName must be unique, and must match a folder authored under
-- Workspace.Assets.Arena.Scriptables.
local kits: { MapFeatureKit.MapFeatureKit } = {
	ElimZones,
	JumpPads,
	FoamPits,
}

local MapFeatureRegistry = {}

function MapFeatureRegistry.all(): { MapFeatureKit.MapFeatureKit }
	return kits
end

return MapFeatureRegistry
