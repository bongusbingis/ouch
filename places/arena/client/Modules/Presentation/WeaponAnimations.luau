--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Animations"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local CombatState = require(script.Parent.CombatState)

-- Plays the local player's combat animations, driven by the visual state
-- machine rather than by raw input.
--
-- Everything is played on the local character the instant the state changes, so
-- a press is never waiting on a round trip. Playing locally also means the
-- animation replicates outward by itself and stays the only copy -- the server
-- must never play these too, or the clip restarts on the actor mid-motion.
--
-- Purely cosmetic. The server decides whether an action happens at all; if it
-- rejects a throw, the worst case is an animation that played for nothing.
--
-- Clip names and which of them are required live in Config.Animations. This
-- module knows how to play a clip and when, never which asset it is.

local WeaponAnimations = {}

local started = false
local animator: Animator? = nil
local tracks: { [string]: AnimationTrack } = {}
-- Clips that are configured but absent from the Studio assets. Remembered so a
-- missing optional animation is looked up once rather than every play.
local missing: { [string]: boolean } = {}
local lastPlayedAt: { [string]: number } = {}
local currentLoop: AnimationTrack? = nil

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
		-- Required assets are waited for: a missing one is a setup error and the
		-- infinite-yield warning is the correct way to surface it.
		instance = folder():WaitForChild(clip.Name)
		assert(instance and instance:IsA("Animation"), "[WeaponAnimations] " .. clip.Name .. " must be an Animation")
	else
		-- Optional clips legitimately may not be authored yet.
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

	-- The release marker is what hands the throw over to its follow-through. A
	-- clip without one still works; the state machine's timer covers it.
	if weapon == "Dodgeball" and name == "Throw" then
		loaded:GetMarkerReachedSignal("Release"):Connect(function()
			CombatState.onReleaseMarker()
		end)
	elseif weapon == "Dodgeball" and name == "Charge" then
		-- Freezing on the marker holds the wound pose for as long as the player
		-- keeps charging, so the clip only has to cover the wind-up itself
		-- rather than the longest possible hold.
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
		-- A charge clip frozen on its marker has to be released, or the next
		-- wind-up starts already stopped at the wound pose.
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
	-- The cooldown gate stops a press the server will reject from replaying the
	-- clip; IsPlaying alone leaves a gap whenever the cooldown outlasts it.
	local key = clipKey(weapon, name)
	local now = os.clock()
	if cooldown and now - (lastPlayedAt[key] or -math.huge) < cooldown then
		return
	end
	lastPlayedAt[key] = now
	track:Play(fadeTime)
end

local function onCharacter(character: Model)
	table.clear(tracks)
	table.clear(missing)
	table.clear(lastPlayedAt)
	currentLoop = nil
	local humanoid = character:WaitForChild("Humanoid")
	local resolved = humanoid:WaitForChild("Animator")
	assert(resolved:IsA("Animator"), "[WeaponAnimations] Humanoid.Animator must be an Animator")
	animator = resolved
end

-- The hammer swing is the one action still driven straight off input rather
-- than off state: it has no charge to wait for, and deferring it would add the
-- whole press-to-release window to every melee swing.
function WeaponAnimations.onIntent(kind: string)
	if kind ~= "Throw" or CombatState.holdsBall() then
		return
	end
	playOnce("Hammer", "Swing", Animations.FadeTime.Attack, Combat.Hammer.Cooldown)
end

local function onState(snapshot: CombatState.Snapshot)
	if snapshot.weapon ~= "Dodgeball" then
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
	player.CharacterAdded:Connect(onCharacter)
	local character = player.Character
	if character then
		onCharacter(character)
	end

	CombatState.subscribe(onState)
end

return WeaponAnimations
