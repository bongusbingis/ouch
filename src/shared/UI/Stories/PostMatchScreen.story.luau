-- Description: Studio story previewing the post-match results screen against the debug result fixtures.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local DebugPostMatchData = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("PostMatch")
		:WaitForChild("DebugPostMatchData")
)
local PostMatchScreen = require(script.Parent.Parent.Components.PostMatchScreen)
local mount = require(script.Parent.StoryRoot)

local c = React.createElement

local function Story()
	local scenarios = DebugPostMatchData.scenarios()
	local index, setIndex = React.useState(1)
	local replay, setReplay = React.useState(false)
	local scenario = scenarios[index]
	scenario.result.endsAt = Workspace:GetServerTimeNow() + 12
	local localUserId = Players.LocalPlayer.UserId
	if scenario.result.party then
		local localMemberIndex = scenario.localMemberIndex or 1
		for _, member in scenario.result.party.members do
			member.isLocal = false
		end
		scenario.result.party.members[localMemberIndex].isLocal = true
		scenario.result.party.members[localMemberIndex].userId = localUserId
		if localMemberIndex == 1 then
			scenario.result.party.leaderUserId = localUserId
		end
	end
	local leaderUserId = if scenario.result.party then scenario.result.party.leaderUserId else localUserId
	return c(React.Fragment, nil, {
		Screen = c(PostMatchScreen, {
			Visible = true,
			Result = scenario.result,
			Status = {
				resultId = scenario.result.resultId,
				revision = if replay then 2 else 1,
				state = if replay then "PlayAgain" else scenario.statusState or "Interactive",
				leaderUserId = leaderUserId,
			},
			Requesting = scenario.requesting,
			PendingAction = scenario.pendingAction,
			Error = scenario.error,
			OnPlayAgain = function()
				setReplay(not replay)
			end,
			OnReturnToLobby = function() end,
			OnLeaveParty = function() end,
		}),
		Toolbar = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(28, 36, 38),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.56, 0.055),
			ZIndex = 100,
		}, {
			Previous = c("TextButton", {
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				Size = UDim2.fromScale(0.15, 1),
				Text = "< PREV",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = false,
				TextSize = 18,
				ZIndex = 101,
				[React.Event.Activated] = function()
					setReplay(false)
					setIndex(if index == 1 then #scenarios else index - 1)
				end,
			}),
			Name = c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.62, 1),
				Text = scenario.name,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = false,
				TextSize = 18,
				ZIndex = 101,
			}),
			Next = c("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromScale(0.15, 1),
				Text = "NEXT >",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = false,
				TextSize = 18,
				ZIndex = 101,
				[React.Event.Activated] = function()
					setReplay(false)
					setIndex(index % #scenarios + 1)
				end,
			}),
		}),
	})
end

return function(target: Instance)
	return mount(target, c(Story))
end
