--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AimAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AimAssist"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Debug"))

type SimEvent = {
	kind: string,
	projectileId: string?,
	position: Vector3?,
	normal: Vector3?,
}

type BounceNormal = {
	from: Vector3,
	to: Vector3,
	expires: number,
}

local DebugVisuals = {}

local PHASE_NAMES: { [number]: string } = {
	[0] = "Held",
	[1] = "Windup",
	[2] = "InFlight",
	[3] = "Bouncing",
	[4] = "Rolling",
	[5] = "Recalling",
	[6] = "Free",
}

local LINE_THICKNESS = 0.035
local CONE_SLICES = 8
local RING_SEGMENTS = 16
local TRAJECTORY_POINTS = 14
local MAX_BOUNCE_NORMALS = 12
local BOUNCE_NORMAL_LIFETIME = 2.5

local rootFolder: Folder? = nil
local lines: { Part } = {}
local lineCursor = 0
local coneSlices: { Part } = {}
local coneCursor = 0
local labels: { [BasePart]: BillboardGui } = {}
local trajectories: { [BasePart]: { Vector3 } } = {}
local bounceNormals: { BounceNormal } = {}
local started = false
local accumulator = 0

local function enabled(): boolean
	return Debug.StudioVisuals == true and RunService:IsStudio()
end

local function anyVisualEnabled(): boolean
	return Debug.AimAssistCones == true
		or Debug.AimAssistTargetRange == true
		or Debug.ThrowOriginMaxOffset == true
		or Debug.PickupRadius == true
		or Debug.RecallRange == true
		or Debug.PhaseLabels == true
		or Debug.Trajectory == true
		or Debug.CollisionRadius == true
		or Debug.SelectedTarget == true
		or Debug.BounceNormals == true
end

local function clearTransientVisuals()
	if rootFolder then
		rootFolder:Destroy()
	end
	rootFolder = nil
	lines = {}
	lineCursor = 0
	coneSlices = {}
	coneCursor = 0
	for _, label in labels do
		label:Destroy()
	end
	labels = {}
	trajectories = {}
	bounceNormals = {}
end

local function ensureRoot(): Folder
	local camera = Workspace.CurrentCamera
	local parent = camera or Workspace
	local existing = parent:FindFirstChild("CombatDebugVisuals")
	if existing and existing:IsA("Folder") then
		rootFolder = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "CombatDebugVisuals"
	folder.Parent = parent
	rootFolder = folder
	return folder
end

local function nextConeSlice(): Part
	coneCursor += 1
	local slice = coneSlices[coneCursor]
	if slice then
		slice.Transparency = 0.88
		return slice
	end

	slice = Instance.new("Part")
	slice.Name = "DebugConeSlice"
	slice.Shape = Enum.PartType.Cylinder
	slice.Anchored = true
	slice.CanCollide = false
	slice.CanQuery = false
	slice.CanTouch = false
	slice.CastShadow = false
	slice.Material = Enum.Material.Neon
	slice.Parent = ensureRoot()
	coneSlices[coneCursor] = slice
	return slice
end

local function nextLine(): Part
	lineCursor += 1
	local line = lines[lineCursor]
	if line then
		line.Transparency = 0
		return line
	end

	line = Instance.new("Part")
	line.Name = "DebugLine"
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.CastShadow = false
	line.Material = Enum.Material.Neon
	line.Parent = ensureRoot()
	lines[lineCursor] = line
	return line
end

local function hideUnusedLines()
	for index = lineCursor + 1, #lines do
		lines[index].Transparency = 1
	end
	for index = coneCursor + 1, #coneSlices do
		coneSlices[index].Transparency = 1
	end
end

local function drawLine(from: Vector3, to: Vector3, color: Color3, thickness: number?, transparency: number?)
	local delta = to - from
	local length = delta.Magnitude
	if length <= 1e-4 then
		return
	end
	local line = nextLine()
	line.Color = color
	line.Transparency = transparency or 0.15
	line.Size = Vector3.new(thickness or LINE_THICKNESS, thickness or LINE_THICKNESS, length)
	line.CFrame = CFrame.lookAt(from + delta * 0.5, to)
end

local function drawCircle(
	center: Vector3,
	axisA: Vector3,
	axisB: Vector3,
	radius: number,
	color: Color3,
	transparency: number?
)
	local previous = center + axisA * radius
	for index = 1, RING_SEGMENTS do
		local angle = math.pi * 2 * index / RING_SEGMENTS
		local point = center + axisA * math.cos(angle) * radius + axisB * math.sin(angle) * radius
		drawLine(previous, point, color, LINE_THICKNESS, transparency)
		previous = point
	end
end

local function drawSphereRings(center: Vector3, radius: number, color: Color3, transparency: number?)
	drawCircle(center, Vector3.xAxis, Vector3.yAxis, radius, color, transparency)
	drawCircle(center, Vector3.xAxis, Vector3.zAxis, radius, color, transparency)
	drawCircle(center, Vector3.zAxis, Vector3.yAxis, radius, color, transparency)
end

local function drawGroundCircle(center: Vector3, radius: number, color: Color3, transparency: number?)
	drawCircle(center, Vector3.xAxis, Vector3.zAxis, radius, color, transparency)
end

local function drawCone(camera: Camera, angleDeg: number, range: number, color: Color3, transparency: number?)
	local origin = camera.CFrame.Position
	local forward = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	local up = camera.CFrame.UpVector
	local endCenter = origin + forward * range

	for index = 1, CONE_SLICES do
		local nearT = (index - 1) / CONE_SLICES
		local farT = index / CONE_SLICES
		local midT = (nearT + farT) * 0.5
		local thickness = range / CONE_SLICES
		local radius = math.tan(math.rad(angleDeg)) * range * midT
		local center = origin + forward * range * midT
		local slice = nextConeSlice()
		slice.Color = color
		slice.Transparency = transparency or 0.88
		slice.Size = Vector3.new(thickness, math.max(radius * 2, 0.05), math.max(radius * 2, 0.05))
		-- Cylinder length is its local X axis. Align that axis with camera forward.
		slice.CFrame = CFrame.fromMatrix(center, forward, up, -right)
	end

	local radius = math.tan(math.rad(angleDeg)) * range
	drawCircle(endCenter, right, up, radius, color, 0.35)
	drawLine(origin, endCenter, color, LINE_THICKNESS, 0.55)
end

local function hasHeldBall(balls: Instance?): boolean
	if balls == nil then
		return false
	end
	local localId = tostring(Players.LocalPlayer.UserId)
	for _, ball in balls:GetChildren() do
		if ball:GetAttribute("hb") == localId then
			return true
		end
	end
	return false
end

local function findSelectedTarget(camera: Camera, character: Model?, balls: Instance?): Model?
	if character == nil then
		return nil
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, balls :: any }
	rayParams.RespectCanCollide = true

	local best: Model? = nil
	local bestAngle = math.huge
	local look = camera.CFrame.LookVector
	for _, player in Players:GetPlayers() do
		local target = player.Character
		if player == Players.LocalPlayer or target == nil then
			continue
		end
		local root = target:FindFirstChild("HumanoidRootPart")
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if
			root == nil
			or not root:IsA("BasePart")
			or humanoid == nil
			or target:GetAttribute("CombatAlive") == false
		then
			continue
		end
		local offset = root.Position - camera.CFrame.Position
		local distance = offset.Magnitude
		if distance <= 0 or distance > Combat.Dodgeball.TargetSelectRange then
			continue
		end
		local angle = math.deg(math.acos(math.clamp(look:Dot(offset.Unit), -1, 1)))
		local obstruction = Workspace:Raycast(camera.CFrame.Position, offset, rayParams)
		local visible = obstruction == nil or obstruction.Instance:IsDescendantOf(target)
		if visible and angle <= AimAssist.Mouse.SelectionConeDeg and angle < bestAngle then
			best = target
			bestAngle = angle
		end
	end
	return best
end

local function labelFor(ball: BasePart): BillboardGui
	local label = labels[ball]
	if label then
		return label
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DebugPhaseLabel"
	billboard.Adornee = ball
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(140, 34)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, Combat.Dodgeball.Radius + 1.5, 0)

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 0.35
	text.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	text.BorderSizePixel = 0
	text.Font = Enum.Font.GothamMedium
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextScaled = true
	text.Size = UDim2.fromScale(1, 1)
	text.Parent = billboard

	billboard.Parent = ensureRoot()
	labels[ball] = billboard
	return billboard
end

local function updateLabels(balls: Instance?)
	if not Debug.PhaseLabels then
		for _, label in labels do
			label:Destroy()
		end
		labels = {}
		return
	end

	local live: { [BasePart]: boolean } = {}
	if balls then
		for _, child in balls:GetChildren() do
			if not child:IsA("BasePart") then
				continue
			end
			live[child] = true
			if Debug.PhaseLabels then
				local phase = (child:GetAttribute("ph") :: number?) or 6
				local heldBy = child:GetAttribute("hb")
				local label = labelFor(child)
				local text = label:FindFirstChild("Text")
				if text and text:IsA("TextLabel") then
					text.Text = `{child.Name}\n{PHASE_NAMES[phase] or "?"}{if heldBy then ` by {heldBy}` else ""}`
				end
				label.Enabled = true
			end
		end
	end

	for ball, label in labels do
		if not live[ball] then
			label:Destroy()
			labels[ball] = nil
		end
	end
end

local function updateTrajectory(ball: BasePart)
	local history = trajectories[ball]
	if history == nil then
		history = {}
		trajectories[ball] = history
	end

	local position = ball.Position
	local last = history[#history]
	if last == nil or (position - last).Magnitude >= 0.35 then
		table.insert(history, position)
		while #history > TRAJECTORY_POINTS do
			table.remove(history, 1)
		end
	end

	for index = 2, #history do
		local alpha = index / #history
		drawLine(history[index - 1], history[index], Color3.fromRGB(255, 220, 80), 0.025, 0.65 - alpha * 0.35)
	end
end

local function drawBallDebug(balls: Instance?)
	if not Debug.Trajectory then
		trajectories = {}
	end

	if balls == nil then
		return
	end

	local live: { [BasePart]: boolean } = {}
	for _, child in balls:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end

		live[child] = true
		local phase = (child:GetAttribute("ph") :: number?) or 6
		local position = child.Position
		if Debug.CollisionRadius then
			drawSphereRings(position, Combat.Dodgeball.Radius, Color3.fromRGB(80, 180, 255), 0.35)
		end
		if Debug.PickupRadius and phase == 6 then
			drawGroundCircle(position, Combat.Dodgeball.PickupRadius, Color3.fromRGB(80, 255, 150), 0.4)
		end
		if Debug.Trajectory and (phase == 2 or phase == 3 or phase == 4 or phase == 5) then
			updateTrajectory(child)
		end
	end

	for ball in trajectories do
		if not live[ball] then
			trajectories[ball] = nil
		end
	end
end

local function drawLocalPlayerDebug(character: Model?)
	if character == nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	if Debug.RecallRange then
		drawGroundCircle(root.Position, Combat.Dodgeball.RecallMaxDistance, Color3.fromRGB(180, 120, 255), 0.72)
	end
	if Debug.ThrowOriginMaxOffset then
		drawSphereRings(root.Position, Combat.Dodgeball.ThrowOriginMaxOffset, Color3.fromRGB(255, 140, 80), 0.55)
	end
end

local function drawAimDebug(camera: Camera, character: Model?, balls: Instance?)
	if Debug.AimAssistCones then
		drawCone(
			camera,
			AimAssist.Mouse.SelectionConeDeg,
			Combat.Dodgeball.TargetSelectRange,
			Color3.fromRGB(80, 255, 120),
			0.45
		)
		drawCone(
			camera,
			AimAssist.Mouse.ValidationConeDeg,
			Combat.Dodgeball.TargetSelectRange,
			Color3.fromRGB(255, 205, 80),
			0.62
		)
	end
	if Debug.AimAssistTargetRange then
		drawLine(
			camera.CFrame.Position,
			camera.CFrame.Position + camera.CFrame.LookVector * Combat.Dodgeball.TargetSelectRange,
			Color3.fromRGB(255, 255, 255),
			0.025,
			0.55
		)
	end
	if Debug.SelectedTarget and hasHeldBall(balls) then
		local target = findSelectedTarget(camera, character, balls)
		local root = target and target:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			drawLine(camera.CFrame.Position, root.Position, Color3.fromRGB(255, 80, 110), 0.06, 0.15)
			drawSphereRings(root.Position, Combat.CharacterCapsule.Radius, Color3.fromRGB(255, 80, 110), 0.25)
		end
	end
end

local function drawBounceNormals()
	if not Debug.BounceNormals then
		return
	end
	local now = os.clock()
	for index = #bounceNormals, 1, -1 do
		local normal = bounceNormals[index]
		if normal.expires <= now then
			table.remove(bounceNormals, index)
		else
			drawLine(normal.from, normal.to, Color3.fromRGB(90, 255, 255), 0.07, 0.15)
		end
	end
end

function DebugVisuals.onEvent(event: SimEvent)
	if not enabled() or not Debug.BounceNormals then
		return
	end
	if event.kind ~= "BallBounced" or event.position == nil or event.normal == nil then
		return
	end
	table.insert(bounceNormals, {
		from = event.position,
		to = event.position + event.normal * 5,
		expires = os.clock() + BOUNCE_NORMAL_LIFETIME,
	})
	while #bounceNormals > MAX_BOUNCE_NORMALS do
		table.remove(bounceNormals, 1)
	end
end

function DebugVisuals.start()
	if started or not enabled() then
		return
	end
	started = true

	RunService.RenderStepped:Connect(function(dt)
		if not enabled() or not anyVisualEnabled() then
			clearTransientVisuals()
			return
		end

		accumulator += dt
		local interval = 1 / math.max(Debug.VisualUpdateHz or 12, 1)
		if accumulator < interval then
			return
		end
		accumulator = 0

		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		if rootFolder and rootFolder.Parent ~= camera then
			rootFolder.Parent = camera
		end

		lineCursor = 0
		coneCursor = 0
		local character = Players.LocalPlayer.Character
		local balls = Workspace:FindFirstChild("Balls")

		drawAimDebug(camera, character, balls)
		drawLocalPlayerDebug(character)
		drawBallDebug(balls)
		drawBounceNormals()
		updateLabels(balls)
		hideUnusedLines()
	end)
end

return DebugVisuals
