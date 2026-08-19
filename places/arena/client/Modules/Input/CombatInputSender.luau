--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

-- Sends throw and catch intent to the server on the rising edge of each action.
-- Intent only: the server decides whether the action is legal, where it starts
-- from, and what it hits.

local CombatInputSender = {}

local started = false
local listeners: { (string) -> () } = {}

-- Lets presentation react to the local player's own intent at press time,
-- without a second place detecting the same input edge.
function CombatInputSender.onIntent(listener: (string) -> ())
	table.insert(listeners, listener)
end

local function notify(kind: string)
	for _, listener in listeners do
		local ok, err = pcall(listener, kind)
		if not ok then
			warn(`[CombatInputSender] intent listener error: {err}`)
		end
	end
end

function CombatInputSender.start()
	if started then
		return
	end
	started = true

	local context = Players.LocalPlayer:WaitForChild(InputConfig.ContextName)
	local aimAction = context:WaitForChild("Aim") :: InputAction
	local actions: { { kind: string, action: InputAction, pressed: boolean } } = {
		{ kind = "Throw", action = context:WaitForChild("Throw") :: InputAction, pressed = false },
		{ kind = "Catch", action = context:WaitForChild("Catch") :: InputAction, pressed = false },
	}

	-- One connection polling both actions rather than one each: the aim state is
	-- read at most once per frame instead of once per action.
	RunService.Heartbeat:Connect(function()
		local aimDir: Vector3? = nil
		for _, entry in actions do
			local pressed = entry.action:GetState() == true
			if pressed and not entry.pressed then
				if aimDir == nil then
					local state = aimAction:GetState()
					aimDir = if typeof(state) == "Vector3" and vector.magnitude(state) > 1e-6 then state else nil
				end
				if aimDir then
					Network.fireServer("SubmitCombatInput", entry.kind, aimDir)
					notify(entry.kind)
				end
			end
			entry.pressed = pressed
		end
	end)
end

return CombatInputSender
