-- Description: Edit-mode-safe lobby header preview. Its world-facing decoration is intentionally omitted.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local LobbyHeader = require(script.Parent.Parent.Components.LobbyHeader)
local mount = require(script.Parent.StoryRoot)

local tabs = {
	{ Id = "SplashScreen", Label = "PLAY", LayoutOrder = 1 },
	{ Id = "Shop", Label = "SHOP", LayoutOrder = 2 },
	{ Id = "Inventory", Label = "BACKPACK", LayoutOrder = 3 },
	{ Id = "Settings", Label = "SETTINGS", LayoutOrder = 4 },
}

local function Story()
	local page, setPage = React.useState("SplashScreen")
	return React.createElement(LobbyHeader, {
		Tabs = tabs,
		CurrentPage = page,
		OnNavigate = setPage,
		DecorationTarget = false,
	})
end

return function(target: Instance)
	return mount(target, React.createElement(Story))
end
