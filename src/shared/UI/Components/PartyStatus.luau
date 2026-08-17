--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"))
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveText = require(script.Parent.ResponsiveText)

local c = React.createElement

export type Props = {
	Text: string,
	Active: boolean,
}

return function(props: Props)
	local dotOneTransparency, setDotOneTransparency = React.useBinding(1)
	local dotTwoTransparency, setDotTwoTransparency = React.useBinding(1)
	local dotThreeTransparency, setDotThreeTransparency = React.useBinding(1)
	local reducedMotion = useReducedMotion()

	React.useEffect(function()
		local setters = { setDotOneTransparency, setDotTwoTransparency, setDotThreeTransparency }
		for index, setTransparency in setters do
			setTransparency(if props.Active and reducedMotion then (index - 1) * 0.35 else 1)
		end
		if not props.Active or reducedMotion then
			return
		end

		local pulseDuration = UIConfig.PartyState.DotPulseSeconds
		local staggerDuration = UIConfig.PartyState.DotStaggerSeconds
		local sequenceDuration = pulseDuration + staggerDuration * 2 + UIConfig.PartyState.SequencePauseSeconds
		local elapsed = 0
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed = (elapsed + deltaTime) % sequenceDuration
			for index, setTransparency in setters do
				local dotTime = elapsed - (index - 1) * staggerDuration
				local opacity = if dotTime >= 0 and dotTime <= pulseDuration
					then math.sin(math.pi * dotTime / pulseDuration)
					else 0
				setTransparency(1 - opacity)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { props.Active, reducedMotion })

	local function dot(layoutOrder: number, transparency: any)
		return c("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = transparency,
			LayoutOrder = layoutOrder,
			Size = UDim2.fromScale(0.22, 0.65),
		}, {
			UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),
			UICorner = c("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		})
	end

	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.489696, 0.955724),
		Size = UDim2.fromScale(0.967519, 0.0940959),
	}, {
		ActivityDots = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.945, 0.5),
			Size = UDim2.fromScale(0.09, 0.72),
			Visible = props.Active,
		}, {
			UIListLayout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.08, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Dot1 = dot(1, dotOneTransparency),
			Dot2 = dot(2, dotTwoTransparency),
			Dot3 = dot(3, dotThreeTransparency),
		}),
		PartyState = c(ResponsiveText, {
			HostName = "PartyState",
			MeasurementFont = Enum.Font.LuckiestGuy,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.465, 0.52),
				Size = UDim2.fromScale(0.87, 1),
				Text = props.Text,
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeColor3 = Color3.fromRGB(24, 41, 48),
				TextStrokeTransparency = 0.25,
			},
		}),
	})
end
