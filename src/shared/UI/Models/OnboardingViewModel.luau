--!strict
local T = require(script.Parent.Parent.Tokens)
local Model = {}
local LESSONS = { "AvoidBumpers", "JumpSweepers", "TimeHammer", "Practice" }

function Model.build(snapshot)
	local step = snapshot.step or "Intro"
	local device = snapshot.deviceClass
	local jump = if device == "Touch" then "Tap Jump" elseif device == "Gamepad" then "Press A" else "Press Space"
	local copy = {
		Intro = { "WELCOME TO TRAINING!", "Follow the arrow. Let's practise avoiding obstacles." },
		AvoidBumpers = { "DODGE THE BUMPERS", "Move around them and follow the arrow." },
		JumpSweepers = { "JUMP OVER THE BAR", jump .. " as the spinning bar comes towards you." },
		TimeHammer = { "TIME YOUR RUN", "Wait for the hammer to swing away, then pass." },
		Practice = { "ONE MORE GO!", "Head back across the bridge. Dodge, jump and time it!" },
		Celebration = { "YOU'RE READY!", "Take those skills into Splashdown!" },
	}
	local hints = {
		AvoidBumpers = "Give each bumper room as you pass on its open side.",
		JumpSweepers = jump .. " near the bar, then land by the arrow.",
		TimeHammer = "Watch one swing. Move through while the hammer is up.",
		Practice = "Follow the arrow back. Each stop saves your progress.",
	}
	local entry = copy[step] or copy.Intro
	local index = table.find(LESSONS, step) or 0
	return {
		title = if snapshot.retrying then "TRY AGAIN!" elseif snapshot.succeeded then "NICE WORK!" else entry[1],
		detail = if snapshot.retrying
			then "Watch the obstacle and give it another go."
			elseif snapshot.succeeded then "Keep going!"
			elseif (snapshot.hintLevel or 0) > 0 then hints[step] or entry[2]
			else entry[2],
		-- The key/glyph is drawn by InputHint ("[X] SKIP"), so the copy stays one word.
		skip = "SKIP",
		celebrating = step == "Celebration",
		done = if step == "Celebration" then 4 else math.max(0, index - 1) + (if snapshot.succeeded then 1 else 0),
	}
end

function Model.layout(width: number, height: number, textScale: number?)
	local L = T.Onboarding
	local compact = height < L.ShortHeight or width < L.NarrowWidth
	local edge = if compact then L.CompactEdge else L.Edge
	local available = width - edge * 2
	local cardWidth = math.min(L.Width, available - L.SkipWidth - L.Gap)
	local title = math.round((if compact then L.CompactTitle else L.Title) * (textScale or 1))
	local body = math.round(T.Type.Minimum * (textScale or 1))
	local narrow = cardWidth < 320
	local titleHeight = math.ceil(title * (if narrow then 2.3 else 1.35))
	local bodyHeight = math.ceil(body * (if narrow then 3.6 else 2.4))
	return {
		width = cardWidth,
		height = L.Inset * 2 + titleHeight + bodyHeight,
		edge = edge,
		inset = L.Inset,
		title = title,
		body = body,
		titleHeight = titleHeight,
		bodyHeight = bodyHeight,
		x = math.min(width / 2, width - edge - L.SkipWidth - L.Gap - cardWidth / 2),
	}
end

return table.freeze(Model)
