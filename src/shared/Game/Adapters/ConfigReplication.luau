--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("LiveConfig"))
local ConfigFolder = script.Parent.Parent:WaitForChild("Config")
local ConfigOverrides = require(ConfigFolder:WaitForChild("ConfigOverrides"))
local ConfigRuntime = require(ConfigFolder:WaitForChild("ConfigRuntime"))

-- Client half of live config: mirrors the override set the server projected onto
-- ReplicatedStorage.ConfigState onto this client's Config tables.
--
-- Values are read back through the same registry the server published from and
-- re-validated by the same pure rules, so an unexpected attribute installs
-- nothing rather than corrupting gameplay values. A client that never receives a
-- projection keeps its baked values, which is also what every client sees while
-- configs are unavailable.

local ConfigReplication = {}

local started = false

-- FindFirstChild is correct here: a key with no override legitimately has no
-- child, and that absence is what reverts the leaf to its baked value.
local function applyProjection(folder: Folder)
	local rawValues = {}
	for _, entry in LiveConfig.Entries do
		local child = folder:FindFirstChild(ConfigOverrides.projectedName(entry.Key))
		if child and child:IsA("ValueBase") then
			rawValues[entry.Key] = (child :: any).Value
		end
	end
	local accepted = ConfigOverrides.resolve(LiveConfig.Entries, rawValues)
	ConfigRuntime.apply(accepted)
end

function ConfigReplication.startClient(modules: { [string]: any })
	if started then
		return
	end
	started = true

	for name, moduleTable in modules do
		ConfigRuntime.register(name, moduleTable)
	end

	local folder = ReplicatedStorage:WaitForChild(LiveConfig.StateFolderName)
	assert(folder:IsA("Folder"), `[ConfigReplication] ReplicatedStorage.{LiveConfig.StateFolderName} must be a Folder`)

	-- Revision alone is not enough: the values live in child instances that
	-- replicate independently of the attribute, so a client woken only by
	-- revision can read the set before the new values land.
	local function reapply()
		applyProjection(folder)
	end

	local function watchChild(child: Instance)
		child.Changed:Connect(reapply)
		reapply()
	end

	folder.AttributeChanged:Connect(reapply)
	folder.ChildAdded:Connect(watchChild)
	folder.ChildRemoved:Connect(reapply)
	for _, child in folder:GetChildren() do
		child.Changed:Connect(reapply)
	end
	applyProjection(folder)
end

return ConfigReplication
