--!strict

-- Emote clip registry. Clips resolve by name from ReplicatedStorage.Assets.Animations.Emotes.

local Cosmetics = require(script.Parent.Cosmetics)

export type Clip = {
	ClipName: string,
	DisplayName: string,
	Duration: number,
	Looped: boolean,
	Priority: string,
	FadeIn: number,
	FadeOut: number,
}

local Clips: { [string]: Clip } = {
	EmoteWave = {
		ClipName = "Wave",
		DisplayName = "Wave",
		Duration = 3.2,
		Looped = false,
		Priority = "Action3",
		FadeIn = 0.12,
		FadeOut = 0.18,
	},
	ShowtimeTwirl = {
		ClipName = "Twirl",
		DisplayName = "Confetti Twirl",
		Duration = 4.0,
		Looped = false,
		Priority = "Action3",
		FadeIn = 0.12,
		FadeOut = 0.18,
	},
	ShowtimeFlex = {
		ClipName = "Flex",
		DisplayName = "Champion Flex",
		Duration = 3.6,
		Looped = false,
		Priority = "Action3",
		FadeIn = 0.12,
		FadeOut = 0.18,
	},
	ShowtimeBounce = {
		ClipName = "Bounce",
		DisplayName = "Party Bounce",
		Duration = 3.2,
		Looped = false,
		Priority = "Action3",
		FadeIn = 0.12,
		FadeOut = 0.18,
	},
}

for emoteId, clip in Clips do
	local item = Cosmetics.Items[emoteId]
	assert(item ~= nil and item.Category == "EmoteAssets", `emote clip "{emoteId}" must be an EmoteAssets item`)
	assert(
		Enum.AnimationPriority[clip.Priority] ~= nil,
		`emote clip "{emoteId}" has unknown priority "{clip.Priority}"`
	)
	assert(clip.Duration > 0, `emote clip "{emoteId}" needs a positive Duration`)
end

return table.freeze({
	FolderName = "Emotes",
	BaseSlots = 4,
	MaxSlots = 8,
	MinReplaySeconds = 0.5,
	Clips = Clips,
	Preview = {
		WidthStuds = 6.8,
		HeightStuds = 7.3,
		FieldOfView = 42,
		TargetOffset = Vector3.new(0, 0.1, 0),
		UpdateHz = 30,
	},
})
