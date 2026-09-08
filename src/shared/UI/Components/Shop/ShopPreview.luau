-- Description: Wraps the live item preview for use inside storefront cards and modals.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local BonksLabel = require(script.Parent.Parent.BonksLabel)
local InventoryPreview = require(script.Parent.Parent.InventoryPreview)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)

local c = React.createElement

return React.memo(function(props)
	if props.Thumbnail ~= nil and props.Thumbnail ~= "" then
		return c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.Thumbnail,
			Position = props.ThumbnailPosition or UDim2.fromScale(0.5, 0.5),
			ScaleType = Enum.ScaleType.Fit,
			-- Fitted to the whole artwork band rather than to a square inside it:
			-- the shop's icons are all wider than they are tall, so a square box
			-- would leave the band's width unused and shrink them. Artwork is
			-- authored with its own margin, so only a hairline is held back here.
			Size = props.ThumbnailSize or UDim2.fromScale(0.94, 0.94),
			ZIndex = props.ZIndex or 5,
		})
	end
	-- A currency offer with no artwork of its own shows what it grants as the
	-- coin plus the amount, the same way every price in the shop is written.
	if props.PlaceholderBonks then
		return c(BonksLabel, {
			Amount = props.PlaceholderBonks,
			MaxTextSize = props.BonksTextSize or 34,
			TextColor = props.TextColor,
			TextStroke = props.TextStroke or 0.05,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0.62),
				ZIndex = props.ZIndex or 5,
			},
		})
	end
	if #props.Items == 0 then
		return c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 34,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.55),
				Text = props.Placeholder or "COMING SOON",
				TextColor3 = props.TextColor or Color3.new(1, 1, 1),
				TextTransparency = 0.15,
				ZIndex = props.ZIndex or 5,
			},
		}, {
			Outline = if props.TextStroke
				then c("UIStroke", {
					Color = UI.ProgressionStyle.Ink,
					Thickness = props.TextStroke,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				})
				else nil,
		})
	end

	local children = {}
	local count = math.min(#props.Items, 3)
	for index = 1, count do
		local entry = props.Items[index]
		local width = if count == 1 then 1 else 0.54
		local x = if count == 1 then 0.5 else 0.2 + (index - 1) * (0.6 / math.max(count - 1, 1))
		children[entry.itemId or `{entry.category}:{index}`] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromScale(width, 1),
			ZIndex = (props.ZIndex or 5) + index,
		}, {
			Preview = c(InventoryPreview, {
				ItemId = entry.itemId,
				Category = entry.category,
				Definition = entry.definition,
				ColorId = props.ColorId,
				CostumeId = props.CostumeId,
				TextColor = props.TextColor,
				TextStroke = props.TextStroke or 0.045,
				ZIndex = (props.ZIndex or 5) + index,
			}),
		})
	end
	return c(React.Fragment, nil, children)
end)
