--!strict
-- Rising wind particles and client-only spinning blades make authored fans readable.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
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
local fanTransforms: { [BasePart]: RBXScriptConnection } = {}
local blades: { [BasePart]: BladeVisual } = {}
local rootWatches: { [Instance]: RootWatch } = {}
local unwatch: (() -> ())? = nil
local renderConnection: RBXScriptConnection? = nil
local motionConnection: RBXScriptConnection? = nil
local budgetConnection: RBXScriptConnection? = nil
local budgetElapsed = 0
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
	local transform = fanTransforms[instance :: BasePart]
	if transform then
		transform:Disconnect()
		fanTransforms[instance :: BasePart] = nil
	end
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

local function updateAirflow(base: BasePart, attachment: Attachment)
	local axis = base:GetAttribute(MapFeatures.Attributes.FanAxis)
	local direction = base:GetAttribute(MapFeatures.Attributes.FanDirection)
	local sign = if typeof(direction) == "number" and direction < 0 then -1 else 1
	local localAxis = if axis == "X" then Vector3.xAxis elseif axis == "Z" then Vector3.zAxis else Vector3.yAxis
	local localDirection = if axis == "X"
			or axis == "Y"
			or axis == "Z"
		then localAxis * sign
		else base.CFrame:VectorToObjectSpace(Vector3.yAxis)
	local offset = if axis == "X"
			or axis == "Y"
			or axis == "Z"
		then localAxis * sign * (base.Size * localAxis).Magnitude / 2
		else Vector3.new(0, base.Size.Y / 2, 0)
	local reference = if math.abs(localDirection:Dot(Vector3.xAxis)) < 0.9 then Vector3.xAxis else Vector3.zAxis
	local right = reference:Cross(localDirection).Unit
	attachment.CFrame = CFrame.fromMatrix(offset, right, localDirection, right:Cross(localDirection))
end

local function updateParticleTravel(base: BasePart, attachment: Attachment)
	local emitter = attachment:FindFirstChild("FanAirflowParticles")
	if not emitter or not emitter:IsA("ParticleEmitter") then
		return
	end
	local axis = base:GetAttribute(MapFeatures.Attributes.FanAxis)
	local height = if axis == "X"
			or axis == "Y"
			or axis == "Z"
		then base:GetAttribute(MapFeatures.Attributes.FanColumnHeight)
		else nil
	if height == nil then
		height = MapFeatures.Fan.ColumnHeight
	end
	emitter:Clear()
	if typeof(height) ~= "number" or height ~= height or height < 1 or height == math.huge then
		emitter.Enabled = false
		return
	end
	-- Keep the whole particle inside even a one-stud authored column.
	local maximumSpeed = math.min(8, (height - 0.15) / 1.1)
	emitter.Speed = NumberRange.new(maximumSpeed * 0.75, maximumSpeed)
	emitter.Lifetime = NumberRange.new(0.8, 1.1)
	emitter.Enabled = true
end

local function updateBudget()
	local camera = Workspace.CurrentCamera
	local near: { { base: BasePart, distance: number } } = {}
	if camera then
		for base in fans do
			local distance = math.max(0, (camera.CFrame.Position - base.Position).Magnitude - base.Size.Magnitude / 2)
			if base:IsDescendantOf(Workspace) and distance <= 140 then
				table.insert(near, { base = base, distance = distance })
			end
		end
		table.sort(near, function(a, b)
			return a.distance < b.distance
		end)
	end
	local selected: { [BasePart]: boolean } = {}
	for index = 1, math.min(8, #near) do
		selected[near[index].base] = true
	end
	for base, attachment in fans do
		local emitter = attachment:FindFirstChild("FanAirflowParticles")
		if emitter and emitter:IsA("ParticleEmitter") then
			emitter.Rate = if selected[base] then (if GuiService.ReducedMotionEnabled then 2 else 5) else 0
		end
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
	attachment.Parent = instance

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FanAirflowParticles"
	emitter.Speed = NumberRange.new(6, 8)
	emitter.Lifetime = NumberRange.new(0.8, 1.1)
	emitter.SpreadAngle = Vector2.new(2, 2)
	emitter.Rate = 0
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
	updateAirflow(instance, attachment)
	updateParticleTravel(instance, attachment)
	fanTransforms[instance] = instance:GetPropertyChangedSignal("CFrame"):Connect(function()
		if instance:GetAttribute(MapFeatures.Attributes.FanAxis) == nil then
			updateAirflow(instance, attachment)
		end
	end)
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
				elseif name == MapFeatures.Attributes.FanAxis or name == MapFeatures.Attributes.FanDirection then
					local attachment = fans[instance]
					if attachment then
						updateAirflow(instance, attachment)
						if name == MapFeatures.Attributes.FanAxis then
							updateParticleTravel(instance, attachment)
						end
					end
				elseif name == MapFeatures.Attributes.FanColumnHeight then
					local attachment = fans[instance]
					if attachment then
						updateParticleTravel(instance, attachment)
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
	motionConnection = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
		updateBudget()
	end)
	budgetElapsed = 0
	budgetConnection = RunService.Heartbeat:Connect(function(delta)
		budgetElapsed += delta
		if budgetElapsed >= 0.5 then
			budgetElapsed = 0
			updateBudget()
		end
	end)
	unwatch = ScriptableRoots.watch(addRoot, removeRoot)
	updateBudget()
end

function FanAirflow.stop()
	started = false
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if motionConnection then
		motionConnection:Disconnect()
		motionConnection = nil
	end
	if budgetConnection then
		budgetConnection:Disconnect()
		budgetConnection = nil
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
