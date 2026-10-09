--[[
    The gameplay emote wheel (EmoteWheel): the segmented ring over a dimmed screen, the lit wedge,
    the emote name under the ring and the per-device release hint, plus the small touch button
    that opens it on phones.

    Why: the wheel's copy and colours depend on the device and on what the pointer is over (a
    filled slot, an empty slot, nothing), and its ring divides by the slot capacity -- each of
    those is a state here instead of one fixed snapshot.

    States
      Keyboard · slot 2       open, ShowtimeTwirl lit, "RELEASE ... TO PLAY" keyboard hint (the
                              old story's only state).
      Gamepad · empty slot    selection on an empty slot: "EMPTY SLOT", gamepad hint.
      Touch · nothing lit     open with no selection: "EMOTES", drag-and-release hint.
      Capacity 4 · full       four slots, all filled.
      Capacity 8              eight slots, four filled (the wheel's widest split).
      Touch · closed          wheel shut: only the touch button (bottom right) shows.

    Snapshots are fixed (props.Snapshot) so no controller input is needed; the wheel sizes from the
    camera viewport, so these are Screen frames.
]]

--!strict

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local EmoteWheel = require(StoryRoot.Components:WaitForChild("EmoteWheel"))

local c = React.createElement

local function wheel(options: {
	open: boolean?,
	selected: number?,
	device: string,
	capacity: number?,
	slots: { string }?,
}): any
	return c(EmoteWheel, {
		ShowTouchButton = options.device == "Touch",
		RegisterTouchExclusion = function()
			return true
		end,
		Snapshot = {
			open = options.open ~= false,
			selected = options.selected,
			slots = options.slots or Fixtures.EmoteSlots,
			capacity = options.capacity or Fixtures.EmoteCapacity,
			deviceClass = options.device,
			pointer = Vector2.zero,
		},
	})
end

local FULL_FOUR = { "EmoteWave", "ShowtimeTwirl", "ShowtimeFlex", "ShowtimeBounce" }

return StoryRoot.story({
	Title = "Emote Wheel",
	Summary = "EmoteWheel per device and selection (filled slot, empty slot, none), at capacities 4 / 6 / 8, "
		.. "and the touch button that opens it.",
	States = {
		{
			Name = "Keyboard · slot 2",
			Note = "Filled slot lit",
			Screen = true,
			Fit = 0.5,
			Element = wheel({ selected = 2, device = "Keyboard" }),
		},
		{
			Name = "Gamepad · empty slot",
			Note = "EMPTY SLOT",
			Screen = true,
			Fit = 0.5,
			Element = wheel({ selected = 5, device = "Gamepad" }),
		},
		{
			Name = "Touch · nothing lit",
			Note = "EMOTES + drag hint",
			Screen = true,
			Fit = 0.5,
			Element = wheel({ device = "Touch" }),
		},
		{
			Name = "Capacity 4 · full",
			Screen = true,
			Fit = 0.5,
			Element = wheel({ selected = 1, device = "Keyboard", capacity = 4, slots = FULL_FOUR }),
		},
		{
			Name = "Capacity 8",
			Note = "Four filled",
			Screen = true,
			Fit = 0.5,
			Element = wheel({ selected = 7, device = "Keyboard", capacity = 8 }),
		},
		{
			Name = "Nothing equipped",
			Note = "NO EMOTES YET + backpack hint",
			Screen = true,
			Fit = 0.5,
			Element = wheel({ selected = 2, device = "Keyboard", slots = {} }),
		},
		{
			Name = "Touch · closed",
			Note = "Touch button only",
			Screen = true,
			Fit = 0.5,
			Element = wheel({ open = false, device = "Touch" }),
		},
	},
})
