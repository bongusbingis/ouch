--!strict
-- Camera and overlay use the same server deadline: late clients join the shot
-- already in progress and duplicate snapshots never restart the sequence.
local ReplicatedStorage = script.Parent.Parent.Parent.Parent
local Splashdown = require(ReplicatedStorage.Config.Gameplay.Splashdown)
local Intro = require(ReplicatedStorage.Config.Interface.SplashdownIntro)

local Model = {}

function Model.course(courseId: string)
	return Intro.Courses[courseId]
		or {
			Description = "Race through the checkpoints and make a dash for the finish!",
			Shots = Intro.Courses.WhirlPool.Shots,
		}
end

function Model.sample(courseId: string, endsAt: number, now: number)
	local shots = Model.course(courseId).Shots
	local duration = Splashdown.IntroSeconds
	local elapsed = math.clamp(now - (endsAt - duration), 0, duration)
	local shotSeconds = duration / #shots
	local index = math.min(math.floor(elapsed / shotSeconds) + 1, #shots)
	local localTime = elapsed - (index - 1) * shotSeconds
	local fade = Intro.CutFadeSeconds
	local cover = 1 - math.clamp(math.min(localTime, shotSeconds - localTime) / fade, 0, 1)
	return {
		shot = shots[index],
		index = index,
		count = #shots,
		progress = elapsed / duration,
		cover = cover,
	}
end

-- Preserve the authored horizontal composition on narrow viewports.
function Model.fieldOfView(authored: number, aspect: number): number
	local adjustment = math.max(1, Intro.ReferenceAspect / math.max(aspect, 0.1))
	return math.min(Intro.MaxFieldOfView, math.deg(2 * math.atan(math.tan(math.rad(authored) / 2) * adjustment)))
end

return table.freeze(Model)
