-- Displays earned places and selected cosmetics; ties retain their authoritative shared rank.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ReactSpring = require(ReplicatedStorage.Packages["react-spring"])
local Motion = require(script.Parent.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Parent.Hooks.useReducedMotion)
local Colors = require(ReplicatedStorage.Config.Interface.ArenaPresentation).Colors
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics.Cosmetics)
local Label = require(script.Parent.Label)
local Surface = require(script.Parent.Surface)
local Avatar = require(script.Parent.CelebrationAvatar)
local InventoryPreview = require(script.Parent.Parent.InventoryPreview)
local c = React.createElement

local function skin(category: string, itemId: string?, x: number)
	local item = if itemId then Cosmetics.Items[itemId] else nil
	if item == nil or item.Category ~= category then
		itemId = nil
		item = Cosmetics.Defaults[category]
	end
	return c("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromScale(x, 0.02),
		Size = UDim2.fromScale(0.25, 0.49),
		ZIndex = 3,
	}, {
		Preview = c(InventoryPreview, { ItemId = itemId, Category = category, Definition = item, ZIndex = 3 }),
	})
end

return function(props)
	local reducedMotion = useReducedMotion()
	local styles = ReactSpring.useSpring({
		from = { Position = UDim2.fromOffset(0, 20) },
		Position = UDim2.fromOffset(0, 0),
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	local podium = props.Entries or {}
	local children = {}
	local count = math.min(#podium, 3)
	for index = 1, count do
		local entry = podium[index]
		local column = if count == 1 then 1 else if index == 1 then 2 else if index == 2 then 1 else 3
		local width = if count == 1 then 0.62 else 1 / 3
		local x = if count == 1 then 0.5 else (column - 0.5) / 3
		local height = if props.Compact
			then (if entry.placement == 1 then 0.52 else if entry.placement == 2 then 0.47 else 0.42)
			else (if entry.placement == 1 then 0.26 else if entry.placement == 2 then 0.2 else 0.16)
		local color = if entry.placement == 1
			then Colors.Yellow
			else if entry.placement == 2 then Colors.Cyan else Colors.Pink
		children[entry.playerId] = c("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(x, 1),
			Size = UDim2.fromScale(width, 1),
			ZIndex = 5,
		}, {
			Avatar = c(Avatar, {
				EmoteId = entry.emoteId,
				ColorId = entry.colorId,
				Native = { Position = UDim2.fromScale(-0.08, 0), Size = UDim2.fromScale(1.16, 1 - height) },
				ZIndex = 5,
			}),
			Base = c(Surface, {
				Color = color,
				Native = { Position = UDim2.new(0, 6, 1 - height, 0), Size = UDim2.new(1, -12, height, -7), ZIndex = 4 },
			}, {
				Ball = if not props.Compact then skin("BallAssets", entry.ballId, 0.06) else nil,
				Hammer = if not props.Compact then skin("HammerAssets", entry.hammerId, 0.7) else nil,
				Rank = c(Label, {
					Text = tostring(entry.placement),
					Title = true,
					Size = if props.Compact then 32 else 56,
					Native = { Size = UDim2.fromScale(1, 0.53) },
				}),
				Name = c(Label, {
					Text = entry.displayName,
					Title = true,
					Size = 23,
					Native = { Position = UDim2.fromScale(0.04, 0.53), Size = UDim2.fromScale(0.92, 0.25) },
				}),
				Score = c(Label, {
					Text = `{entry.score} ELIMS`,
					Size = 17,
					Native = { Position = UDim2.fromScale(0, 0.79), Size = UDim2.fromScale(1, 0.2) },
				}),
			}),
		})
	end
	if count == 0 then
		children.Ball = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.08, 0.05),
			Size = UDim2.fromScale(0.45, 0.55),
		}, { Preview = c(InventoryPreview, { Category = "BallAssets", Definition = Cosmetics.Defaults.BallAssets }) })
		children.Hammer = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.46, 0.05),
			Size = UDim2.fromScale(0.45, 0.55),
		}, {
			Preview = c(InventoryPreview, { Category = "HammerAssets", Definition = Cosmetics.Defaults.HammerAssets }),
		})
		children.Message = c(Label, {
			Text = "NO WINNER THIS ROUND",
			Title = true,
			Size = if props.Compact then 24 else 38,
			Native = { Position = UDim2.fromScale(0.05, 0.65), Size = UDim2.fromScale(0.9, 0.25) },
		})
	end
	return c(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = styles.Position },
		children
	)
end
