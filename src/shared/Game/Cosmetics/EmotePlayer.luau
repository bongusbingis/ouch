-- Name: EmotePlayer.luau
-- Author: Jack C.
-- Description: Resolves emote clips by name from ReplicatedStorage and plays or stops them on an Animator, caching loaded tracks per animator.
-- Created: 2026-09-09

--!strict

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Emotes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Emotes"))

local EmotePlayer = {}

local missing: { [string]: boolean } = {}
local registered: { [Instance]: Animation } = {}
local tracksByAnimator = setmetatable({}, { __mode = "k" }) :: { [Animator]: { [string]: AnimationTrack } }

local function folder(): Instance?
	local animations = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations")
	return animations:FindFirstChild(Emotes.FolderName)
end

function EmotePlayer.animation(emoteId: string): Animation?
	if missing[emoteId] then
		return nil
	end
	local clip = Emotes.Clips[emoteId]
	if clip == nil then
		missing[emoteId] = true
		warn(`[EmotePlayer] unknown emote id "{emoteId}"`)
		return nil
	end
	local emotesFolder = folder()
	local instance = emotesFolder and emotesFolder:FindFirstChild(clip.ClipName)
	if instance and instance:IsA("Animation") then
		return instance
	end
	local placeholders = script.Parent:FindFirstChild("EmoteClips")
	local sequence = placeholders and placeholders:FindFirstChild(clip.ClipName)
	if sequence and sequence:IsA("KeyframeSequence") then
		local animation = registered[sequence]
		if animation == nil then
			local ok, id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, sequence)
			if ok and type(id) == "string" and id ~= "" then
				animation = Instance.new("Animation")
				animation.Name = clip.ClipName
				animation.AnimationId = id
				registered[sequence] = animation
			end
		end
		if animation then
			return animation
		end
	end
	missing[emoteId] = true
	warn(`[EmotePlayer] missing Assets.Animations.{Emotes.FolderName}.{clip.ClipName} for emote "{emoteId}"`)
	return nil
end

function EmotePlayer.play(animator: Animator, emoteId: string): AnimationTrack?
	local clip = Emotes.Clips[emoteId]
	local animation = EmotePlayer.animation(emoteId)
	if clip == nil or animation == nil then
		return nil
	end
	local tracks = tracksByAnimator[animator]
	if tracks == nil then
		tracks = {}
		tracksByAnimator[animator] = tracks
	end
	local track = tracks[emoteId]
	if track == nil then
		track = animator:LoadAnimation(animation)
		tracks[emoteId] = track
	end
	track.Priority = Enum.AnimationPriority[clip.Priority]
	track.Looped = clip.Looped
	track:Play(clip.FadeIn)
	return track
end

function EmotePlayer.stop(track: AnimationTrack?, fadeOut: number?)
	if track ~= nil and track.IsPlaying then
		track:Stop(fadeOut or 0.18)
	end
end

return EmotePlayer
