--!strict
local RS = game:GetService("ReplicatedStorage")
local T = require(RS.Shared.UI.Tokens)
local C = T.Colors
local CandyBackdrop = {}
function CandyBackdrop.new(background)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CandyBackdrop"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1920, 1080)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = background
	local face = Instance.new("Frame")
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = C.Surface
	face.BorderSizePixel = 0
	face.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.BackdropTop),
		ColorSequenceKeypoint.new(0.5, C.BackdropMid),
		ColorSequenceKeypoint.new(1, C.BackdropBottom),
	})
	gradient.Parent = face
	local swirl = Instance.new("ImageLabel")
	swirl.BackgroundTransparency = 1
	swirl.Size = UDim2.fromScale(1, 1)
	swirl.Image = T.Texture.Swirl
	swirl.ImageColor3 = C.Surface
	swirl.ImageTransparency = 1 - T.Texture.SwirlOpacity
	swirl.ScaleType = Enum.ScaleType.Tile
	swirl.TileSize = UDim2.fromOffset(360, 360)
	swirl.Parent = face
	local pieces = {}
	for i = 1, 42 do
		local piece = Instance.new("TextLabel")
		piece.BackgroundTransparency = 1
		piece.Size = UDim2.fromOffset(34, 34)
		piece.Position = UDim2.fromScale((i * 0.618) % 1, (i * 0.381) % 1)
		piece.Font = T.Type.Display
		piece.Text = ({ "•", "✦", "~", "▪" })[i % 4 + 1]
		piece.TextColor3 = ({ C.Pink, C.CyanLip, C.Grape, C.Surface })[i % 4 + 1]
		piece.TextSize = 30
		piece.TextTransparency = 1 - T.Texture.ConfettiOpacity
		piece.Rotation = i * 39 % 180
		piece.Parent = face
		table.insert(pieces, piece)
	end
	return {
		gui = gui,
		update = function(t)
			for i, piece in pieces do
				piece.Position = UDim2.fromScale((i * 0.618) % 1, (i * 0.381 + t / 100) % 1)
			end
		end,
		destroy = function()
			gui:Destroy()
		end,
	}
end
return CandyBackdrop
