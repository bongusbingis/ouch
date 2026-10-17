--!strict
local T = require(script.Parent.Parent.Tokens)
local Model = {}
local LESSONS = { "NormalThrow", "Dodge", "Hammer", "ChargedThrow", "Practice" }

function Model.build(snapshot)
	local step = snapshot.step or "Intro"
	local device = snapshot.deviceClass
	local jump = if device == "Touch" then "Tap jump" elseif device == "Gamepad" then "Press A" else "Press Space"
	local copy = {
		Intro = { "WELCOME TO TRAINING!", "Let's learn to throw, swing and dodge." },
		NormalThrow = { "THROW!", "Aim at the dummy, then throw your ball." },
		Dodge = { "GET ACROSS!", "The spinning bar will knock you off. Jump it or time it." },
		Hammer = { "BONK!", "Get close to the dummy, then swing your hammer." },
		ChargedThrow = { "HOLD FOR POWER!", "Hold to charge your throw, then release." },
		Practice = { "KNOCK 'EM OUT!", "Ball and hammer are both yours. Clear the ring!" },
		Celebration = { "YOU'RE READY!", "Take those skills into a real match!" },
	}
	local hints = {
		NormalThrow = "Point at the red dummy and throw; your first throw curves in.",
		Dodge = jump .. " as the bar sweeps past, then follow the arrow across.",
		Hammer = "Walk right up to the dummy before you swing.",
		ChargedThrow = "Hold until the ball glows, then let go.",
		Practice = "Any weapon, any dummy. Knock all four down.",
	}
	local entry = copy[step] or copy.Intro
	local index = table.find(LESSONS, step) or 0
	return {
		title = if snapshot.retrying then "TRY AGAIN!" elseif snapshot.succeeded then "NICE!" else entry[1],
		detail = if snapshot.retrying
			then "Watch the bar for one swing, then go."
			elseif snapshot.succeeded then "Keep going!"
			elseif (snapshot.hintLevel or 0) > 0 then hints[step] or entry[2]
			else entry[2],
		-- The key/glyph is drawn by InputHint ("[X] SKIP"), so the copy stays one word.
		skip = "SKIP",
		celebrating = step == "Celebration",
		done = if step == "Celebration"
			then #LESSONS
			else math.max(0, index - 1) + (if snapshot.succeeded then 1 else 0),
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
