-- Name: ScriptableRoots.luau
-- Author: Jack C.
-- Description: The set of Scriptables folders the map feature kits drive, found through one CollectionService tag so the arena's authored folder and every instantiated Splashdown course are discovered the same way on both server and client, including roots that stream in later or leave the Workspace.
-- Created: 2026-09-14

--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))

local ScriptableRoots = {}

local TAG = MapFeatures.Attributes.ScriptableRoot

function ScriptableRoots.tag(root: Instance)
	CollectionService:AddTag(root, TAG)
end

function ScriptableRoots.untag(root: Instance)
	CollectionService:RemoveTag(root, TAG)
end

function ScriptableRoots.isRoot(instance: Instance): boolean
	return CollectionService:HasTag(instance, TAG) and instance:IsDescendantOf(Workspace)
end

function ScriptableRoots.all(): { Instance }
	local roots = {}
	for _, root in CollectionService:GetTagged(TAG) do
		if root:IsDescendantOf(Workspace) then
			table.insert(roots, root)
		end
	end
	return roots
end

-- Reports every tagged root that is in the Workspace, now and as they arrive,
-- and reports a root once when it loses the tag or leaves the Workspace. A
-- root tagged before it is parented is reported when it lands.
function ScriptableRoots.watch(onAdded: (Instance) -> (), onRemoved: (Instance) -> ()): () -> ()
	local connections: { RBXScriptConnection } = {}
	local tracked: { [Instance]: RBXScriptConnection } = {}
	local live: { [Instance]: boolean } = {}

	local function sync(root: Instance)
		local inWorld = CollectionService:HasTag(root, TAG) and root:IsDescendantOf(Workspace)
		if inWorld and not live[root] then
			live[root] = true
			onAdded(root)
		elseif not inWorld and live[root] then
			live[root] = nil
			onRemoved(root)
		end
	end

	local function track(root: Instance)
		if tracked[root] then
			return
		end
		tracked[root] = root.AncestryChanged:Connect(function()
			sync(root)
		end)
		sync(root)
	end

	local function untrack(root: Instance)
		local connection = tracked[root]
		if connection then
			connection:Disconnect()
			tracked[root] = nil
		end
		sync(root)
	end

	table.insert(connections, CollectionService:GetInstanceAddedSignal(TAG):Connect(track))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack))
	for _, root in CollectionService:GetTagged(TAG) do
		track(root)
	end

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		for root, connection in tracked do
			connection:Disconnect()
			if live[root] then
				live[root] = nil
				onRemoved(root)
			end
		end
		table.clear(tracked)
	end
end

return table.freeze(ScriptableRoots)
