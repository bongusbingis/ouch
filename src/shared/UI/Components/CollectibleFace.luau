--!strict
-- The shared collectible card face drawn inside a card body (ItemTile, crate
-- results, crate odds): a recessed art window tinted by rarity, the candy
-- rarity tag pinned on the window's lower seam, the CAPS name in plum Fredoka
-- and an optional footer line. CollectibleLayout keeps the art clear of tags.
-- A grid passes one NameSize/NameHeight to every sibling (CollectibleLayout.
-- nameStyle) so names never mix sizes; a lone card measures its own name.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local Layout = require(script.Parent.Parent.Models.CollectibleLayout)
local Ribbon = require(script.Parent.RarityRibbon)
local c, C, K = React.createElement, T.Colors, T.Collectible

export type Props = {
	Width: number,
	Height: number,
	Rarity: string?,
	TagText: string?,
	TagColor: Color3?,
	CornerText: string?,
	CornerColor: Color3?,
	Name: string?,
	NameSize: number?,
	NameHeight: number?,
	Footer: string?,
	WellColor: Color3?,
	Art: any,
	ZIndex: number?,
}

local function wellColorFor(props: Props): Color3
	if props.WellColor then
		return props.WellColor
	end
	local tier = if props.Rarity then T.Rarity[props.Rarity] else nil
	return if tier then tier.Color:Lerp(C.Surface, K.WellTint) else C.Well
end

return function(props: Props)
	local z = props.ZIndex or 6
	local tagText = props.TagText or props.Rarity
	local face = Layout.card(props.Width, props.Height, {
		tag = tagText ~= nil,
		name = props.Name ~= nil,
		footer = props.Footer ~= nil,
		corner = props.CornerText ~= nil,
		nameHeight = props.NameHeight,
	})
	local well = face.well
	local fill = wellColorFor(props)
	local wellChildren: { [string]: any } = {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, K.WellRadius) }),
		Edge = c("UIStroke", { Color = fill:Lerp(C.Ink, K.WellEdgeTint), Thickness = T.Shape.StrokeInner }),
		Swirl = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = T.Texture.Swirl,
			ImageColor3 = C.Surface,
			ImageTransparency = 0.9,
			Size = UDim2.fromScale(1, 1),
			ZIndex = z,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, K.WellRadius) }) }),
		Art = c("Frame", {
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			Position = UDim2.fromOffset(face.art.x, face.art.y),
			Size = UDim2.fromOffset(face.art.w, face.art.h),
			ZIndex = z + 1,
		}, { Content = props.Art }),
	}
	local corner = face.corner
	if corner and props.CornerText then
		wellChildren.CornerTag = c(Ribbon, {
			Text = props.CornerText,
			Color = props.CornerColor or C.Yellow,
			Native = {
				Position = UDim2.fromOffset(corner.x, corner.y),
				Size = UDim2.fromOffset(Layout.tagWidth(props.CornerText, T.Type.Minimum, corner.maxWidth), corner.h),
				ZIndex = z + 6,
			},
		})
	end
	local children: { [string]: any } = {
		Well = c("Frame", {
			BackgroundColor3 = fill,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(well.x, well.y),
			Size = UDim2.fromOffset(well.w, well.h),
			ZIndex = z,
		}, wellChildren),
	}
	local tag = face.tag
	if tag and tagText then
		local width = Layout.tagWidth(string.upper(tagText), T.Type.Minimum, tag.maxWidth)
		children.RarityTag = c(Ribbon, {
			Rarity = props.Rarity,
			Text = props.TagText,
			Color = props.TagColor,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(tag.centerX, tag.y),
				Size = UDim2.fromOffset(width, tag.h),
				ZIndex = z + 8,
			},
		})
	end
	local name = face.name
	if name and props.Name then
		local text = string.upper(props.Name)
		children.ItemName = c("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(name.x, name.y),
			Size = UDim2.fromOffset(name.w, name.h),
			Font = T.Type.Display,
			Text = text,
			TextSize = props.NameSize or (Layout.nameStyle({ text }, name.w, name.h)),
			TextColor3 = C.Ink,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = z + 4,
		})
	end
	local footer = face.footer
	if footer and props.Footer then
		children.Footer = c("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(footer.x, footer.y),
			Size = UDim2.fromOffset(footer.w, footer.h),
			Font = T.Type.Label,
			Text = props.Footer,
			TextSize = T.Type.Minimum,
			TextColor3 = C.InkSoft,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = z + 4,
		})
	end
	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(props.Width, props.Height),
		ZIndex = z,
	}, children)
end
