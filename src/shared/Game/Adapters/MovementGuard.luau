-- Owns server movement acceptance history and bounded allowances for server-issued motion.
--!strict

local Workspace = game:GetService("Workspace")
local Config = require(script.Parent.Parent.Parent.Parent.Config.Gameplay.Combat).MovementValidation
local Budget = require(script.Parent.Parent.MapFeatures.MovementBudget)
local Rotating = require(script.Parent.Parent.MapFeatures.RotatingPlatforms)
local Guard = {}
local histories = setmetatable({}, { __mode = "k" }) :: { [BasePart]: any }
local corrections = 0

local function finite(v: Vector3): boolean
	return Budget.finite(v, Config.CoordinateLimit)
end

function Guard.reset(root: BasePart)
	if not finite(root.Position) or not finite(root.CFrame.LookVector) or not finite(root.CFrame.UpVector) then
		return
	end
	local now = os.clock()
	histories[root] = {
		budget = Budget.new(root.Position, now, Config.BurstStuds),
		safe = root.CFrame,
		ground = root.CFrame,
		groundedAt = now,
		checkedAt = now,
		allowances = {},
		pivotOffset = if root.Parent and root.Parent:IsA("Model")
			then root.CFrame:ToObjectSpace(root.Parent:GetPivot())
			else CFrame.identity,
	}
end

function Guard.allow(
	root: BasePart,
	key: string,
	seconds: number,
	horizontal: number,
	upward: number,
	wallObstacle: BasePart?
)
	if not histories[root] then
		Guard.reset(root)
	end
	local history = histories[root]
	if history then
		history.allowances[key] = {
			untilAt = os.clock() + seconds,
			horizontal = horizontal,
			upward = upward,
			wallObstacle = wallObstacle,
		}
	end
end

local function recover(root: BasePart, history: any, grounded: boolean): boolean
	corrections += 1
	if history then
		local target = if grounded then history.ground else history.safe
		local model = root.Parent
		if model and model:IsA("Model") then
			model:PivotTo(target * history.pivotOffset)
		end
		root.CFrame = target
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		history.budget.position = target.Position
		history.budget.horizontal = 0
		history.budget.vertical = 0
		history.budget.time = os.clock()
		history.safe = target
		if grounded then
			history.groundedAt = os.clock()
		end
	end
	return false
end

function Guard.check(root: BasePart, excluded: { Instance }): boolean
	local history = histories[root]
	if
		not finite(root.Position)
		or not finite(root.CFrame.LookVector)
		or not finite(root.CFrame.UpVector)
		or not finite(root.AssemblyLinearVelocity)
		or not finite(root.AssemblyAngularVelocity)
	then
		return recover(root, history, false)
	end
	if history == nil then
		Guard.reset(root)
		return true
	end
	local now = os.clock()
	local delta = root.Position - history.budget.position
	if now - history.checkedAt < Config.SampleSeconds and delta.Magnitude < Config.BurstStuds then
		return true
	end
	history.checkedAt = now
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local base = if humanoid then humanoid.WalkSpeed else 16
	local horizontal = base * Config.WalkTolerance + Config.PlatformSpeedAllowance
	local upward = Config.UpwardSpeed
	local airborneAllowance = false
	local wallExcluded: { Instance }? = nil
	for key, allowance in history.allowances do
		if now > allowance.untilAt then
			history.allowances[key] = nil
		else
			horizontal = math.max(horizontal, allowance.horizontal)
			upward = math.max(upward, allowance.upward)
			airborneAllowance = true
			if allowance.wallObstacle then
				wallExcluded = wallExcluded or table.clone(excluded)
				table.insert(wallExcluded, allowance.wallObstacle)
			end
		end
	end
	for _, platform in Rotating.all() do
		if
			(root.Position - platform.referencePivot.Position).Magnitude
			<= platform.reach + Config.PlatformReachPadding
		then
			horizontal = math.max(
				horizontal,
				base * Config.WalkTolerance + math.rad(math.abs(platform.degreesPerSecond)) * platform.reach
			)
		end
	end
	local from = history.budget.position
	if not Budget.step(history.budget, root.Position, now, horizontal, upward, Config.BurstStuds) then
		return recover(root, history, false)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = wallExcluded or excluded
	params.RespectCanCollide = true
	if delta.Magnitude > Config.WallCheckMinimumStuds then
		local hit = Workspace:Spherecast(from, Config.WallProbeRadius, delta, params)
		if hit and math.abs(hit.Normal.Y) < 0.5 and hit.Distance + Config.WallToleranceStuds < delta.Magnitude then
			return recover(root, history, false)
		end
	end
	-- The moving obstacle is exempt only from this launch's wall sweep. It must
	-- remain visible to the ordinary ground/support check.
	params.FilterDescendantsInstances = excluded
	local groundDistance = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2 + Config.GroundToleranceStuds
	local support = Workspace:Raycast(root.Position, Vector3.new(0, -groundDistance, 0), params)
	if support and support.Normal.Y > 0.5 then
		history.groundedAt = now
		history.ground = root.CFrame
	elseif
		not airborneAllowance
		and now - history.groundedAt > Config.MaxAirborneSeconds
		and root.AssemblyLinearVelocity.Y > -Config.MinimumFallSpeed
	then
		return recover(root, history, true)
	end
	history.safe = root.CFrame
	return true
end

function Guard.takeCorrections(): number
	local count = corrections
	corrections = 0
	return count
end

return Guard
