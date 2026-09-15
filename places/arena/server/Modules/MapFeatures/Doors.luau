-- Description: Breakaway doors for a Splashdown course: the doors the server chose for the round give way the moment a racer's root reaches them and are announced to clients, every other door stays solid, and the plan lives only here so no client can read which doors are real.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Volume = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("MapFeatures"):WaitForChild("Volume")
)
local MapFeatureKit = require(script.Parent.MapFeatureKit)

local Doors = {}

Doors.folderName = "Doors"

local breakable: { [BasePart]: boolean } = {}
local broken: { [BasePart]: boolean } = {}

function Doors.reset()
	for door in broken do
		if door.Parent ~= nil then
			door.CanCollide = true
			door.CanQuery = true
		end
	end
	table.clear(broken)
	table.clear(breakable)
end

function Doors.setPlan(plan: { [BasePart]: boolean })
	Doors.reset()
	for door, chosen in plan do
		if chosen then
			breakable[door] = true
		end
	end
end

function Doors.isBroken(door: BasePart): boolean
	return broken[door] == true
end

local function breakDoor(door: BasePart, position: Vector3)
	broken[door] = true
	door.CanCollide = false
	door.CanQuery = false
	Network.fire("DoorBroken", nil, door, position)
end

function Doors.tickPlayer(_context: MapFeatureKit.Context, _player: Player, root: BasePart)
	local settings = MapFeatures.Door
	local reach = Vector3.new(settings.ContactPadding * 2, 0, settings.ContactPadding * 2)
	for _, instance in _context.instances do
		local door = instance :: BasePart
		if
			breakable[door]
			and not broken[door]
			and Volume.contains(door.CFrame, door.Size + reach, root.Position, settings.VerticalPadding)
		then
			breakDoor(door, root.Position)
		end
	end
end

function Doors.forget(player: Player?)
	if player == nil then
		Doors.reset()
	end
end

return Doors
