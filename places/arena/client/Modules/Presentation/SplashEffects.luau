-- Description: Plays the Splashdown race feedback the server announces: a purple burst and the fall cue where a racer hits the lava, a detached camera that pans to keep watching a fast fall past the point of impact, a chime for the local racer's checkpoints and finish, and the breakaway fall of a Knock Knock door, restoring each door when the server makes it solid again.

--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Splashdown = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local MapFeatures = require(Config:WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local PlayerIds = require(Shared:WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("PlayerIds"))
local GameAudio = require(script.Parent.GameAudio)
local SplashdownClient = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("SplashdownClient"))
local PresentationCamera = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Services")
		:WaitForChild("PresentationCamera")
)

local SplashEffects = {}

local LAVA_COLOR = Color3.fromRGB(214, 63, 214)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local localPlayer = Players.LocalPlayer
local started = false
local connections: { RBXScriptConnection | () -> () } = {}
local doorOrigins: { [BasePart]: { cframe: CFrame, transparency: number, watch: RBXScriptConnection } } = {}
local template: BasePart? = nil
local lavaCameraLease: PresentationCamera.Token? = nil
local lavaCameraGeneration = 0

local function buildTemplate(): BasePart
	local part = Instance.new("Part")
	part.Name = "Splash"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)

	local droplets = Instance.new("ParticleEmitter")
	droplets.Name = "Droplets"
	droplets.Enabled = false
	droplets.Texture = SMOKE_TEXTURE
	droplets.Color = ColorSequence.new(LAVA_COLOR)
	droplets.EmissionDirection = Enum.NormalId.Top
	droplets.Speed = NumberRange.new(28, 48)
	droplets.Lifetime = NumberRange.new(0.5, 0.9)
	droplets.SpreadAngle = Vector2.new(35, 35)
	droplets.Size = NumberSequence.new(1.2, 0.3)
	droplets.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.6, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	droplets.Acceleration = Vector3.new(0, -70, 0)
	droplets.Drag = 1.5
	droplets.LightEmission = 0.3
	droplets.Parent = part

	local ring = Instance.new("ParticleEmitter")
	ring.Name = "Ring"
	ring.Enabled = false
	ring.Texture = SMOKE_TEXTURE
	ring.Color = ColorSequence.new(LAVA_COLOR)
	ring.EmissionDirection = Enum.NormalId.Top
	ring.Speed = NumberRange.new(6, 12)
	ring.Lifetime = NumberRange.new(0.35, 0.5)
	ring.SpreadAngle = Vector2.new(85, 85)
	ring.Size = NumberSequence.new(2.5, 5)
	ring.Transparency = NumberSequence.new(0.2, 1)
	ring.LightEmission = 0.2
	ring.Parent = part
	return part
end

local function splashAt(position: Vector3)
	if template == nil then
		template = buildTemplate()
	end
	local burst = (template :: BasePart):Clone()
	burst.CFrame = CFrame.new(position)
	burst.Parent = Workspace
	local droplets = burst:FindFirstChild("Droplets")
	if droplets and droplets:IsA("ParticleEmitter") then
		droplets:Emit(Splashdown.Splash.ParticleBurst)
	end
	local ring = burst:FindFirstChild("Ring")
	if ring and ring:IsA("ParticleEmitter") then
		ring:Emit(math.ceil(Splashdown.Splash.ParticleBurst / 4))
	end
	Debris:AddItem(burst, Splashdown.Splash.Lifetime)
	GameAudio.play("ElimZoneFall", position)
end

local function humanoidRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function fallingRootPosition(character: Model): Vector3?
	local root = humanoidRoot(character)
	return if root then root.Position else nil
end

local function stopLavaCamera()
	lavaCameraGeneration += 1
	if lavaCameraLease then
		PresentationCamera.release(lavaCameraLease)
		lavaCameraLease = nil
	end
end

-- The racer keeps falling under ordinary gravity, uninterrupted; only the
-- camera detaches, holding its position and panning to keep looking at the
-- character as it drops past the lava's surface and out of view. Timed to
-- Splashdown.RespawnDelaySeconds, the same window the server free-falls the
-- racer for before pulling them back to their checkpoint.
local function startLavaCamera(character: Model)
	stopLavaCamera()
	local camera = Workspace.CurrentCamera
	local root = humanoidRoot(character)
	if camera == nil or root == nil then
		return
	end

	lavaCameraGeneration += 1
	local generation = lavaCameraGeneration
	local frozenPosition = camera.CFrame.Position
	lavaCameraLease = PresentationCamera.acquire(
		"LavaSplash",
		PresentationCamera.Priority.Splash,
		function(activeCamera: Camera, _deltaTime: number)
			local target = fallingRootPosition(character) or frozenPosition
			activeCamera.CFrame = CFrame.lookAt(frozenPosition, target)
		end
	)
	task.delay(Splashdown.RespawnDelaySeconds, function()
		if lavaCameraGeneration == generation then
			stopLavaCamera()
		end
	end)
end

local function restoreDoor(door: BasePart)
	local origin = doorOrigins[door]
	if origin == nil then
		return
	end
	door.CFrame = origin.cframe
	door.Transparency = origin.transparency
end

local function forgetDoor(door: BasePart)
	local origin = doorOrigins[door]
	if origin then
		origin.watch:Disconnect()
		doorOrigins[door] = nil
	end
end

-- The door tips over away from whoever broke it, hinged on its bottom edge,
-- and fades; the server's later CanCollide reset is what stands it back up.
local function breakDoor(door: BasePart, from: Vector3)
	if doorOrigins[door] == nil then
		doorOrigins[door] = {
			cframe = door.CFrame,
			transparency = door.Transparency,
			watch = door:GetPropertyChangedSignal("CanCollide"):Connect(function()
				if door.CanCollide then
					restoreDoor(door)
				end
			end),
		}
		door.AncestryChanged:Connect(function()
			if door.Parent == nil then
				forgetDoor(door)
			end
		end)
	end
	local origin = doorOrigins[door].cframe
	local toBreaker = origin:PointToObjectSpace(from)
	local away = if toBreaker.Z > 0 then -1 else 1
	local halfHeight = door.Size.Y / 2
	local hinge = origin * CFrame.new(0, -halfHeight, 0)
	local fallen = hinge * CFrame.Angles(math.rad(88) * away, 0, 0) * CFrame.new(0, halfHeight, 0)
	local seconds = MapFeatures.Door.BrokenSeconds
	TweenService:Create(door, TweenInfo.new(seconds * 0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		CFrame = fallen,
	}):Play()
	TweenService:Create(
		door,
		TweenInfo.new(seconds * 0.55, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, seconds * 0.45),
		{
			Transparency = 1,
		}
	):Play()
	GameAudio.play("JumpPadBounce", door)
end

function SplashEffects.start()
	if started then
		return
	end
	started = true
	local localId = PlayerIds.toId(Players.LocalPlayer)
	table.insert(
		connections,
		SplashdownClient.onEvent(function(event)
			if event.kind == "Splash" and typeof(event.position) == "Vector3" then
				splashAt(event.position)
				if
					event.playerId == localId
					and typeof(event.velocity) == "Vector3"
					and event.velocity.Y <= -Splashdown.LavaCamera.MinFallSpeed
				then
					local character = localPlayer.Character
					if character then
						startLavaCamera(character)
					end
				end
			elseif event.kind == "Checkpoint" and event.playerId == localId then
				GameAudio.play("OnboardingStepSuccess")
			elseif event.kind == "Finish" and event.playerId == localId then
				GameAudio.play("OnboardingCoreComplete")
			end
		end)
	)
	table.insert(
		connections,
		Network.on("DoorBroken", function(door, from)
			if typeof(door) == "Instance" and door:IsA("BasePart") and typeof(from) == "Vector3" then
				breakDoor(door, from)
			end
		end)
	)
	table.insert(
		connections,
		localPlayer.CharacterRemoving:Connect(function()
			stopLavaCamera()
		end)
	)
end

function SplashEffects.destroy()
	for _, connection in connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		else
			connection()
		end
	end
	table.clear(connections)
	for door in doorOrigins do
		forgetDoor(door)
	end
	stopLavaCamera()
	started = false
end

return SplashEffects
