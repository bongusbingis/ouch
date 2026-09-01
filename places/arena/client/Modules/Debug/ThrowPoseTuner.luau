-- Name: ThrowPoseTuner.luau
-- Author: Jack C.
-- Description: Developer-only live tuning harness that binds keys to the throw-pose config values so arm offsets and timings can be adjusted in Studio without editing the config module.
-- Created: 2026-08-20

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Debug"))
local ThrowPose = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("ThrowPose"))

local ThrowPoseTuner = {}

local FOLDER_NAME = "ThrowPoseTuning"

local started = false

local function enabled(): boolean
	return Debug.StudioVisuals == true and Debug.ThrowPoseTuner == true and RunService:IsStudio()
end

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
