-- Description: Lists the map feature kits the arena runs, the single place a new authored feature is registered.

--!strict

local MapFeatureKit = require(script.Parent.MapFeatureKit)
local JumpPads = require(script.Parent.JumpPads)
local ElimZones = require(script.Parent.ElimZones)
local FoamPits = require(script.Parent.FoamPits)
local FanUpdraft = require(script.Parent.FanUpdraft)
local SpinnerBump = require(script.Parent.SpinnerBump)

local kits: { MapFeatureKit.MapFeatureKit } = {
	ElimZones,
	JumpPads,
	FoamPits,
	FanUpdraft,
	SpinnerBump,
}

local MapFeatureRegistry = {}

function MapFeatureRegistry.all(): { MapFeatureKit.MapFeatureKit }
	return kits
end

return MapFeatureRegistry
