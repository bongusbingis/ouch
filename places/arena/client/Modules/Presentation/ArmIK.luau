--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ThrowPose = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ThrowPose"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local AimPose =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Pose"):WaitForChild("AimPose"))
local Spring =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Util"):WaitForChild("Spring"))
local AimDirector = require(script.Parent.Parent.Input.AimDirector)
local CombatState = require(script.Parent.CombatState)

-- Procedural throwing-arm pose. It owns the arm while a ball is held and leaves
-- the torso, facing, and throw animation to their existing owners.

local ArmIK = {}

type Chain = {
	character: Model,
	control: IKControl,
	target: Attachment,
	pole: Attachment,
	root: BasePart,
	weight: Spring.Spring,
	-- Hand target in character space, sprung per axis so it can overshoot.
	x: Spring.Spring,
	y: Spring.Spring,
	z: Spring.Spring,
	seeded: boolean,
}

local ARM_PART_TIMEOUT = 5

-- Config offsets are authored with vector.create, matching the other config
-- modules and keeping them loadable headlessly. Converted once at the point of
-- use rather than stored twice.
local function v3(value: any): Vector3
	return Vector3.new(value.x, value.y, value.z)
end

local started = false
local chains: { [Player]: Chain } = {}
local lastReportAt = 0
local lastReportedCharge = -1

local function destroyChain(player: Player)
	local chain = chains[player]
	if chain == nil then
		return
	end
	-- Control first, so the solver stops before its target disappears.
	chain.control:Destroy()
	chain.target:Destroy()
	chain.pole:Destroy()
	chains[player] = nil
end

-- CharacterAdded fires as soon as the model is parented, well before its limbs
-- have replicated. Looking them up immediately finds nothing and the chain is
-- never built, so each part is waited for on its own thread.
local function buildChain(player: Player, character: Model)
	destroyChain(player)
	if not ThrowPose.Enabled then
		return
	end

	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid")
		local root = character:WaitForChild("HumanoidRootPart")
		-- R15 only. R6 has a single "Right Arm" with no elbow to solve for, so a
		-- timeout rather than an open-ended wait: it keeps the authored animation
		-- and no IK, which is the correct degradation.
		local upperArm = character:WaitForChild("RightUpperArm", ARM_PART_TIMEOUT)
		local hand = character:WaitForChild("RightHand", ARM_PART_TIMEOUT)
		if
			not humanoid:IsA("Humanoid")
			or not root:IsA("BasePart")
			or upperArm == nil
			or not upperArm:IsA("BasePart")
			or hand == nil
			or not hand:IsA("BasePart")
		then
			return
		end
		if player.Character ~= character or character.Parent == nil then
			return
		end

		local target = Instance.new("Attachment")
		target.Name = "ThrowIKTarget"
		target.Parent = root

		local pole = Instance.new("Attachment")
		pole.Name = "ThrowIKPole"
		pole.Parent = root

		local control = Instance.new("IKControl")
		control.Name = "ThrowArmIK"
		control.Type = Enum.IKControlType.Position
		control.ChainRoot = upperArm
		control.EndEffector = hand
		control.Target = target
		control.Pole = pole
		control.SmoothTime = ThrowPose.Arm.SmoothTime
		-- Inert until the state machine asks for something, so a chain built
		-- mid-throw cannot snap the arm on its first frame.
		control.Weight = 0
		control.Enabled = true
		control.Parent = humanoid

		-- start() and CharacterAdded can both build for the same character and
		-- each waits independently; clearing here guarantees the loser's control
		-- is destroyed rather than orphaned on the Humanoid.
		destroyChain(player)
		chains[player] = {
			character = character,
			control = control,
			target = target,
			pole = pole,
			root = root,
			weight = Spring.new(0),
			x = Spring.new(0),
			y = Spring.new(0),
			z = Spring.new(0),
			seeded = false,
		}
	end)
end

-- Where the hand wants to be, in character space relative to the root. Two
-- poses only: presenting the ball along aim, and coiled at the wind-up spot.
local function desiredLocalTarget(chain: Chain, chargeAlpha: number, charging: boolean): Vector3
	local arm = ThrowPose.Arm
	local shoulder = v3(arm.ShoulderOffset)

	if charging then
		local reach = AimPose.windupReach(chargeAlpha, arm.ChargeStretch)
		-- Authored as right/up/back; Roblox faces -Z, so back is +Z.
		return shoulder + v3(arm.WindupOffset) * reach
	end

	local aim = AimDirector.currentAim()
	if typeof(aim) ~= "Vector3" or aim.Magnitude <= 1e-6 then
		return shoulder + Vector3.new(0, 0, -arm.ReadyDistance)
	end
	-- Aim only decides which way the ball is presented. It never reaches past the
	-- arm's length, so the elbow keeps a bend rather than locking straight.
	local localAim = chain.root.CFrame:VectorToObjectSpace(aim.Unit)
	return shoulder + localAim * arm.ReadyDistance
end

local function frequencyScale(): number
	if AimDirector.deviceClass() == "Touch" then
		return ThrowPose.Motion.TouchFrequencyScale
	end
	return 1
end

-- Charge is replicated so opponents can read a wind-up. Rate limited and change
-- gated: a cosmetic value is not worth a packet per frame, and a player who is
-- not charging sends nothing at all.
local function report(charge: number)
	local remote = ThrowPose.Remote
	if not remote.Enabled then
		return
	end
	local now = os.clock()
	if now - lastReportAt < 1 / math.max(remote.ReportHz, 1) then
		return
	end
	if math.abs(charge - lastReportedCharge) < remote.MinReportDelta then
		return
	end
	lastReportAt = now
	lastReportedCharge = charge
	Network.fireServer("ReportAimPose", charge)
end

local function updateChain(player: Player, chain: Chain, dt: number, isLocal: boolean)
	local motion = ThrowPose.Motion
	local weights = ThrowPose.Weights

	local stateName: string
	local chargeAlpha: number
	local hasBall: boolean
	if isLocal then
		local snapshot = CombatState.getSnapshot()
		stateName = snapshot.state
		chargeAlpha = snapshot.chargeAlpha
		hasBall = snapshot.weapon == "Dodgeball"
	else
		-- Remote characters get the wind-up only. Their charge is replicated;
		-- their aim is not, because the coil is what reads at a distance.
		local reported = player:GetAttribute("AimCharge")
		chargeAlpha = if typeof(reported) == "number" then reported else 0
		stateName = if chargeAlpha > 0 then "Charging" else "Idle"
		hasBall = chargeAlpha > 0
	end

	local charging = stateName == "Charging"
	local stateWeight = (weights :: any)[stateName] or 0
	local desired = if hasBall then AimPose.weight(stateWeight, chargeAlpha, 0, weights.Max) else 0

	chain.weight.target = desired
	Spring.step(chain.weight, motion.WeightFrequency, motion.WeightDamping, dt)
	chain.control.Weight = math.clamp(chain.weight.position, 0, weights.Max)

	if isLocal then
		report(chargeAlpha)
	end

	-- Nothing visible is happening; skip the target maths entirely.
	if chain.control.Weight <= 1e-3 then
		chain.seeded = false
		return
	end

	local localTarget = desiredLocalTarget(chain, chargeAlpha, charging)
	if not chain.seeded then
		-- Start at the destination on the first frame the solver engages, so the
		-- hand does not sweep in from wherever the springs happened to rest.
		chain.x.position, chain.y.position, chain.z.position = localTarget.X, localTarget.Y, localTarget.Z
		chain.x.velocity, chain.y.velocity, chain.z.velocity = 0, 0, 0
		chain.seeded = true
	end

	chain.x.target, chain.y.target, chain.z.target = localTarget.X, localTarget.Y, localTarget.Z

	-- Under-damped into the wind-up so the hand overshoots and settles; calm on
	-- the way back, where a bounce would read as a twitch.
	local scale = if isLocal then frequencyScale() else 1
	local frequency = if charging then motion.WindupFrequency else motion.ReturnFrequency
	local damping = if charging then motion.WindupDamping else motion.ReturnDamping
	Spring.step(chain.x, frequency * scale, damping, dt)
	Spring.step(chain.y, frequency * scale, damping, dt)
	Spring.step(chain.z, frequency * scale, damping, dt)

	-- Defence in depth. A non-finite target does not merely look wrong: it makes
	-- the limb's CFrame non-finite, which renders as the arm vanishing, and it
	-- never recovers because the bad value keeps feeding itself. The springs are
	-- stable now, but a bad tuning value must not be able to break a character
	-- for the rest of the session.
	local px, py, pz = chain.x.position, chain.y.position, chain.z.position
	if px ~= px or py ~= py or pz ~= pz or math.abs(px) + math.abs(py) + math.abs(pz) > 1e4 then
		chain.seeded = false
		chain.x, chain.y, chain.z = Spring.new(0), Spring.new(0), Spring.new(0)
		chain.control.Weight = 0
		warn("[ArmIK] throw pose target went non-finite and was reset; check Config.ThrowPose.Motion")
		return
	end

	local rootCFrame = chain.root.CFrame
	chain.target.WorldPosition = rootCFrame * Vector3.new(px, py, pz)
	-- The pole sits in character space too, so the elbow keeps flaring the same
	-- way however the character is facing.
	chain.pole.WorldPosition = rootCFrame * (v3(ThrowPose.Arm.ShoulderOffset) + v3(ThrowPose.Arm.PoleOffset))
end

local function update(dt: number)
	if not ThrowPose.Enabled then
		return
	end
	local localPlayer = Players.LocalPlayer
	for player, chain in chains do
		if chain.character.Parent == nil or chain.character:GetAttribute("CombatAlive") == false then
			chain.control.Weight = 0
			continue
		end
		local isLocal = player == localPlayer
		if isLocal or ThrowPose.Remote.Enabled then
			updateChain(player, chain, dt, isLocal)
		end
	end
end

-- Exposed for the debug view so it draws what the solver is actually using
-- rather than an approximation of it.
function ArmIK.debugState(): (Vector3?, Vector3?, number)
	local chain = chains[Players.LocalPlayer]
	if chain == nil then
		return nil, nil, 0
	end
	return chain.target.WorldPosition, chain.pole.WorldPosition, chain.control.Weight
end

function ArmIK.start()
	if started then
		return
	end
	started = true

	local function observe(player: Player)
		player.CharacterAdded:Connect(function(character)
			buildChain(player, character)
		end)
		player.CharacterRemoving:Connect(function()
			destroyChain(player)
		end)
		if player.Character then
			buildChain(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(observe)
	Players.PlayerRemoving:Connect(destroyChain)
	for _, player in Players:GetPlayers() do
		observe(player)
	end

	-- After the animator has written this frame's pose, so the solver blends over
	-- a finished animation rather than one about to be overwritten.
	RunService:BindToRenderStep("ThrowArmIK", Enum.RenderPriority.Character.Value + 1, update)
end

return ArmIK
