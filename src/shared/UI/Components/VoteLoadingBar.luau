--!strict
-- A compact candy countdown, filled from the authoritative server deadline.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local CandyProgressBar = require(script.Parent.CandyProgressBar)
local CandySurface = require(script.Parent.CandySurface)
local VoteModel = require(script.Parent.Parent.Models.GameModeVoteViewModel)
local T = require(script.Parent.Parent.Tokens)

local c = React.createElement

export type Props = {
	Active: boolean,
	EndsAt: number,
	DurationSeconds: number,
	Position: UDim2?,
	Size: UDim2?,
}

return function(props: Props)
	local progress, setProgress = React.useBinding(1)
	local seconds, setSeconds = React.useBinding(0)

	React.useEffect(function()
		local function update()
			local now = Workspace:GetServerTimeNow()
			setProgress(VoteModel.progress(now, props.EndsAt, props.DurationSeconds))
			setSeconds(math.ceil(math.max(0, props.EndsAt - now)))
		end
		update()
		if not props.Active then
			return
		end
		local connection = RunService.RenderStepped:Connect(update)
		return function()
			connection:Disconnect()
		end
	end, { props.Active, props.EndsAt, props.DurationSeconds })

	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = props.Position or UDim2.fromScale(0.5, 0.975),
		Size = props.Size or UDim2.fromOffset(T.MapVote.BarMaxWidth, T.MapVote.BarHeight),
	}, {
		Surface = c(CandySurface, {
			Color = T.Colors.SurfaceWarm,
			LipColor = T.Colors.WellLine,
			Radius = T.Shape.RadiusCard,
			ZIndex = 1,
		}),
		Caption = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = T.Type.Label,
			Position = UDim2.fromOffset(18, 7),
			Size = UDim2.new(1, -104, 0, 20),
			Text = "VOTING ENDS",
			TextColor3 = T.Colors.Ink,
			TextSize = T.Type.Minimum,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
		}),
		Seconds = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = T.Type.Display,
			Position = UDim2.new(1, -84, 0, 5),
			Size = UDim2.fromOffset(66, 23),
			Text = seconds:map(function(value: number)
				return `{value}s`
			end),
			TextColor3 = T.Colors.Pink,
			TextSize = T.Type.TileLabel,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6,
		}),
		Bar = c(CandyProgressBar, {
			Progress = progress,
			Color = T.Colors.Pink,
			Native = {
				Position = UDim2.new(0, 18, 1, -20),
				Size = UDim2.new(1, -36, 0, 11),
				ZIndex = 6,
			},
		}),
	})
end
