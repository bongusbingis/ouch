local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local InputSetup = require(Modules:WaitForChild("InputSetup"))
local BallSpawner = require(Modules:WaitForChild("BallSpawner"))

local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local ServerAuthAdapter = require(Adapters:WaitForChild("ServerAuthAdapter"))

InputSetup.start()
BallSpawner.start()

-- Server-side events are authoritative; this is the hook match/score logic
-- attaches to later. Prints suffice for the M2 exit check.
ServerAuthAdapter.onEvent(function(event)
	if event.kind == "Elim" then
		print(`[Combat] {event.sourceId} eliminated {event.targetId} ({event.projectileId})`)
	end
end)

ServerAuthAdapter.start()
