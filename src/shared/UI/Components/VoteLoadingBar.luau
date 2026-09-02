-- Name: VoteLoadingBar.luau
-- Author: Jack C.
-- Description: The countdown bar on the mode ballot, filling from server time so every client shows the same remaining window.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local GameModeVoteViewModel = require(script.Parent.Parent.Models.GameModeVoteViewModel)

local c = React.createElement
local REFERENCE_HEIGHT = 1200
local STROKE_THICKNESS = 3 / (REFERENCE_HEIGHT * 0.027)

export type Props = {
	Active: boolean,
	EndsAt: number,
	DurationSeconds: number,
	Position: UDim2?,
	Size: UDim2?,
}

return function(props: Props)
	local progress, setProgress = React.useBinding(1)

	React.useEffect(function()
		local function update()
			setProgress(
				GameModeVoteViewModel.progress(Workspace:GetServerTimeNow(), props.EndsAt, props.DurationSeconds)
			)
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
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = props.Position or UDim2.fromScale(0.5, 0.895087),
		Size = props.Size or UDim2.fromScale(0.6, 0.027),
	}, {
		UICorner = c("UICorner", {
			BottomLeftRadius = UDim.new(1, 0),
			BottomRightRadius = UDim.new(1, 0),
			TopLeftRadius = UDim.new(1, 0),
			TopRightRadius = UDim.new(1, 0),
		}),
		InnerBar = c("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(26, 194, 230),
			Image = "rbxassetid://10051822476",
			ImageColor3 = Color3.fromRGB(124, 242, 255),
			Position = UDim2.fromScale(0, 0.5),
			ResampleMode = Enum.ResamplerMode.Pixelated,
			ScaleType = Enum.ScaleType.Tile,
			Size = progress:map(function(value: number)
				return UDim2.fromScale(value, 1)
			end),
			TileSize = UDim2.fromOffset(200, 200),
		}, {
			UICorner = c("UICorner", {
				BottomLeftRadius = UDim.new(1, 0),
				BottomRightRadius = UDim.new(1, 0),
				TopLeftRadius = UDim.new(1, 0),
				TopRightRadius = UDim.new(1, 0),
			}),
		}),
		UIPadding = c("UIPadding", {
			PaddingBottom = UDim.new(0.05, 0),
			PaddingLeft = UDim.new(0.003, 0),
			PaddingRight = UDim.new(0.003, 0),
			PaddingTop = UDim.new(0.05, 0),
		}),
		UIStroke = c("UIStroke", {
			Color = Color3.fromRGB(99, 99, 99),
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = STROKE_THICKNESS,
		}),
	})
end
