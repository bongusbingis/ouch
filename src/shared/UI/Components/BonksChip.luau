-- Name: BonksChip.luau
-- Author: Jack C.
-- Description: The one Bonks balance readout: a cream candy pill holding the coin and amount in ink display lettering, so the Shop header and crate footer show the wallet the same way the Daily Rewards modal shows a reward.
-- Created: 2026-09-10
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local BonksLabel = require(script.Parent.BonksLabel)
local CandyPanel = require(script.Parent.CandyPanel)
local formatNumber = require(script.Parent.Parent.Models.NumberText)
local T = require(script.Parent.Parent.Tokens)

local c = React.createElement

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
	local height = props.HeightPx or T.Layout.MinTarget
	local textSize = math.max(props.TextSize or T.Type.TileLabel, T.Type.Minimum)
	local amount = props.Amount or 0
	local z = props.ZIndex or 5
	local inset = T.Layout.CompactGap
	-- The pill is scale-sized, so the chip measures its own width instead of
	-- relying on AutomaticSize: padding + icon (square, text-sized) + gap + amount + padding.
	local textWidth = TextService:GetTextSize(formatNumber(amount), textSize, T.Type.Display, Vector2.new(10000, 100)).X
	local width = inset * 2 + textSize + UIConfig.Button.GapPx + math.ceil(textWidth)
	return c(CandyPanel, {
		Color = T.Colors.Surface,
		Padding = 0,
		Tilt = 0,
		Radius = T.Shape.RadiusPill,
		Shadow = false,
		Native = {
			AnchorPoint = props.AnchorPoint or Vector2.new(1, 0.5),
			LayoutOrder = props.LayoutOrder,
			Position = props.Position,
			Size = UDim2.fromOffset(width, height),
			ZIndex = z,
		},
	}, {
		Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0, inset),
			PaddingRight = UDim.new(0, inset),
		}),
		Amount = c(BonksLabel, {
			Amount = amount,
			MaxTextSize = textSize,
			TextColor = T.Colors.Ink,
			TextStroke = 0,
			Alignment = Enum.HorizontalAlignment.Center,
			Native = {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z + 1,
			},
		}),
	})
end
