-- Description: Decides where a character is placed on every spawn: the authored arena spawns on an Arena venue, or the handler the race registered on a Splashdown venue, so MatchService never names a venue or a course.

--!strict

local ArenaService = require(script.Parent.ArenaService)
local VenueService = require(script.Parent.VenueService)

local SpawnRouter = {}

export type Reason = "MatchStart" | "Join" | "Respawn" | "Cleanup" | "Idle" | "Admin"
export type CourseHandler = (character: Model, player: Player?, reason: Reason) -> boolean

local courseHandler: CourseHandler? = nil

function SpawnRouter.registerCourseHandler(handler: CourseHandler?)
	courseHandler = handler
end

-- Idle spawns on an Arena venue stay where the native spawn put the character;
-- only a Splashdown venue owns every placement, because the native spawn there
-- sits above whatever course happens to be standing.
function SpawnRouter.spawn(character: Model, player: Player?, teamId: string?, reason: Reason)
	if VenueService.venue() == "Splashdown" then
		local handler = courseHandler
		if handler then
			handler(character, player, reason)
		end
		return
	end
	if reason == "Idle" then
		return
	end
	ArenaService.teleport(character, teamId)
end

return SpawnRouter
