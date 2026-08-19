--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local PlayerIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("PlayerIds")
)

-- Starts the local player's weapon animation the instant they press, instead of
-- waiting for the server's event to arrive. Played on the local character, so it
-- replicates outward and stays the only copy.
--
-- Purely cosmetic: the server still decides whether the action happens at all.

local WeaponAnimations = {}

local HELD_PHASE = 0

-- heldBall is the condition under which this weapon takes a Throw press, which
-- is how the sim routes it: Dodgeball consumes the press while a ball is held,
-- Hammer otherwise. Keep this list in WeaponRegistry order. Config is read per
-- press rather than captured, so live overrides apply.
local weapons = {
	{
		module = "Dodgeball",
		animationKey = "ThrowAnimationName",
		cooldownKey = "ThrowCooldown",
		fadeTime = 0.04,
		heldBall = true,
	},
	{
		module = "Hammer",
		animationKey = "AnimationName",
		cooldownKey = "Cooldown",
		fadeTime = 0.03,
		heldBall = false,
	},
}

local started = false
local ballsFolder: Folder? = nil
local tracks: { [string]: AnimationTrack } = {}
local lastPlayedAt: { [string]: number } = {}
local animator: Animator? = nil

local function onCharacter(character: Model)
	table.clear(tracks)
	table.clear(lastPlayedAt)
	local humanoid = character:WaitForChild("Humanoid")
	local resolved = humanoid:WaitForChild("Animator")
	assert(resolved:IsA("Animator"), "[WeaponAnimations] Humanoid.Animator must be an Animator")
	animator = resolved
end

local function trackFor(name: string): AnimationTrack?
	local existing = tracks[name]
	if existing then
		return existing
	end
	local current = animator
	if current == nil then
		return nil
	end
	local animation = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations"):WaitForChild(name)
	assert(animation:IsA("Animation"), `[WeaponAnimations] Assets.Animations.{name} must be an Animation`)
	local loaded = current:LoadAnimation(animation)
	loaded.Priority = Enum.AnimationPriority.Action4
	loaded.Looped = false
	tracks[name] = loaded
	return loaded
end

local function holdsBall(): boolean
	local folder = ballsFolder
	if folder == nil then
		return false
	end
	local localId = PlayerIds.toId(Players.LocalPlayer)
	for _, ball in folder:GetChildren() do
		if ball:GetAttribute("hb") == localId and ball:GetAttribute("ph") == HELD_PHASE then
			return true
		end
	end
	return false
end

function WeaponAnimations.onIntent(kind: string)
	if kind ~= "Throw" then
		return
	end
	local held = holdsBall()
	for _, weapon in weapons do
		if weapon.heldBall ~= held then
			continue
		end
		local settings = (Combat :: any)[weapon.module]
		local name = settings[weapon.animationKey] :: string
		local track = trackFor(name)
		-- The cooldown gate stops a press the server will reject on cooldown from
		-- replaying the clip; IsPlaying alone leaves a gap when the cooldown is
		-- longer than the animation.
		local now = os.clock()
		if
			track == nil
			or track.IsPlaying
			or now - (lastPlayedAt[name] or -math.huge) < settings[weapon.cooldownKey]
		then
			return
		end
		lastPlayedAt[name] = now
		track:Play(weapon.fadeTime)
		return
	end
end

function WeaponAnimations.start()
	if started then
		return
	end
	started = true

	local resolved = Workspace:WaitForChild("Balls")
	assert(resolved:IsA("Folder"), "[WeaponAnimations] Workspace.Balls must be a Folder")
	ballsFolder = resolved

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacter)
	local character = player.Character
	if character then
		onCharacter(character)
	end
end

return WeaponAnimations
