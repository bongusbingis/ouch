-- Name: BonksChip.luau
-- Author: Jack C.
-- Description: The one Bonks balance readout: a Claimed pill holding the coin and amount in white display lettering, so the Shop header and crate footer show the wallet the same way the Daily Rewards modal shows a reward.
-- Created: 2026-09-10
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local BonksLabel = require(script.Parent.BonksLabel)
local formatNumber = require(script.Parent.Parent.Models.NumberText)
local Surface = require(script.Parent.Arena.Surface)

local c = React.createElement
local Palette = UIConfig.ProgressionStyle

export type Props = {
	Amount: number,
	HeightPx: number?,
	TextSize: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
}

return function(props: Props)
	local height = props.HeightPx or 40
	local textSize = props.TextSize or 22
	local amount = props.Amount or 0
	local z = props.ZIndex or 5
	-- Surface faces are scale-sized, so the chip measures its own width instead of
	-- relying on AutomaticSize: icon (square, text-sized) + gap + amount + padding.
	local textWidth =
		TextService:GetTextSize(formatNumber(amount), textSize, Enum.Font.LuckiestGuy, Vector2.new(10000, 100)).X
	local width = 12 + textSize + UIConfig.Button.GapPx + math.ceil(textWidth) + 14
	return c(Surface, {
		Color = Palette.Claimed,
		Radius = UIConfig.Radius.Control,
		Shadow = false,
		StrokeTransparency = 0.55,
		Native = {
			AnchorPoint = props.AnchorPoint or Vector2.new(1, 0.5),
			LayoutOrder = props.LayoutOrder,
			Position = props.Position,
			Size = UDim2.fromOffset(width, height),
			ZIndex = z,
		},
	}, {
		Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 14),
		}),
		Amount = c(BonksLabel, {
			Amount = amount,
			MaxTextSize = textSize,
			TextColor = Palette.White,
			TextStroke = 0.045,
			Alignment = Enum.HorizontalAlignment.Center,
			Native = {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z + 1,
			},
		}),
	})
end
