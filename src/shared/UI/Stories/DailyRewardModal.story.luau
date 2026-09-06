-- Name: DailyRewardModal.story.luau
-- Author: Jack C.
-- Description: Studio story for the daily reward modal's claimable and already-claimed presentations.
-- Created: 2026-09-05

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local DailyRewardModal = require(script.Parent.Parent.Components.DailyRewardModal)
local StoryRoot = require(script.Parent.StoryRoot)

local c = React.createElement

local REWARDS = { 100, 125, 150, 200, 250, 300, 500 }

local function days(currentDay: number, claimedThrough: number)
	local list = {}
	for day, amount in REWARDS do
		table.insert(list, {
			day = day,
			reward = { kind = "Bonks", amount = amount },
			claimed = day <= claimedThrough,
			available = day == currentDay,
			current = day == currentDay,
		})
	end
	return list
end

local SCENARIOS = {
	{ name = "CLAIM PENDING", canClaim = true, currentDay = 1, nextDay = 1, claimedThrough = 0, pending = true },
	{
		name = "CLAIM FAILED",
		canClaim = true,
		currentDay = 1,
		nextDay = 1,
		claimedThrough = 0,
		errorText = "COULDN'T CLAIM. TRY AGAIN.",
	},
	{ name = "DAY 1 CLAIMABLE", canClaim = true, currentDay = 1, nextDay = 1, claimedThrough = 0 },
	{ name = "MID STREAK CLAIMABLE", canClaim = true, currentDay = 4, nextDay = 4, claimedThrough = 3 },
	{ name = "FINAL DAY CLAIMABLE", canClaim = true, currentDay = 7, nextDay = 7, claimedThrough = 6 },
	{ name = "ALREADY CLAIMED", canClaim = false, currentDay = 4, nextDay = 5, claimedThrough = 4 },
}

local function Story()
	local index, setIndex = React.useState(1)
	local scenario = SCENARIOS[index]

	return c("ScreenGui", {
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Backdrop = c("Frame", {
			BackgroundColor3 = Color3.fromRGB(104, 197, 222),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}),
		Modal = c(DailyRewardModal, {
			Visible = true,
			Pending = scenario.pending,
			ErrorText = scenario.errorText,
			State = {
				canClaim = scenario.canClaim,
				currentDay = scenario.currentDay,
				nextDay = scenario.nextDay,
				totalClaimed = scenario.claimedThrough,
				days = days(scenario.currentDay, scenario.claimedThrough),
			},
			OnClaim = function() end,
			OnClose = function() end,
		}),
		Next = c("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(27, 24, 47),
			BorderSizePixel = 0,
			FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
			Position = UDim2.fromScale(0.5, 0.02),
			Size = UDim2.fromOffset(320, 44),
			Text = scenario.name,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 19,
			ZIndex = 200,
			[React.Event.Activated] = function()
				setIndex(index % #SCENARIOS + 1)
			end,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }),
		}),
	})
end

return function(target: Instance)
	return StoryRoot(target, c(Story))
end
