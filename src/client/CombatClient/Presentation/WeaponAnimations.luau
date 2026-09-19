-- Description: Plays the local character's weapon animation clips directly from its own combat intents so they are not delayed by a server round trip, resolving clips per weapon and state.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Animations"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local CombatState = require(script.Parent.CombatState)

local WeaponAnimations = {}

local started = false
local animator: Animator? = nil
local tracks: { [string]: AnimationTrack } = {}
local missing: { [string]: boolean } = {}
local lastPlayedAt: { [string]: number } = {}
local currentLoop: AnimationTrack? = nil
local characterAddedConnection: RBXScriptConnection? = nil
local combatStateUnsubscribe: (() -> ())? = nil

local function clipKey(weapon: string, name: string): string
	return weapon .. "." .. name
end

local function folder(): Instance
	return ReplicatedStorage:WaitForChild("Assets"):WaitForChild(Animations.FolderName)
end

local function resolve(weapon: string, name: string): AnimationTrack?
	local key = clipKey(weapon, name)
	if missing[key] then
		return nil
	end
	local existing = tracks[key]
	if existing then
		return existing
	end

	local current = animator
	local clip = Animations.Clips[weapon] and Animations.Clips[weapon][name]
	if current == nil or clip == nil then
		return nil
	end

	local instance: Instance?
	if clip.Required then
		instance = folder():WaitForChild(clip.Name)
		--assert(instance and instance:IsA("Animation") or instance:IsA("KeyframeSequence"), "[WeaponAnimations] " .. clip.Name .. " must be an Animation")
	else
		instance = folder():FindFirstChild(clip.Name)
		if instance == nil or not instance:IsA("Animation") then
			missing[key] = true
			return nil
		end
	end

	local loaded = current:LoadAnimation(instance :: Animation)
	loaded.Priority = Enum.AnimationPriority[clip.Priority]
	loaded.Looped = clip.Looped
	tracks[key] = loaded

	if weapon == "Dodgeball" and name == "Throw" then
		loaded:GetMarkerReachedSignal("Release"):Connect(function()
			CombatState.onReleaseMarker()
		end)
	elseif weapon == "Dodgeball" and name == "Charge" then
		loaded:GetMarkerReachedSignal("Charged"):Connect(function()
			loaded:AdjustSpeed(0)
		end)
	end
	return loaded
end

local function stopLoop()
	local track = currentLoop
	if track then
		if track.IsPlaying then
			track:Stop(Animations.FadeTime.Hold)
		end
		track:AdjustSpeed(1)
	end
	currentLoop = nil
end

local function playLoop(weapon: string, name: string)
	local track = resolve(weapon, name)
	if track == currentLoop then
		return
	end
	stopLoop()
	if track == nil then
		return
	end
	track:Play(Animations.FadeTime.Hold)
	currentLoop = track
end

local function playOnce(weapon: string, name: string, fadeTime: number, cooldown: number?)
	local track = resolve(weapon, name)
	if track == nil or track.IsPlaying then
		return
	end
	local key = clipKey(weapon, name)
	local now = os.clock()
	if cooldown and now - (lastPlayedAt[key] or -math.huge) < cooldown then
		return
	end
	lastPlayedAt[key] = now
	track:Play(fadeTime)
end

local function onCharacter(character: Model)
	for _, track in tracks do
		pcall(function()
			track:Stop(0)
			track:Destroy()
		end)
	end
	table.clear(tracks)
	table.clear(missing)
	table.clear(lastPlayedAt)
	currentLoop = nil
	local humanoid = character:WaitForChild("Humanoid")
	local resolved = humanoid:WaitForChild("Animator")
	assert(resolved:IsA("Animator"), "[WeaponAnimations] Humanoid.Animator must be an Animator")
	animator = resolved
end

function WeaponAnimations.onIntent(kind: string)
	if kind ~= "Throw" or CombatState.canThrowBall() then
		return
	end
	playOnce("Hammer", "Swing", Animations.FadeTime.Attack, Combat.Hammer.Cooldown)
end

local function onState(snapshot: CombatState.Snapshot)
	if snapshot.weapon ~= "Dodgeball" or not snapshot.holdsBall then
		stopLoop()
		playLoop("Hammer", "Idle")
		return
	end

	local state = snapshot.state
	if state == "Throwing" then
		playOnce("Dodgeball", "Throw", Animations.FadeTime.Attack, Combat.Dodgeball.ThrowCooldown)
		stopLoop()
	elseif state == "Charging" then
		playLoop("Dodgeball", "Charge")
	elseif state == "Recovering" then
		playOnce("Dodgeball", "Recover", Animations.FadeTime.Recover)
	elseif state == "Aiming" or state == "BallEquipped" then
		playLoop("Dodgeball", "Hold")
	end
end

function WeaponAnimations.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	characterAddedConnection = player.CharacterAdded:Connect(onCharacter)
	local character = player.Character
	if character then
		onCharacter(character)
	end

	combatStateUnsubscribe = CombatState.subscribe(onState)
end

function WeaponAnimations.stop()
	if characterAddedConnection then
		characterAddedConnection:Disconnect()
		characterAddedConnection = nil
	end
	if combatStateUnsubscribe then
		combatStateUnsubscribe()
		combatStateUnsubscribe = nil
	end
	stopLoop()
	for _, track in tracks do
		pcall(function()
			track:Stop(0)
			track:Destroy()
		end)
	end
	table.clear(tracks)
	table.clear(missing)
	table.clear(lastPlayedAt)
	currentLoop = nil
	animator = nil
	started = false
end

return WeaponAnimations
