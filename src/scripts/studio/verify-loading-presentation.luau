-- Run in a Play client to check loading readiness across initial mount, hide, and reopen.
--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
assert(RunService:IsRunning() and RunService:IsClient(), "Run this check in a Play client")
local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local LoadingScreen = require(ReplicatedStorage.Shared.UI.Components.LoadingScreen)
local host = Instance.new("ScreenGui")
host.Name = "LoadingPresentationCheck"
host.IgnoreGuiInset = true
host.DisplayOrder = 1000
host.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local root = ReactRoblox.createRoot(host)
local presentations = 0
local function render(visible, static)
	root:render(React.createElement(LoadingScreen, {
		Visible = visible,
		Static = static,
		Title = "LOADING ARENA",
		OnPresented = function()
			presentations += 1
		end,
	}))
end
local function awaitCount(expected)
	local deadline = os.clock() + 3
	repeat
		task.wait()
	until presentations >= expected or os.clock() >= deadline
	assert(presentations == expected, `Expected {expected} presentations, got {presentations}`)
end
local ok, err = pcall(function()
	render(true, false)
	awaitCount(1)
	render(false, true)
	task.wait(0.2)
	assert(presentations == 1, "Hidden loading screen announced itself")
	render(true, true)
	awaitCount(2)
	render(false, true)
	task.wait(0.2)
	render(true, false)
	awaitCount(3)
end)
root:unmount()
host:Destroy()
assert(ok, err)
return { presentations = presentations }
