-- Description: Consolidates shove physics and spatial queries for ring bumpers, spinner paddles, and rotating assemblies into a unified shove feature.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local MovementGuard = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("MovementGuard")
)
local RotatingPlatforms = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("RotatingPlatforms")
)
local ShoveTuning = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("ShoveTuning")
)
local Parts = require(script.Parent.FeatureParts)
local MapFeatureKit = require(script.Parent.MapFeatureKit)

local ShoveFeature = {}
ShoveFeature.folderName = "Rotating"
ShoveFeature.folderNames = { "Bumpers", "Motion", "Rotating" }
ShoveFeature.instanceClass = "Folder"

type BumperContact = {
	kind: "Bumper",
	part: BasePart,
}

type SpinnerContact = {
	kind: "Spinner",
	part: BasePart,
}

type RotorContact = {
	kind: "Rotor",
	part: BasePart,
	rotor: RotatingPlatforms.LocalRotor,
	platform: RotatingPlatforms.Platform,
}

type Contact = BumperContact | SpinnerContact | RotorContact

type Visit = { root: BasePart, contactPart: BasePart, bumped: boolean }
type Shove = { root: BasePart, contactPart: BasePart, attachment: Attachment, expiresAt: number }

local contacts: { [BasePart]: Contact } = {}
local activeParts: { [BasePart]: boolean } = {}
local bumpersByAssembly: { [Instance]: { BasePart } } = {}
local visits: { [Player]: Visit } = {}
local shoves: { [Player]: Shove } = {}
local cooldowns: { [Player]: number } = {}
local roots: { Instance } = {}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function clearShove(player: Player)
	local shove = shoves[player]
	if shove then
		shove.attachment:Destroy()
		shoves[player] = nil
	end
end

local function bumpersFor(group: Instance): { BasePart }
	local cached = bumpersByAssembly[group]
	if cached and #cached > 0 then
		return cached
	end
	local found: { BasePart } = {}
	if group:IsA("BasePart") then
		if group:GetAttribute(MapFeatures.Attributes.Bumper) == true then
			table.insert(found, group)
		else
			for _, prefix in MapFeatures.Bumper.NamePrefixes do
				if group.Name:find(prefix, 1, true) == 1 then
					table.insert(found, group)
					break
				end
			end
		end
	end
	for _, descendant in group:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		if descendant:GetAttribute(MapFeatures.Attributes.Bumper) == true then
			table.insert(found, descendant)
			continue
		end
		for _, prefix in MapFeatures.Bumper.NamePrefixes do
			if descendant.Name:find(prefix, 1, true) == 1 then
				table.insert(found, descendant)
				break
			end
		end
	end
	bumpersByAssembly[group] = found
	return found
end

local function isNearAnyRoot(partPos: Vector3, reach: number): boolean
	local reachSq = reach * reach
	for _, rootInst in roots do
		local root = rootInst :: BasePart
		local diff = root.Position - partPos
		if diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z <= reachSq then
			return true
		end
	end
	return false
end

local function testBumper(bumper: BasePart)
	local reach = bumper.Size.Magnitude * 0.5 + MapFeatures.Bumper.ContactPadding * 2 + 3
	if not isNearAnyRoot(bumper.Position, reach) then
		return
	end
	local padding = Vector3.one * MapFeatures.Bumper.ContactPadding * 2
	local touching = if bumper:GetAttribute(MapFeatures.Attributes.ShoveContact) == "mesh"
		then Workspace:GetPartsInPart(bumper, overlap)
		else Workspace:GetPartBoundsInBox(bumper.CFrame, bumper.Size + padding, overlap)
	for _, root in touching do
		if contacts[root] == nil then
			contacts[root] = { kind = "Bumper", part = bumper }
		end
	end
end

local function testSpinner(spinner: BasePart)
	local reach = spinner.Size.Magnitude * 0.5 + MapFeatures.Spinner.ContactPadding * 2 + 3
	if not isNearAnyRoot(spinner.Position, reach) then
		return
	end
	local padding = Vector3.one * MapFeatures.Spinner.ContactPadding * 2
	for _, root in Workspace:GetPartBoundsInBox(spinner.CFrame, spinner.Size + padding, overlap) do
		if contacts[root] == nil then
			contacts[root] = { kind = "Spinner", part = spinner }
		end
	end
end

local function testRotorPart(platform: RotatingPlatforms.Platform, rotor: RotatingPlatforms.LocalRotor, part: BasePart)
	if part.Parent == nil then
		return
	end
	local reach = part.Size.Magnitude * 0.5 + MapFeatures.RotorBump.ContactPadding * 2 + 3
	if not isNearAnyRoot(part.Position, reach) then
		return
	end
	local padding = Vector3.one * MapFeatures.RotorBump.ContactPadding * 2
	local touching = if rotor.part:GetAttribute(MapFeatures.Attributes.ShoveContact) == "mesh"
		then Workspace:GetPartsInPart(part, overlap)
		else Workspace:GetPartBoundsInBox(part.CFrame, part.Size + padding, overlap)
	for _, root in touching do
		if contacts[root] == nil then
			contacts[root] = {
				kind = "Rotor",
				part = part,
				rotor = rotor,
				platform = platform,
			}
		end
	end
end

function ShoveFeature.tickWorld(context: MapFeatureKit.Context)
	for assembly in bumpersByAssembly do
		if not assembly:IsDescendantOf(Workspace) then
			bumpersByAssembly[assembly] = nil
		end
	end
	table.clear(contacts)
	table.clear(activeParts)
	table.clear(roots)

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			character
			and root
			and root:IsA("BasePart")
			and not root.Anchored
			and character:GetAttribute("CombatAlive") ~= false
		then
			table.insert(roots, root)
		end
	end
	overlap.FilterDescendantsInstances = roots
	if #roots == 0 then
		return
	end

	for _, group in context.instances do
		for _, bumper in bumpersFor(group) do
			activeParts[bumper] = true
			testBumper(bumper)
		end
		for name, enabled in MapFeatures.Spinner.EnabledNames do
			local spinner = if enabled then group:FindFirstChild(name, true) else nil
			if spinner and spinner:IsA("BasePart") then
				activeParts[spinner] = true
				testSpinner(spinner)
			end
		end
	end

	for _, platform in RotatingPlatforms.all() do
		for _, rotor in platform.localRotors do
			if not rotor.shove then
				continue
			end
			activeParts[rotor.part] = true
			testRotorPart(platform, rotor, rotor.part)
			for _, follower in rotor.followers do
				activeParts[follower.part] = true
				testRotorPart(platform, rotor, follower.part)
			end
		end
	end
end

local function applyBumper(
	context: MapFeatureKit.Context,
	bumper: BasePart,
	root: BasePart
): (Vector3, number, string, number, number)
	local attributes = MapFeatures.Attributes
	local settings = ShoveTuning.resolve(
		MapFeatures.Bumper,
		bumper:GetAttribute(attributes.ShoveSpeed),
		bumper:GetAttribute(attributes.ShoveUpwardSpeed),
		bumper:GetAttribute(attributes.ShoveSeconds)
	)
	local offset = root.Position - bumper.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	local current = root.AssemblyLinearVelocity
	local target = direction * settings.KnockbackSpeed + Vector3.yAxis * math.max(current.Y, settings.UpwardSpeed)
	local guardSeconds =
		math.max(settings.GuardSeconds, Parts.number(bumper, "GuardSeconds", settings.GuardSeconds, 0.3, 10))
	local retriggerCooldown = Parts.number(bumper, "RetriggerCooldown", MapFeatures.Bumper.RetriggerCooldown, 0.1, 10)
	return target, settings.KnockbackSpeed, "Bumper", guardSeconds, retriggerCooldown
end

local function applySpinner(spinner: BasePart, root: BasePart): (Vector3, number, string, number, number)
	local settings = MapFeatures.Spinner
	local center = spinner.CFrame:PointToWorldSpace(spinner.PivotOffset.Position)
	local offset = root.Position - center
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local outward = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	local tangent = Vector3.new(outward.Z, 0, -outward.X) * math.sign(settings.DegreesPerSecond)
	local direction = (tangent + outward * settings.OutwardBias).Unit
	local current = root.AssemblyLinearVelocity
	local target = direction * settings.KnockbackSpeed + Vector3.yAxis * math.max(current.Y, settings.UpwardSpeed)
	return target, settings.KnockbackSpeed, "Spinner", settings.GuardSeconds, settings.RetriggerCooldown
end

local function applyRotor(contact: RotorContact, root: BasePart): (Vector3, number, string, number, number)
	local settings = MapFeatures.RotorBump
	local attributes = MapFeatures.Attributes
	local response = ShoveTuning.resolve(
		settings,
		contact.rotor.shoveSpeed,
		contact.rotor.part:GetAttribute(attributes.ShoveUpwardSpeed),
		contact.rotor.part:GetAttribute(attributes.ShoveSeconds)
	)
	local now = Workspace:GetServerTimeNow()
	local center = RotatingPlatforms.rotorPoseAt(contact.platform, contact.rotor, now).Position
	local offset = root.Position - center
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local outward = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	local surface = RotatingPlatforms.surfaceVelocityAt(contact.platform, contact.rotor, root.Position, now)
	local flatSurface = Vector3.new(surface.X, 0, surface.Z)
	local direction = if flatSurface.Magnitude >= settings.MinimumSurfaceSpeed
		then (flatSurface.Unit + outward * settings.OutwardBias).Unit
		else outward
	local current = root.AssemblyLinearVelocity
	local target = direction * response.KnockbackSpeed + Vector3.yAxis * math.max(current.Y, response.UpwardSpeed)
	local guardSeconds = math.max(
		response.GuardSeconds,
		Parts.number(contact.rotor.part, "GuardSeconds", response.GuardSeconds, 0.3, 10)
	)
	local retriggerCooldown = Parts.number(contact.rotor.part, "RetriggerCooldown", settings.RetriggerCooldown, 0.1, 10)
	return target, response.KnockbackSpeed, "RotorBump", guardSeconds, retriggerCooldown
end

local function bump(
	context: MapFeatureKit.Context,
	player: Player,
	contact: Contact,
	root: BasePart,
	humanoid: Humanoid
)
	local target: Vector3
	local speed: number
	local guardName: string
	local guardSeconds: number
	local retriggerCooldown: number
	local shoveDuration = 0.25
	local attachmentName = "BumperShoveAttachment"
	local velocityName = "BumperShoveVelocity"

	if contact.kind == "Bumper" then
		target, speed, guardName, guardSeconds, retriggerCooldown = applyBumper(context, contact.part, root)
		shoveDuration = ShoveTuning.resolve(
			MapFeatures.Bumper,
			contact.part:GetAttribute(MapFeatures.Attributes.ShoveSpeed),
			contact.part:GetAttribute(MapFeatures.Attributes.ShoveUpwardSpeed),
			contact.part:GetAttribute(MapFeatures.Attributes.ShoveSeconds)
		).ShoveSeconds
		attachmentName = "BumperShoveAttachment"
		velocityName = "BumperShoveVelocity"
	elseif contact.kind == "Spinner" then
		target, speed, guardName, guardSeconds, retriggerCooldown = applySpinner(contact.part, root)
		shoveDuration = MapFeatures.Spinner.ShoveSeconds
		attachmentName = "SpinnerShoveAttachment"
		velocityName = "SpinnerShoveVelocity"
	else
		target, speed, guardName, guardSeconds, retriggerCooldown = applyRotor(contact, root)
		shoveDuration = ShoveTuning.resolve(
			MapFeatures.RotorBump,
			contact.rotor.shoveSpeed,
			contact.rotor.part:GetAttribute(MapFeatures.Attributes.ShoveUpwardSpeed),
			contact.rotor.part:GetAttribute(MapFeatures.Attributes.ShoveSeconds)
		).ShoveSeconds
		attachmentName = "RotorShoveAttachment"
		velocityName = "RotorShoveVelocity"
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = target

	local attachment = Instance.new("Attachment")
	attachment.Name = attachmentName
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = velocityName
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitsEnabled = false
	velocity.VectorVelocity = target
	velocity.Parent = attachment

	shoves[player] = {
		root = root,
		contactPart = contact.part,
		attachment = attachment,
		expiresAt = context.now + shoveDuration,
	}
	cooldowns[player] = context.now + retriggerCooldown

	MovementGuard.allow(root, guardName, guardSeconds, speed * 1.3, target.Y * 1.3, contact.part)

	if contact.kind == "Bumper" then
		Network.fire("BumperHit", nil, contact.part)
	elseif contact.kind == "Rotor" then
		if contact.rotor.part:GetAttribute(MapFeatures.Attributes.ImpactVisual) == true then
			Network.fire("HazardVisual", nil, contact.part, "impact", 0.25)
		end
	end
end

function ShoveFeature.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	local character = root.Parent
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		humanoid == nil
		or humanoid.Health <= 0
		or root.Anchored
		or (character and character:GetAttribute("CombatAlive") == false)
	then
		ShoveFeature.forget(player)
		return
	end

	local visit = visits[player]
	local shove = shoves[player]
	if (visit and visit.root ~= root) or (shove and shove.root ~= root) then
		ShoveFeature.forget(player)
		visit = nil
		shove = nil
	end
	if shove and (context.now >= shove.expiresAt or not activeParts[shove.contactPart]) then
		clearShove(player)
	end

	local contact = contacts[root]
	local contactPart = if contact then contact.part else nil
	if visit and visit.contactPart ~= contactPart then
		visits[player] = nil
		visit = nil
	end
	if contact == nil or contactPart == nil then
		return
	end
	if visit == nil then
		visit = { root = root, contactPart = contactPart, bumped = false }
		visits[player] = visit
	end
	if not visit.bumped and shoves[player] == nil and context.now >= (cooldowns[player] or 0) then
		visit.bumped = true
		bump(context, player, contact, root, humanoid)
	end
end

function ShoveFeature.forget(player: Player?)
	if player then
		clearShove(player)
		local visit = visits[player]
		if visit then
			contacts[visit.root] = nil
		end
		visits[player] = nil
		cooldowns[player] = nil
		return
	end
	for existing in shoves do
		clearShove(existing)
	end
	table.clear(contacts)
	table.clear(activeParts)
	table.clear(visits)
	table.clear(cooldowns)
	table.clear(roots)
	overlap.FilterDescendantsInstances = {}
end

return ShoveFeature
