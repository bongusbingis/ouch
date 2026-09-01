-- Name: TeleportGui.luau
-- Author: Jack C.
-- Description: Prepares and registers the screen shown during a teleport so it is carried into the destination place.
-- Created: 2026-08-24

--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local TeleportGui = {}

function TeleportGui.prepare(container: ScreenGui)
	container.Enabled = false
	container.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function TeleportGui.register(container: ScreenGui, cancelled: () -> boolean): (boolean, any?)
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	if cancelled() then
		return false, "cancelled"
	end

	container.Parent = nil
	container.Enabled = true
	return pcall(TeleportService.SetTeleportGui, TeleportService, container)
end

return TeleportGui
