--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PlayerAssist"))
local AssistResolver = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Config"):WaitForChild("AssistResolver")
)

-- Client's view of its own assist scalars, projected by PlayerAssistService onto
-- a folder under this Player. Re-validated here against the same rules the
-- server used, so a malformed projection lands on defaults rather than reaching
-- the camera.
--
-- Reads every value on any change rather than trusting the revision attribute as
-- a commit barrier: attributes and child values do not replicate in write order.

local AssistConfig = {}

local started = false
local resolved: { [string]: any } = PlayerAssist.Defaults

local function reread(folder: Folder)
	local rawValues = {}
	for _, entry in PlayerAssist.Entries do
		local value = folder:FindFirstChild(entry.Key)
		if value and value:IsA("ValueBase") then
			rawValues[entry.Key] = (value :: any).Value
		end
	end
	resolved = AssistResolver.resolve(PlayerAssist.Entries, rawValues)
end

-- Effective 0-1 strength for a feature on the given device. Zero means inert;
-- callers should skip the work entirely rather than scaling by zero.
function AssistConfig.strength(feature: string, deviceClass: string): number
	local scale = AssistResolver.scaleFor(PlayerAssist.DeviceScale, deviceClass)
	return AssistResolver.strength(resolved, scale, feature)
end

function AssistConfig.start()
	if started then
		return
	end
	started = true

	local folder = Players.LocalPlayer:WaitForChild(PlayerAssist.FolderName)
	assert(folder:IsA("Folder"), "[AssistConfig] Player.AssistConfig must be a Folder")

	local function watch(child: Instance)
		if child:IsA("ValueBase") then
			child.Changed:Connect(function()
				reread(folder)
			end)
		end
	end
	for _, child in folder:GetChildren() do
		watch(child)
	end
	folder.ChildAdded:Connect(function(child)
		watch(child)
		reread(folder)
	end)
	folder.AttributeChanged:Connect(function()
		reread(folder)
	end)
	reread(folder)
end

return AssistConfig
