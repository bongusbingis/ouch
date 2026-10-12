--[[
    NotificationModal, the one confirm/notice dialog every lobby flow raises, in the three shapes
    it is called with: a two-button confirmation with a destructive red action (KICK PLAYER?), a
    single-button notice (REMOVED FROM PARTY, as LobbyApp raises when you are kicked) and a long
    description that has to wrap. Screen frames: the modal centres on the viewport. Choices print
    their Value; FocusEnabled is off.

    Migrated from NotificationModal.story (kick confirmation only).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local NotificationModal = require(StoryRoot.Components:WaitForChild("NotificationModal"))

local c = React.createElement

local function modal(request: any): any
	return c(NotificationModal, {
		FocusEnabled = false,
		Request = request,
		OnChoose = Fixtures.log("Notifications", "OnChoose"),
	})
end

return StoryRoot.story({
	Title = "Notifications",
	Summary = "NotificationModal as a red/blue confirmation, a one-button notice and a long wrapping message.",
	States = {
		{
			Name = "Confirm kick",
			Screen = true,
			Fit = 0.5,
			Element = modal({
				Title = "KICK PLAYER?",
				Description = "ARE YOU SURE YOU WANT TO REMOVE PLAYER FROM YOUR PARTY?",
				Buttons = {
					{ Color = "Red", Text = "KICK", Value = true },
					{ Color = "Blue", Text = "CANCEL", Value = false },
				},
			}),
		},
		{
			Name = "Notice",
			Note = "Single button.",
			Screen = true,
			Fit = 0.5,
			Element = modal({
				Title = "REMOVED FROM PARTY",
				Description = "YOU WERE REMOVED FROM THE PARTY.",
				Buttons = { { Color = "Blue", Text = "CONFIRM", Value = true } },
			}),
		},
		{
			Name = "Long message",
			Note = "Wrapping description.",
			Screen = true,
			Fit = 0.5,
			Element = modal({
				Title = "REWARDS ARE STILL SAVING",
				Description = "YOUR LAST MATCH'S REWARDS ARE STILL BEING SAVED. YOU CAN KEEP PLAYING — THEY WILL APPEAR IN YOUR BACKPACK AS SOON AS THE SAVE FINISHES.",
				Buttons = { { Color = "Blue", Text = "OK", Value = true } },
			}),
		},
	},
})
