--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Debug"))
local ThrowPose = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ThrowPose"))

-- Live tuning for the throw pose, so a value can be dialled in during a test
-- session instead of stopping, editing, and rejoining for every guess.
--
-- Mirrors Config.ThrowPose into a folder of Value objects under Workspace and
-- writes edits straight back into the config table the pose modules already
-- read. There is no second resolved copy: ArmIK reads the table every frame, so
-- dragging a value moves the arm on the next frame.
--
-- Studio only and off by default. The folder is created by the client and
-- replicates nowhere, so it is a scratchpad for whoever is testing and cannot
-- reach a live server. Values are never written back to disk -- once a number
-- feels right, copy it into src/config/ThrowPose.luau, which stays the source of
-- truth.
--
-- The tree is walked generically rather than from a list of paths, so a value
-- added to the config shows up here with no extra work and none of the usual
-- drift between a config and its editor.

local ThrowPoseTuner = {}

local FOLDER_NAME = "ThrowPoseTuning"

local started = false

local function enabled(): boolean
	return Debug.StudioVisuals == true and Debug.ThrowPoseTuner == true and RunService:IsStudio()
end

-- Vector config values are authored with vector.create, whose typeof is
-- "vector"; Vector3Value needs a real Vector3, so the two are converted at the
-- boundary in both directions.
local function isVector(value: any): boolean
	return typeof(value) == "vector" or typeof(value) == "Vector3"
end

local function bind(container: Instance, holder: { [string]: any }, key: string, path: string)
	local value = holder[key]
	local instance: Instance?

	if typeof(value) == "number" then
		local object = Instance.new("NumberValue")
		object.Value = value
		object.Changed:Connect(function(new)
			holder[key] = new
		end)
		instance = object
	elseif typeof(value) == "boolean" then
		local object = Instance.new("BoolValue")
		object.Value = value
		object.Changed:Connect(function(new)
			holder[key] = new
		end)
		instance = object
	elseif isVector(value) then
		local object = Instance.new("Vector3Value")
		object.Value = Vector3.new(value.x, value.y, value.z)
		object.Changed:Connect(function(new)
			holder[key] = vector.create(new.X, new.Y, new.Z)
		end)
		instance = object
	end

	if instance then
		instance.Name = path
		instance.Parent = container
	end
end

local function mirror(container: Instance, holder: { [string]: any }, prefix: string)
	-- Sorted so the folder reads the same way every session; Instance children
	-- are otherwise ordered by insertion, and pairs order is not stable.
	local keys: { string } = {}
	for key in holder do
		table.insert(keys, key)
	end
	table.sort(keys)

	for _, key in keys do
		local value = holder[key]
		local path = if prefix == "" then key else prefix .. "_" .. key
		if typeof(value) == "table" and not isVector(value) then
			mirror(container, value, path)
		else
			bind(container, holder, key, path)
		end
	end
end

function ThrowPoseTuner.start()
	if started or not enabled() then
		return
	end
	started = true

	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	mirror(folder, ThrowPose :: any, "")
	folder.Parent = Workspace

	print(
		"[ThrowPoseTuner] Tuning values are under Workspace."
			.. FOLDER_NAME
			.. ". Edits apply immediately and are NOT saved -- copy the ones you like into src/config/ThrowPose.luau."
	)
end

return ThrowPoseTuner
