-- Description: Detects a live Studio Play session (simulation running with a player present, where Debug.StudioQueue auto-starts a match and the live arena/ball services mutate the world) so specs that need an untouched arena or an empty server can skip with an explicit reason instead of failing on live state. The cloud run has no players and never trips this.

--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LiveSession = {}

LiveSession.REASON = "live Play session: a player is present and the live match, arena and ball services own the world"

function LiveSession.active(): boolean
	return RunService:IsRunning() and #Players:GetPlayers() > 0
end

-- Returns a drop-in `it` that registers a skipped test whose name states the reason when a live
-- session is active, and a normal test otherwise. Pass the TestEZ `it` and `itSKIP` globals.
function LiveSession.guardedIt(it: (string, () -> ()) -> (), itSKIP: (string, () -> ()) -> ()): (string, () -> ()) -> ()
	return function(name: string, body: () -> ())
		if LiveSession.active() then
			itSKIP(`{name} [skipped: {LiveSession.REASON}]`, body)
		else
			it(name, body)
		end
	end
end

return LiveSession
