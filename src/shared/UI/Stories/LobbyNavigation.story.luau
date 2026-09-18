-- Description: Interactive edit-mode preview of the lobby navigation rail.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local LobbyNavigation = require(script.Parent.Parent.Components.LobbyNavigation)
local mount = require(script.Parent.StoryRoot)

local tabs = {
	{ Id = "SplashScreen", Label = "PLAY", LayoutOrder = 1 },
	{ Id = "Shop", Label = "SHOP", LayoutOrder = 2 },
	{ Id = "Inventory", Label = "BACKPACK", LayoutOrder = 3 },
	{ Id = "Settings", Label = "SETTINGS", LayoutOrder = 4 },
}

local function Story(props)
	local page, setPage = React.useState("SplashScreen")
	return React.createElement(LobbyNavigation, {
		Tabs = tabs,
		CurrentPage = page,
		OnNavigate = setPage,
		Width = props.Width,
		Compact = props.Compact,
		IconOnly = props.IconOnly,
	})
end

return function(target: Instance)
	return mount(
		target,
		React.createElement(Story, {
			Width = target:GetAttribute("Width") or 680,
			Compact = target:GetAttribute("Compact") == true,
			IconOnly = target:GetAttribute("IconOnly") == true,
		})
	)
end
