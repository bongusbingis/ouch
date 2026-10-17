-- Render-only smoothing for native seesaws and free beach balls. The source retains all local physics and queries.
--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config.Gameplay.MapFeatures)
local ScriptableRoots = require(ReplicatedStorage.Shared.Game.MapFeatures.ScriptableRoots)

local PhysicalHazardVisuals = {}

type State = {
	ghost: BasePart,
	pose: CFrame,
	sourcePose: CFrame,
	sourceChangedAt: number,
	wasAnchored: boolean,
	localTransparency: number,
}

local states: { [BasePart]: State } = {}
local watched: { [BasePart]: RBXScriptConnection } = {}
local warnedClone: { [BasePart]: boolean } = {}
local rootStates: {
	[Instance]: { parts: { [BasePart]: boolean }, added: RBXScriptConnection, removing: RBXScriptConnection },
} =
	{}
local folder: Folder? = nil
local render: RBXScriptConnection? = nil
local unwatchRoots: (() -> ())? = nil

local function isPhysicalSource(part: BasePart): boolean
	if
		part:GetAttribute(Config.Attributes.Seesaw) == true
		or part:GetAttribute(Config.Attributes.BeachBall) == true
	then
		return true
	end
	-- Legacy Arena balls are name-matched by BeachBalls on the server before being moved into its runtime folder.
	return part.Name:find(Config.BeachBall.NamePrefix, 1, true) == 1
		and part:FindFirstAncestor("Scriptables") ~= nil
		and part:FindFirstAncestor("SplashdownCourse") == nil
end

local function sanitize(instance: Instance)
	for key in instance:GetAttributes() do
		instance:SetAttribute(key, nil)
	end
	for _, tag in CollectionService:GetTags(instance) do
		CollectionService:RemoveTag(instance, tag)
	end
end

local function cosmeticCopy(source: BasePart): BasePart
	local ghost = source:Clone()
	for _, child in ghost:GetChildren() do
		if
			not child:IsA("DataModelMesh")
			and not child:IsA("Decal")
			and not child:IsA("Texture")
			and not child:IsA("SurfaceAppearance")
		then
			child:Destroy()
		else
			for _, nested in child:GetDescendants() do
				nested:Destroy()
			end
			sanitize(child)
		end
	end
	sanitize(ghost)
	ghost.Name = "PhysicalHazardVisual"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanTouch = false
	ghost.CanQuery = false
	ghost.LocalTransparencyModifier = 0
	return ghost
end

local function clear(source: BasePart)
	local state = states[source]
	if not state then
		return
	end
	states[source] = nil
	if source.Parent and source.LocalTransparencyModifier == 1 then
		source.LocalTransparencyModifier = state.localTransparency
	end
	state.ghost:Destroy()
end

local function attach(source: BasePart)
	local visualFolder = folder
	if
		not visualFolder
		or states[source]
		or not source:IsDescendantOf(Workspace)
		or source:IsDescendantOf(visualFolder)
	then
		return
	end
	if not isPhysicalSource(source) then
		return
	end
	local ok, ghost = pcall(cosmeticCopy, source)
	if not ok or not ghost then
		if not warnedClone[source] then
			warnedClone[source] = true
			warn(`[PhysicalHazardVisuals] Cosmetic copy unavailable for {source:GetFullName()}: {tostring(ghost)}`)
		end
		return
	end
	ghost.CFrame = source.CFrame
	ghost.Parent = visualFolder
	states[source] = {
		ghost = ghost,
		pose = source.CFrame,
		sourcePose = source.CFrame,
		sourceChangedAt = os.clock(),
		wasAnchored = source.Anchored,
		localTransparency = source.LocalTransparencyModifier,
	}
	source.LocalTransparencyModifier = 1
end

local function watch(source: BasePart)
	local visualFolder = folder
	if not visualFolder or source:IsDescendantOf(visualFolder) or watched[source] then
		return
	end
	watched[source] = source.AttributeChanged:Connect(function()
		if isPhysicalSource(source) then
			attach(source)
		else
			clear(source)
		end
	end)
	attach(source)
end

local function unwatch(source: BasePart)
	local connection = watched[source]
	if connection then
		connection:Disconnect()
		watched[source] = nil
	end
	warnedClone[source] = nil
	clear(source)
end

local function addRoot(root: Instance)
	if rootStates[root] then
		return
	end
	local parts: { [BasePart]: boolean } = {}
	local function addPart(instance: Instance)
		if instance:IsA("BasePart") then
			parts[instance] = true
			watch(instance)
		end
	end
	local function removePart(instance: Instance)
		if instance:IsA("BasePart") then
			parts[instance] = nil
			unwatch(instance)
		end
	end
	rootStates[root] = {
		parts = parts,
		added = root.DescendantAdded:Connect(addPart),
		removing = root.DescendantRemoving:Connect(removePart),
	}
	addPart(root)
	for _, instance in root:GetDescendants() do
		addPart(instance)
	end
end

local function removeRoot(root: Instance)
	local state = rootStates[root]
	if not state then
		return
	end
	rootStates[root] = nil
	state.added:Disconnect()
	state.removing:Disconnect()
	for part in state.parts do
		unwatch(part)
	end
end

local function avatarNear(source: BasePart): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - source.Position).Magnitude < source.Size.Magnitude * 0.5 + 6
end

local function update(source: BasePart, state: State, dt: number)
	if not source:IsDescendantOf(Workspace) or not state.ghost.Parent then
		clear(source)
		return
	end
	local target = source.CFrame
	local now = os.clock()
	if target ~= state.sourcePose then
		state.sourcePose = target
		state.sourceChangedAt = now
	end
	local relative = state.pose:ToObjectSpace(target)
	local _, angle = relative:ToAxisAngle()
	local error = relative.Position.Magnitude
	local near = avatarNear(source)
	local stale = now - state.sourceChangedAt > 0.35
		and (source.AssemblyLinearVelocity.Magnitude > 1 or source.AssemblyAngularVelocity.Magnitude > 1)
	local snap = stale
		or (state.wasAnchored ~= source.Anchored)
		or error > (if near then 1.5 else 4)
		or math.abs(angle) > (if near then math.rad(18) else math.rad(50))
	if snap then
		state.pose = target
	else
		local tau = if near then 0.018 else 0.06
		local alpha = 1 - math.exp(-math.clamp(dt, 0, 0.1) / tau)
		state.pose = state.pose:Lerp(target, alpha)
	end
	state.wasAnchored = source.Anchored
	state.ghost.CFrame = state.pose
	state.ghost.Size = source.Size
	state.ghost.Transparency = source.Transparency
	state.ghost.Color = source.Color
	state.ghost.Material = source.Material
	if source.LocalTransparencyModifier ~= 1 then
		state.localTransparency = source.LocalTransparencyModifier
		source.LocalTransparencyModifier = 1
	end
end

function PhysicalHazardVisuals.start()
	if render then
		return
	end
	local visualFolder = Instance.new("Folder")
	visualFolder.Name = "PhysicalHazardVisuals"
	visualFolder.Parent = Workspace
	folder = visualFolder
	unwatchRoots = ScriptableRoots.watch(addRoot, removeRoot)
	render = RunService.RenderStepped:Connect(function(dt)
		for source, state in states do
			local ok, reason = pcall(update, source, state, dt)
			if not ok then
				warn(`[PhysicalHazardVisuals] Cosmetic update failed: {tostring(reason)}`)
				clear(source)
			end
		end
	end)
end

function PhysicalHazardVisuals.stop()
	if render then
		render:Disconnect()
		render = nil
	end
	if unwatchRoots then
		unwatchRoots()
		unwatchRoots = nil
	end
	for root in rootStates do
		removeRoot(root)
	end
	for source in states do
		clear(source)
	end
	for source in watched do
		unwatch(source)
	end
	table.clear(warnedClone)
	if folder then
		folder:Destroy()
		folder = nil
	end
end

return PhysicalHazardVisuals
