-- A support contact arms one shared countdown; server collision is authoritative.
--!strict
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(RS.Config.Gameplay.MapFeatures)
local Network = require(RS.Shared.Network)
local Parts = require(script.Parent.FeatureParts)
local Kit = require(script.Parent.MapFeatureKit)
local FallingTiles = { folderName = "Rotating", instanceClass = "Folder" }
type Original = { part: BasePart, transparency: number, collide: boolean, query: boolean, touch: boolean }
type Tile = { original: { Original }, dropAt: number?, restoreAt: number?, hidden: boolean }
local tiles: { [BasePart]: Tile } = {}
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.RespectCanCollide = true
local function restore(state: Tile)
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
			restore(state)
			tiles[tile] = nil
			continue
		end
		if state.dropAt and not state.hidden and context.now >= state.dropAt then
			state.hidden = true
			for _, v in state.original do
				v.part.CanCollide = false
				v.part.CanQuery = false
				v.part.CanTouch = false
				v.part.Transparency = 1
			end
			local respawn = Parts.number(tile, "RespawnSeconds", Config.FallingTile.RespawnSeconds, 0, 120)
			state.restoreAt = if respawn > 0 then context.now + respawn else nil
		elseif state.restoreAt and context.now >= state.restoreAt then
			restore(state)
		end
	end
end
function FallingTiles.tickPlayer(context: Kit.Context, _player: Player, root: BasePart)
	local humanoid = if root.Parent then root.Parent:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or root.Anchored then
		return
	end
	ray.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = Workspace:Raycast(root.Position, Vector3.yAxis * -(humanoid.HipHeight + root.Size.Y / 2 + 0.75), ray)
	if not hit or hit.Normal.Y < 0.5 then
		return
	end
	for tile, state in tiles do
		if (hit.Instance == tile or hit.Instance:IsDescendantOf(tile)) and not state.dropAt then
			local delay = Parts.number(tile, "DropDelaySeconds", Config.FallingTile.DropDelaySeconds, 0.1, 10)
			state.dropAt = context.now + delay
			Network.fire("HazardVisual", nil, tile, "shake", delay)
			return
		end
	end
end
function FallingTiles.forget(player: Player?)
	if player then
		return
	end
	for _, state in tiles do
		restore(state)
	end
	table.clear(tiles)
end
return FallingTiles
