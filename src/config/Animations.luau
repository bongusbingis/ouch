--!strict

-- The single registry of combat animations. Every clip the game plays is named
-- here once; nothing else in the codebase names an animation.
--
-- A clip's Name is the child of ReplicatedStorage.Assets.Animations that holds
-- it, following the project rule that assets are authored in Studio and
-- referenced by name. Replacing a rough prototype with a proper animation is
-- therefore a Studio operation -- point the existing Animation instance at a new
-- AnimationId -- and needs no code change at all.
--
-- Required clips must exist or the game is broken, and are fetched with
-- WaitForChild so a missing one surfaces loudly. Optional clips are the polish
-- passes that may not be authored yet: they are looked up leniently, and the
-- system simply does without them. That is what lets this ship today with two
-- prototype animations and improve as more are made, with no code edits.
--
-- Markers are the contract between an animation and gameplay. A clip that
-- declares one is expected to carry a KeyframeMarker of that name, and the
-- combat code listens for it rather than guessing at timings with a wait.
-- A missing marker is survivable: the state machine falls back to the durations
-- in Config.ThrowPose.Timing.

export type Clip = {
	-- Child name under ReplicatedStorage.Assets.Animations.
	Name: string,
	-- Required clips are asserted at load; optional ones degrade to nothing.
	Required: boolean,
	Looped: boolean,
	-- Enum.AnimationPriority member name. Attacks sit above locomotion so they
	-- read over a run cycle; holds sit just above idle so movement still shows.
	Priority: string,
	-- Marker names this clip is expected to carry.
	Markers: { string },
}

local clips: { [string]: { [string]: Clip } } = {
	Dodgeball = {
		-- Looping pose while carrying a ball. Two properties matter: it should be
		-- neutral enough that the IK can adjust the hand without fighting a
		-- strong authored pose, and it should keyframe ONLY the throwing arm.
		-- Roblox blends per joint, so an arm-only clip at this priority overrides
		-- the default locomotion on that arm and leaves the legs and torso free
		-- to keep running. Keyframing the whole body here would freeze the run.
		Hold = { Name = "DodgeballHold", Required = false, Looped = true, Priority = "Idle", Markers = {} },
		-- Wind-up. Charged marks the frame the arm reaches the fully-wound pose;
		-- playback freezes there for as long as the player keeps holding, so the
		-- clip does not need to be padded out to the maximum charge time. A clip
		-- without the marker simply plays through and blends out.
		Charge = {
			Name = "DodgeballCharge",
			Required = false,
			Looped = false,
			Priority = "Action2",
			Markers = { "Charged" },
		},
		-- The one clip that must exist. Release marks the frame the ball leaves
		-- the hand, which is when the held visual is hidden and the pose layer
		-- steps aside for the follow-through.
		Throw = { Name = "Throw", Required = true, Looped = false, Priority = "Action4", Markers = { "Release" } },
		-- Settle back to the hold pose. Without it the throw simply blends out.
		Recover = { Name = "DodgeballRecover", Required = false, Looped = false, Priority = "Action2", Markers = {} },
	},

	Hammer = {
		Idle = { Name = "HammerIdle", Required = false, Looped = true, Priority = "Idle", Markers = {} },
		-- SwingHit marks the frame the head of the hammer passes through its
		-- arc, for effects and audio. Gameplay does not read it: the server
		-- decides what a swing hits.
		Swing = { Name = "Swing", Required = true, Looped = false, Priority = "Action4", Markers = { "SwingHit" } },
		Recover = { Name = "HammerRecover", Required = false, Looped = false, Priority = "Action2", Markers = {} },
	},
}

return table.freeze({
	Clips = clips,
	-- Parent folder of every clip above.
	FolderName = "Animations",
	-- Crossfade times in seconds. Attacks cut in fast so a press feels
	-- immediate; holds and recoveries blend slowly so they do not pop.
	FadeTime = {
		Attack = 0.04,
		Hold = 0.18,
		Recover = 0.12,
	},
})
