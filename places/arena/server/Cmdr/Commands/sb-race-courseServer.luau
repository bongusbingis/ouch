-- Description: Server implementation of sb-race-course, choosing the next course through the Splashdown service's admin seam.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local SplashdownService = require(
	ServerScriptService:WaitForChild("Server")
		:WaitForChild("Modules")
		:WaitForChild("Splashdown")
		:WaitForChild("SplashdownService")
)

return function(_context: any, courseId: string): string
	local ok, reason = SplashdownService.setNextCourseForAdmin(courseId)
	if not ok then
		return `Could not choose {courseId}: {reason or "unknown_error"}.`
	end
	return `The next round runs on {courseId}.`
end
