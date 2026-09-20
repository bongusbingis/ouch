-- Native, server-owned hinges. The authored course parts stay anchored until activation.
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config.Gameplay.MapFeatures)
local Parts = require(script.Parent.FeatureParts)
local Collision = require(script.Parent.SeesawCollision)
local Kit = require(script.Parent.MapFeatureKit)

local Seesaws = { folderName = "Rotating", instanceClass = "Folder" }
Seesaws.folderNames = { "Seesaws", "Rotating" }

type State = {
	board: BasePart,
	rest: CFrame,
	anchored: boolean,
	group: string,
	canCollide: boolean,
	canQuery: boolean,
	physicalProperties: PhysicalProperties?,
	authoredTilt: any,
	authoredResponse: any,
	boardAttachment: Attachment,
	pedestalAttachment: Attachment,
	hinge: HingeConstraint,
	noCollision: NoCollisionConstraint,
	gravityAttachment: Attachment,
	gravityForce: VectorForce,
}

local states: { [BasePart]: State } = {}

local function serverOwns(board: BasePart)
	local canSet, reason = board:CanSetNetworkOwnership()
	assert(canSet, `[Seesaws] {board:GetFullName()} cannot set server ownership: {tostring(reason)}`)
	board:SetNetworkOwner(nil)
	assert(board:GetNetworkOwner() == nil, `[Seesaws] {board:GetFullName()} must be server owned: {tostring(reason)}`)
end

local function setup(board: BasePart): State
	local pedestal = board.Parent
	assert(pedestal and pedestal:IsA("BasePart"), `[Seesaws] {board:GetFullName()} needs a BasePart pedestal parent`)
	assert(pedestal.Anchored, `[Seesaws] {pedestal:GetFullName()} must be anchored`)
	assert(
		Parts.axis(board, "SeesawAxis", Config.Seesaw.Axis) == Vector3.xAxis,
		`[Seesaws] {board:GetFullName()} axle must use local X`
	)
	local rest = board.CFrame
	local boardAttachment = Instance.new("Attachment")
	boardAttachment.Name = "SeesawAxle"
	boardAttachment.CFrame = CFrame.identity
	boardAttachment.Parent = board
	local pedestalAttachment = Instance.new("Attachment")
	pedestalAttachment.Name = "SeesawAxle"
	pedestalAttachment.CFrame = pedestal.CFrame:ToObjectSpace(rest)
	pedestalAttachment.Parent = pedestal

	local hinge = Instance.new("HingeConstraint")
	hinge.Name = "SeesawHinge"
	hinge.Attachment0 = pedestalAttachment
	hinge.Attachment1 = boardAttachment
	hinge.ActuatorType = Enum.ActuatorType.Servo
	hinge.TargetAngle = 0
	hinge.AngularSpeed = Config.Seesaw.AngularSpeed
	hinge.AngularResponsiveness = Config.Seesaw.AngularResponsiveness
	hinge.ServoMaxTorque = Config.Seesaw.ServoMaxTorque
	hinge.Restitution = 0
	-- Set distinct bounds before enabling limits; equal interim bounds can lock the joint.
	hinge.UpperAngle = 85
	hinge.LowerAngle = -85
	hinge.LimitsEnabled = true
	assert(
		hinge.LowerAngle == -85 and hinge.UpperAngle == 85,
		`[Seesaws] {board:GetFullName()} hinge limits did not initialize`
	)
	hinge.Parent = pedestal

	local noCollision = Instance.new("NoCollisionConstraint")
	noCollision.Name = "SeesawPedestalNoCollision"
	noCollision.Part0 = board
	noCollision.Part1 = pedestal
	noCollision.Parent = pedestal

	local state: State = {
		board = board,
		rest = rest,
		anchored = board.Anchored,
		group = board.CollisionGroup,
		canCollide = board.CanCollide,
		canQuery = board.CanQuery,
		physicalProperties = board.CustomPhysicalProperties,
		authoredTilt = board:GetAttribute("MaxTiltDegrees"),
		authoredResponse = board:GetAttribute("SeesawResponse"),
		boardAttachment = boardAttachment,
		pedestalAttachment = pedestalAttachment,
		hinge = hinge,
		noCollision = noCollision,
		gravityAttachment = Instance.new("Attachment"),
		gravityForce = Instance.new("VectorForce"),
	}
	board.CollisionGroup = Collision.PLANK_GROUP
	board:SetAttribute("MaxTiltDegrees", 85)
	board:SetAttribute("SeesawResponse", nil)
	board.CanCollide = true
	board.CanQuery = true
	local material = board.CurrentPhysicalProperties
	board.CustomPhysicalProperties = PhysicalProperties.new(
		Config.Seesaw.PlankDensity,
		material.Friction,
		material.Elasticity,
		material.FrictionWeight,
		material.ElasticityWeight
	)
	state.gravityAttachment.Name = "SeesawGravityAttachment"
	state.gravityAttachment.Parent = board
	state.gravityForce.Name = "SeesawGravityCompensation"
	state.gravityForce.Attachment0 = state.gravityAttachment
	state.gravityForce.RelativeTo = Enum.ActuatorRelativeTo.World
	state.gravityForce.ApplyAtCenterOfMass = true
	state.gravityForce.Force = Vector3.yAxis * board:GetMass() * Workspace.Gravity
	state.gravityForce.Parent = board
	board.Anchored = false
	serverOwns(board)
	return state
end

local function teardown(state: State)
	local board = state.board
	if board.Parent then
		board.Anchored = true
		board.CFrame = state.rest
		board.AssemblyAngularVelocity = Vector3.zero
		board.AssemblyLinearVelocity = Vector3.zero
		board.CollisionGroup = state.group
		board.CanCollide = state.canCollide
		board.CanQuery = state.canQuery
		board.CustomPhysicalProperties = state.physicalProperties
		board:SetAttribute("MaxTiltDegrees", state.authoredTilt)
		board:SetAttribute("SeesawResponse", state.authoredResponse)
		board.Anchored = state.anchored
	end
	state.hinge:Destroy()
	state.noCollision:Destroy()
	state.boardAttachment:Destroy()
	state.pedestalAttachment:Destroy()
	state.gravityForce:Destroy()
	state.gravityAttachment:Destroy()
end

function Seesaws.tickWorld(context: Kit.Context)
	local active: { [BasePart]: boolean } = {}
	local boards = Parts.collect(context.instances, Config.Attributes.Seesaw)
	if #boards > 0 and next(states) == nil then
		Collision.start()
	end
	for _, board in boards do
		if not board:IsDescendantOf(Workspace) then
			continue
		end
		active[board] = true
		local state = states[board]
		if state == nil then
			state = setup(board)
			states[board] = state
		else
			assert(
				Parts.axis(board, "SeesawAxis", Config.Seesaw.Axis) == Vector3.xAxis,
				`[Seesaws] {board:GetFullName()} axle must use local X`
			)
			assert(
				state.hinge.LowerAngle == -85 and state.hinge.UpperAngle == 85,
				`[Seesaws] {board:GetFullName()} hinge limits changed`
			)
		end
	end
	for board, state in states do
		if not active[board] then
			teardown(state)
			states[board] = nil
		end
	end
	if next(states) == nil then
		Collision.stop()
	end
end

function Seesaws.forget(player: Player?)
	if player then
		return
	end
	for board, state in states do
		teardown(state)
		states[board] = nil
	end
	Collision.stop()
end

return Seesaws
