-- A support contact arms one shared countdown; server collision is authoritative.
--!strict
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(RS.Config.Gameplay.MapFeatures)
local Network = require(RS.Shared.Network)
local Parts = require(script.Parent.FeatureParts)
local SeesawQuery = require(RS.Shared.Game.MapFeatures.SeesawQuery)
local Kit = require(script.Parent.MapFeatureKit)
local FallingTiles = { folderName = "Rotating", instanceClass = "Folder" }
FallingTiles.folderNames = { "FallingTiles", "Rotating" }
type Original = { part: BasePart, transparency: number, collide: boolean, query: boolean, touch: boolean }
type Tile = { original: { Original }, dropAt: number?, restoreAt: number?, hidden: boolean }
local tiles: { [BasePart]: Tile } = {}
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.RespectCanCollide = true
local function publishState(tile: BasePart, stage: string, dropAt: number?, restoreAt: number?)
	local revision = tile:GetAttribute("HazardTileRevision")
	tile:SetAttribute("HazardTileDropAt", dropAt or 0)
	tile:SetAttribute("HazardTileRestoreAt", restoreAt or 0)
	tile:SetAttribute("HazardTileState", stage)
	tile:SetAttribute("HazardTileRevision", (if typeof(revision) == "number" then revision else 0) + 1)
end
local function restore(tile: BasePart, state: Tile)
	for _, v in state.original do
		if v.part.Parent then
			v.part.Transparency = v.transparency
			v.part.CanCollide = v.collide
			v.part.CanQuery = v.query
			v.part.CanTouch = v.touch
		end
	end
	state.dropAt = nil
	state.restoreAt = nil
	state.hidden = false
	if tile.Parent then
		publishState(tile, "solid", nil, nil)
	end
end
function FallingTiles.tickWorld(context: Kit.Context)
	local active = {}
	for _, tile in Parts.collect(context.instances, Config.Attributes.FallingTile) do
		active[tile] = true
		if not tiles[tile] then
			local original = {}
			local descendants = tile:GetDescendants()
			table.insert(descendants, tile)
			for _, part in descendants do
				if part:IsA("BasePart") then
					table.insert(original, {
						part = part,
						transparency = part.Transparency,
						collide = part.CanCollide,
						query = part.CanQuery,
						touch = part.CanTouch,
					})
				end
			end
			tiles[tile] = { original = original, hidden = false }
		end
	end
	for tile, state in tiles do
		if not active[tile] then
			restore(tile, state)
			tiles[tile] = nil
			continue
		end
		if state.dropAt and not state.hidden and context.now >= state.dropAt then
			local respawn = Parts.number(tile, "RespawnSeconds", Config.FallingTile.RespawnSeconds)
			state.hidden = true
			for _, v in state.original do
				v.part.CanCollide = false
				v.part.CanQuery = false
				v.part.CanTouch = false
				v.part.Transparency = 1
			end
			state.restoreAt = if respawn > 0 then context.now + respawn else nil
			publishState(tile, "hidden", nil, if respawn > 0 then Workspace:GetServerTimeNow() + respawn else nil)
		elseif state.restoreAt and context.now >= state.restoreAt then
			restore(tile, state)
		end
	end
end
function FallingTiles.tickPlayer(context: Kit.Context, _player: Player, root: BasePart)
	local humanoid = if root.Parent then root.Parent:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or root.Anchored then
		return
	end
	ray.FilterDescendantsInstances = { root.Parent :: Instance }
	ray.CollisionGroup = SeesawQuery.groupFor(root)
	local hit = Workspace:Raycast(root.Position, Vector3.yAxis * -(humanoid.HipHeight + root.Size.Y / 2 + 0.75), ray)
	if not hit or hit.Normal.Y < 0.5 then
		return
	end
	for tile, state in tiles do
		if (hit.Instance == tile or hit.Instance:IsDescendantOf(tile)) and not state.dropAt then
			local delay = Parts.number(tile, "DropDelaySeconds", Config.FallingTile.DropDelaySeconds)
			state.dropAt = context.now + delay
			publishState(tile, "armed", Workspace:GetServerTimeNow() + delay, nil)
			Network.fire("HazardVisual", nil, tile, "shake", delay)
			return
		end
	end
end
function FallingTiles.forget(player: Player?)
	if player then
		return
	end
	for tile, state in tiles do
		restore(tile, state)
	end
	table.clear(tiles)
end
return FallingTiles
