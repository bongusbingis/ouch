-- Identifies visible allies from replicated team membership without revealing opponents or obscured characters.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Config = require(ReplicatedStorage.Config.Interface.ArenaPresentation)
local Model = require(script.Parent.Parent.Parent.Models.MatchHUDModel)
local Label = require(script.Parent.Label)
local c = React.createElement

return function(props)
	local view = props.Snapshot
	if not props.Visible or not view.teamMode then
		return nil
	end
	local markers = {}
	for _, entry in view.entries do
		if entry.head and Model.isTeammate(entry, view.teamId) then
			markers[tostring(entry.userId)] = c("BillboardGui", {
				Adornee = entry.head,
				AlwaysOnTop = false,
				LightInfluence = 0,
				MaxDistance = Config.Teammates.MaxDistanceStuds,
				Size = UDim2.fromOffset(116, 26),
				StudsOffsetWorldSpace = Vector3.new(0, Config.Teammates.HeightStuds, 0),
			}, {
				Name = c(Label, {
					Text = `TEAM • {entry.displayName}`,
					Color = if view.teamId == "Red" then Config.Colors.Pink else Config.Colors.Cyan,
					Size = 17,
				}),
			})
		end
	end
	return c(React.Fragment, nil, markers)
end
