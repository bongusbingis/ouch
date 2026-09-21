--!strict
-- Rising wind particles and client-only spinning blades make authored fans readable.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local MapFeatures = require(ReplicatedStorage.Config.Gameplay.MapFeatures)
local ScriptableRoots = require(ReplicatedStorage.Shared.Game.MapFeatures.ScriptableRoots)

local FanAirflow = {}

type BladeVisual = {
	base: BasePart,
	ghost: BasePart,
	centerOffset: Vector3,
	centerToBlade: CFrame,
	originalTransparency: number,
}

type RootWatch = {
	connections: { RBXScriptConnection },
	attributes: { [BasePart]: RBXScriptConnection },
}

local fans: { [BasePart]: Attachment } = {}
local blades: { [BasePart]: BladeVisual } = {}
local rootWatches: { [Instance]: RootWatch } = {}
local unwatch: (() -> ())? = nil
local renderConnection: RBXScriptConnection? = nil
local visualFolder: Folder? = nil
local started = false

local function forgetBlade(blade: BasePart)
	local visual = blades[blade]
	if visual == nil then
		return
	end
	blades[blade] = nil
	visual.ghost:Destroy()
	if blade.LocalTransparencyModifier == 1 then
		blade.LocalTransparencyModifier = visual.originalTransparency
	end
end

local function forget(instance: Instance)
	if instance:IsA("BasePart") then
		forgetBlade(instance)
		for blade, visual in blades do
			if visual.base == instance then
				forgetBlade(blade)
			end
		end
	end
	local attachment = fans[instance :: BasePart]
	if attachment == nil then
		return
	end
	fans[instance :: BasePart] = nil
	attachment:Destroy()
end

local function isFan(instance: Instance): boolean
	return instance:IsA("BasePart")
		and (
			MapFeatures.Fan.EnabledNames[instance.Name] == true
			or instance:GetAttribute(MapFeatures.Attributes.Fan) == true
		)
end

local function isFanBlade(instance: Instance): boolean
	return instance:IsA("BasePart")
		and (
			instance.Name:find("propeller_trampoline_2_", 1, true) == 1
			or instance:GetAttribute(MapFeatures.Attributes.FanBlade) == true
		)
end

local function clearGameplayMetadata(instance: Instance)
	for name in instance:GetAttributes() do
		instance:SetAttribute(name, nil)
	end
	for _, tag in CollectionService:GetTags(instance) do
		CollectionService:RemoveTag(instance, tag)
	end
end

local function trackBlade(blade: BasePart, base: BasePart)
	if blades[blade] or not visualFolder then
		return
	end
	local center = base.CFrame.Rotation + blade:GetPivot().Position
	local ghost = blade:Clone()
	for _, child in ghost:GetChildren() do
		if
			child:IsA("DataModelMesh")
			or child:IsA("SurfaceAppearance")
			or child:IsA("Decal")
			or child:IsA("Texture")
		then
			clearGameplayMetadata(child)
			child:ClearAllChildren()
		else
			child:Destroy()
		end
	end
	clearGameplayMetadata(ghost)
	ghost.Name = "FanBladeVisual"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanTouch = false
	ghost.CanQuery = false
	ghost.LocalTransparencyModifier = 0
	ghost.Parent = visualFolder
	-- The authored blade stays in its assembly for collision and queries. Only
	-- this nonphysical local copy turns around its authored pivot.
	blades[blade] = {
		base = base,
		ghost = ghost,
		centerOffset = base.CFrame:PointToObjectSpace(center.Position),
		centerToBlade = center:ToObjectSpace(blade.CFrame),
		originalTransparency = blade.LocalTransparencyModifier,
	}
	blade.LocalTransparencyModifier = 1
end

local function track(instance: Instance)
	if isFanBlade(instance) then
		local base = instance.Parent
		if base and isFan(base) then
			trackBlade(instance :: BasePart, base :: BasePart)
		end
		return
	end
	if not instance:IsA("BasePart") or not isFan(instance) or fans[instance] then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "FanAirflowAttachment"
	attachment.Position = Vector3.new(0, instance.Size.Y / 2, 0)
	attachment.Parent = instance

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FanAirflowParticles"
	emitter.Speed = NumberRange.new(6, 8)
	emitter.Lifetime = NumberRange.new(0.8, 1.1)
	emitter.SpreadAngle = Vector2.new(6, 6)
	emitter.Rate = 5
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.4),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
	emitter.LightEmission = 0.4
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = attachment

	fans[instance] = attachment
	for _, child in instance:GetChildren() do
		if isFanBlade(child) then
			trackBlade(child :: BasePart, instance)
		end
	end
end

local function renderBlades()
	local degrees = (Workspace:GetServerTimeNow() * MapFeatures.Fan.BladeDegreesPerSecond) % 360
	for blade, visual in blades do
		if blade.Parent ~= visual.base or visual.base.Parent == nil then
			forgetBlade(blade)
			continue
		end
		local base = visual.base
		local axis = base:GetAttribute(MapFeatures.Attributes.FanAxis)
		local direction = if base:GetAttribute(MapFeatures.Attributes.FanDirection) == -1 then -1 else 1
		local angle = math.rad(degrees * direction)
		local spin = if axis == "X"
			then CFrame.Angles(angle, 0, 0)
			elseif axis == "Z" then CFrame.Angles(0, 0, angle)
			else CFrame.Angles(0, angle, 0)
		visual.ghost.CFrame = base.CFrame * CFrame.new(visual.centerOffset) * spin * visual.centerToBlade
	end
end

local function addRoot(root: Instance)
	if rootWatches[root] then
		return
	end
	local watch: RootWatch = { connections = {}, attributes = {} }
	rootWatches[root] = watch
	local function watchPart(instance: Instance)
		if instance:IsA("BasePart") and not watch.attributes[instance] then
			watch.attributes[instance] = instance.AttributeChanged:Connect(function(name)
				if name == MapFeatures.Attributes.Fan then
					if isFan(instance) then
						track(instance)
					else
						forget(instance)
					end
				elseif name == MapFeatures.Attributes.FanBlade then
					if isFanBlade(instance) then
						track(instance)
					else
						forgetBlade(instance)
					end
				end
			end)
		end
		track(instance)
	end
	table.insert(watch.connections, root.DescendantAdded:Connect(watchPart))
	table.insert(
		watch.connections,
		root.DescendantRemoving:Connect(function(instance)
			forget(instance)
			for part, connection in watch.attributes do
				if part == instance or part:IsDescendantOf(instance) then
					connection:Disconnect()
					watch.attributes[part] = nil
				end
			end
		end)
	)
	for _, instance in root:GetDescendants() do
		watchPart(instance)
	end
end

local function removeRoot(root: Instance)
	local watch = rootWatches[root]
	if watch then
		for _, connection in watch.connections do
			connection:Disconnect()
		end
		for _, connection in watch.attributes do
			connection:Disconnect()
		end
		rootWatches[root] = nil
	end
	for base in fans do
		if base:IsDescendantOf(root) or base.Parent == nil then
			forget(base)
		end
	end
	for blade in blades do
		if blade:IsDescendantOf(root) or blade.Parent == nil then
			forgetBlade(blade)
		end
	end
end

function FanAirflow.start()
	if started then
		return
	end
	started = true
	visualFolder = Instance.new("Folder")
	visualFolder.Name = "FanBladeVisuals"
	visualFolder.Parent = Workspace
	renderConnection = RunService.PreRender:Connect(renderBlades)
	unwatch = ScriptableRoots.watch(addRoot, removeRoot)
end

function FanAirflow.stop()
	started = false
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if unwatch then
		unwatch()
		unwatch = nil
	end
	for root in rootWatches do
		removeRoot(root)
	end
	for base in fans do
		forget(base)
	end
	for blade in blades do
		forgetBlade(blade)
	end
	if visualFolder then
		visualFolder:Destroy()
		visualFolder = nil
	end
end

return FanAirflow
