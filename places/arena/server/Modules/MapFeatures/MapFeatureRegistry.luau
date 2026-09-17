-- Description: Lists the map feature kits the arena runs, the single place a new authored feature is registered.

--!strict

local MapFeatureKit = require(script.Parent.MapFeatureKit)
local JumpPads = require(script.Parent.JumpPads)
local ElimZones = require(script.Parent.ElimZones)
local FanUpdraft = require(script.Parent.FanUpdraft)
local SpinnerBump = require(script.Parent.SpinnerBump)
local RotorBump = require(script.Parent.RotorBump)
local Bumpers = require(script.Parent.Bumpers)
local BeachBalls = require(script.Parent.BeachBalls)
local Doors = require(script.Parent.Doors)
local ServerRiders = require(script.Parent.ServerRiders)
local Conveyors = require(script.Parent.Conveyors)
local BigBalls = require(script.Parent.BigBalls)
local FallingTiles = require(script.Parent.FallingTiles)
local Seesaws = require(script.Parent.Seesaws)

local kits: { MapFeatureKit.MapFeatureKit } = {
	ElimZones,
	JumpPads,
	FanUpdraft,
	SpinnerBump,
	RotorBump,
	Bumpers,
	BeachBalls,
	Doors,
	Conveyors,
	BigBalls,
	FallingTiles,
	Seesaws,
	ServerRiders,
}

local MapFeatureRegistry = {}

function MapFeatureRegistry.all(): { MapFeatureKit.MapFeatureKit }
	return kits
end

return MapFeatureRegistry
