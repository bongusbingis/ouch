-- Description: Earliest-running client script that adopts the arriving teleport loading screen, suppresses the default Roblox one, and tears both down once the React loading screen reports itself on screen.

--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local arrivingGui: ScreenGui? = nil
local ok, result = pcall(TeleportService.GetArrivingTeleportGui, TeleportService)
if ok and result and result:IsA("ScreenGui") then
	arrivingGui = result
	result.Name = "ArrivingLoadingScreen"
	result.ResetOnSpawn = false
	result.Parent = playerGui
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end

local connection: RBXScriptConnection? = nil
local function finish()
	if ReplicatedFirst:GetAttribute("ReactLoadingPresented") ~= true then
		return
	end
	ReplicatedFirst:RemoveDefaultLoadingScreen()
	if arrivingGui then
		arrivingGui:Destroy()
		arrivingGui = nil
	end
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

connection = ReplicatedFirst:GetAttributeChangedSignal("ReactLoadingPresented"):Connect(finish)
finish()
