--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local PartyStatus = require(script.Parent.PartyStatus)
local ResponsiveText = require(script.Parent.ResponsiveText)

local c = React.createElement

export type Props = {
	PartyState: string,
	ShowMatchmakingActivity: boolean,
	PlayText: string,
	PlayEnabled: boolean,
	OnPlay: () -> (),
	OnInvite: () -> (),
	OnJoinCode: () -> (),
	Position: any?,
}

return function(props: Props)
	return c("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		FontFace = Font.new(
			"rbxasset://fonts/families/HighwayGothic.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		),
		Position = UDim2.fromScale(0.01, 0.99),
		Size = UDim2.fromScale(0.2, 0.03),
		Text = "Version xxx\n123456789",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	})
end
