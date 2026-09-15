-- Description: Gives authored spinning paddles one bounded, damage-free push per player contact.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local MovementGuard = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("MovementGuard")
)
local MapFeatureKit = require(script.Parent.MapFeatureKit)

local SpinnerBump = {}
SpinnerBump.folderName = "Rotating"
SpinnerBump.instanceClass = "Folder"

type Visit = { root: BasePart, spinner: BasePart, bumped: boolean }
type Shove = { root: BasePart, spinner: BasePart, attachment: Attachment, expiresAt: number }

local contacts: { [BasePart]: BasePart } = {}
local activeSpinners: { [BasePart]: boolean } = {}
local visits: { [Player]: Visit } = {}
local shoves: { [Player]: Shove } = {}
local cooldowns: { [Player]: number } = {}
local roots: { Instance } = {}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function clearShove(player: Player)
	local shove = shoves[player]
	if shove then
		-- The velocity constraint is a child, so this destroys both owned objects.
		shove.attachment:Destroy()
		shoves[player] = nil
	end
end

function SpinnerBump.tickWorld(context: MapFeatureKit.Context)
	table.clear(contacts)
	table.clear(activeSpinners)
	table.clear(roots)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") and character:GetAttribute("CombatAlive") ~= false then
			table.insert(roots, root)
		end
	end
	overlap.FilterDescendantsInstances = roots
	if #roots == 0 then
		return
	end

	for _, group in context.instances do
		local assembly = group:FindFirstChild("Assembly")
		if assembly == nil or not assembly:IsA("Model") then
			continue
		end
		for name, enabled in MapFeatures.Spinner.EnabledNames do
			local spinner = if enabled then assembly:FindFirstChild(name) else nil
			if spinner and spinner:IsA("BasePart") then
				activeSpinners[spinner] = true
				-- Root-only contact excludes cosmetic/limb grazing. A small padded
				-- oriented box makes near-edge contacts register more reliably.
				local padding = Vector3.one * MapFeatures.Spinner.ContactPadding * 2
				for _, root in Workspace:GetPartBoundsInBox(spinner.CFrame, spinner.Size + padding, overlap) do
					contacts[root] = contacts[root] or spinner
				end
			end
		end
	end
end

local function bump(
	context: MapFeatureKit.Context,
	player: Player,
	spinner: BasePart,
	root: BasePart,
	humanoid: Humanoid
)
	local settings = MapFeatures.Spinner
	local center = spinner.CFrame:PointToWorldSpace(spinner.PivotOffset.Position)
	local offset = root.Position - center
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local outward = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	local tangent = Vector3.new(outward.Z, 0, -outward.X) * math.sign(settings.DegreesPerSecond)
	local direction = (tangent + outward * settings.OutwardBias).Unit
	local current = root.AssemblyLinearVelocity
	-- A target velocity, rather than an additive kick, prevents re-entry from
	-- stacking speed. A stronger fan/jump-pad ascent remains intact.
	local target = direction * settings.KnockbackSpeed + Vector3.yAxis * math.max(current.Y, settings.UpwardSpeed)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = target
	-- A brief hold clears the moving paddle before the normal controller slows
	-- the shove. It is never refreshed while the player remains in contact.
	local attachment = Instance.new("Attachment")
	attachment.Name = "SpinnerShoveAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "SpinnerShoveVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitsEnabled = false
	velocity.VectorVelocity = target
	velocity.Parent = attachment
	shoves[player] = {
		root = root,
		spinner = spinner,
		attachment = attachment,
		expiresAt = context.now + settings.ShoveSeconds,
	}
	MovementGuard.allow(root, "Spinner", settings.GuardSeconds, settings.KnockbackSpeed * 1.3, target.Y * 1.3, spinner)
end

function SpinnerBump.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	local character = root.Parent
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		humanoid == nil
		or humanoid.Health <= 0
		or root.Anchored
		or (character and character:GetAttribute("CombatAlive") == false)
	then
		SpinnerBump.forget(player)
		return
	end

	local visit = visits[player]
	local shove = shoves[player]
	if (visit and visit.root ~= root) or (shove and shove.root ~= root) then
		SpinnerBump.forget(player)
		visit = nil
		shove = nil
	end
	if shove and (context.now >= shove.expiresAt or not activeSpinners[shove.spinner]) then
		clearShove(player)
	end
	local spinner = contacts[root]
	if visit and visit.spinner ~= spinner then
		visits[player] = nil
		visit = nil
	end
	if spinner == nil then
		return
	end
	if visit == nil then
		visit = { root = root, spinner = spinner, bumped = false }
		visits[player] = visit
	end
	if not visit.bumped and shoves[player] == nil and context.now >= (cooldowns[player] or 0) then
		visit.bumped = true
		cooldowns[player] = context.now + MapFeatures.Spinner.RetriggerCooldown
		bump(context, player, spinner, root, humanoid)
	end
end

function SpinnerBump.forget(player: Player?)
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
	table.clear(activeSpinners)
	table.clear(visits)
	table.clear(cooldowns)
	table.clear(roots)
	overlap.FilterDescendantsInstances = {}
end

return SpinnerBump
