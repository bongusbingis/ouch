-- Name: ModalClose.luau
-- Author: Jack C.
-- Description: The one modal close control: the Daily Rewards pink X, 44 px square, sitting at the panel inset so every modal in the game dismisses the same way.
-- Created: 2026-09-10
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)

local c = React.createElement
local artwork = UIConfig.LobbyArtwork.Action
local Palette = UIConfig.ProgressionStyle

export type Props = {
	OnActivated: (() -> ())?,
	ButtonRef: any?,
	Enabled: boolean?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	SizePx: number?,
	ZIndex: number?,
}

return function(props: Props)
	local side = props.SizePx or UIConfig.Interaction.MinTargetPx
	local z = props.ZIndex or 4
	return c(AnimatedButton, {
		ButtonRef = props.ButtonRef,
		SelectionRadius = UDim.new(0, artwork.CornerPx),
		Enabled = props.Enabled ~= false and props.OnActivated ~= nil,
		OnActivated = props.OnActivated,
		Native = {
			AnchorPoint = props.AnchorPoint or Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Image = artwork.Pink,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = artwork.PinkSlice,
			SliceScale = artwork.SliceScale,
			Position = props.Position or UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(side, side),
			ZIndex = z,
		},
	}, {
		Label = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
			Position = UDim2.fromOffset(0, 1),
			Size = UDim2.fromScale(1, 1),
			Text = "X",
			TextColor3 = Palette.White,
			TextSize = math.round(side * 0.68),
			ZIndex = z + 1,
		}, {
			Outline = c("UIStroke", {
				Color = Palette.Ink,
				Thickness = 0.045,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			}),
		}),
	})
end
