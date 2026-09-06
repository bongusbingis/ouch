--!strict

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local MatchHUD = require(script.Parent.Parent.Components.MatchHUD)
local Model = require(script.Parent.Parent.Models.MatchHUDModel)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	local view = Model.build({
		title = "TEAM DEATHMATCH",
		timeRemaining = 125,
		scoreTarget = 40,
		teamMode = true,
		redScore = 18,
		blueScore = 22,
		teamId = "Blue",
		alive = target:GetAttribute("Respawning") ~= true,
		respawnAt = 3,
	}, 0)
	return mount(target, React.createElement(MatchHUD, { Snapshot = view, Visible = true }))
end
