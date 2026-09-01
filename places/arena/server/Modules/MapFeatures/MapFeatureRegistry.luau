-- Name: MapFeatureRegistry.luau
-- Author: Jack C.
-- Description: Lists the map feature kits the arena runs, the single place a new authored feature is registered.
-- Created: 2026-08-18

--!strict

local MapFeatureKit = require(script.Parent.MapFeatureKit)
local JumpPads = require(script.Parent.JumpPads)
local ElimZones = require(script.Parent.ElimZones)
local FoamPits = require(script.Parent.FoamPits)

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
