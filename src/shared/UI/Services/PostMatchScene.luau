-- Owns the local world-stage clone and its camera lease. Match results own standings;
-- the existing emote projection supplies presentation changes without moving live characters.
--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Presentation =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation"))
local Config = Presentation.Results
local Camera = require(script.Parent.PresentationCamera)
local EmoteRig = require(script.Parent.EmoteRig)
local Framing = require(script.Parent.Parent.Models.StageFraming)
local T = require(script.Parent.Parent.Tokens)
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Scene = {}

local Palette = T.Results.StagePalette
local PlacementColors = T.Results.PlacementColors
local ConfettiColors = T.Results.Confetti

local function paint(instance: Instance, color: Color3?)
	if color and instance:IsA("BasePart") then
		instance.Color = color
	end
end

-- Lighting-independent lilac sky: a SurfaceGui is not lit by the arena Lighting, which is what
-- washed the SmoothPlastic backdrop to royal blue. The authored swirl texture moves onto it.
local BACKDROP_CANVAS = Vector2.new(1000, 640)
local SWIRL_TILE = 56

local function dressBackdrop(backdrop: BasePart)
	local swirlImage = ""
	for _, child in backdrop:GetChildren() do
		if child:IsA("Texture") then
			swirlImage = child.Texture
			child:Destroy()
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sky"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = BACKDROP_CANVAS
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.Parent = backdrop
	local sky = Instance.new("Frame")
	sky.Name = "Gradient"
	sky.BorderSizePixel = 0
	sky.BackgroundColor3 = Palette.Backdrop
	sky.Size = UDim2.fromScale(1, 1)
	sky.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, T.Colors.BackdropTop),
		ColorSequenceKeypoint.new(0.55, Palette.Backdrop),
		ColorSequenceKeypoint.new(1, Palette.Backdrop:Lerp(T.Colors.BackdropBottom, 0.45)),
	})
	gradient.Parent = sky
	if swirlImage ~= "" then
		local swirl = Instance.new("ImageLabel")
		swirl.Name = "Swirl"
		swirl.BackgroundTransparency = 1
		swirl.Image = swirlImage
		swirl.ImageTransparency = 0.84
		swirl.ScaleType = Enum.ScaleType.Tile
		swirl.TileSize = UDim2.fromOffset(SWIRL_TILE, SWIRL_TILE)
		swirl.Size = UDim2.fromScale(1, 1)
		swirl.Parent = gui
	end
end

-- Authored names carry a side suffix (WingTrim1, WingTrim-1); fall back to the stem.
local function paletteColor(name: string): Color3?
	return Palette[name] or Palette[string.gsub(name, "%-?%d+$", "")]
end

local function isPurple(color: Color3): boolean
	local hue, saturation = color:ToHSV()
	return hue > 0.7 and hue < 0.8 and saturation > 0.35
end

-- The authored stage keeps its geometry; only its palette moves to the candy tokens.
local function paintStage(stage: Model)
	for _, child in stage:GetDescendants() do
		if child:IsA("BasePart") and child.Name ~= "ConfettiPiece" and not child:FindFirstAncestor("Stands") then
			local color = paletteColor(child.Name)
			if color == nil and child.Transparency < 1 and isPurple(child.Color) then
				-- Any leftover authoring-purple slab joins the lilac set instead of reading as a stray block.
				color = Palette.Backdrop
			end
			if child.Name == "Deck" then
				-- Cream under bright arena light blows out to flat white; a lilac cast keeps the deck readable.
				color = Palette.Deck:Lerp(Palette.Backdrop, 0.28)
			end
			paint(child, color)
			if child.Name == "Backdrop" then
				dressBackdrop(child)
			end
		end
	end
end

local function paintStand(stand: Model, placement: number, neutral: boolean?)
	local color = if neutral then T.Colors.Cyan else PlacementColors[math.clamp(placement, 1, 3)]
	for _, child in stand:GetChildren() do
		if child.Name == "Pillar" or child.Name == "Top" then
			paint(child, color)
		else
			paint(child, Palette[child.Name])
		end
	end
	local plaque = stand:FindFirstChild("Plaque")
	local label = if plaque then plaque:FindFirstChild("Label") else nil
	local rank = if label then label:FindFirstChild("Rank") else nil
	if rank and rank:IsA("TextLabel") then
		rank.Font = T.Type.Display
		rank.TextColor3 = T.Colors.Surface
		local stroke = rank:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = T.Colors.Ink
		end
	end
end

function Scene.create(entries: { any }, viewport: GuiObject)
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("ResultsStage")
	assert(template:IsA("Model"), "[PostMatchScene] Assets.UI.ResultsStage must be a Model")
	local stage = template:Clone()
	stage.Name = "PostMatchStage"
	stage:PivotTo(Config.StageOrigin)
	paintStage(stage)
	stage.Parent = Workspace
	local stands = stage:WaitForChild("Stands")
	local confettiTemplate = stage:WaitForChild("ConfettiPiece")
	assert(confettiTemplate:IsA("BasePart"), "[PostMatchScene] ConfettiPiece must be a BasePart")
	local confettiCap = 18
	local rigs = {}
	local active = true
	local jobs = {}
	for index = 1, 3 do
		local stand = stands:WaitForChild("Stand" .. index)
		assert(stand:IsA("Model"), "[PostMatchScene] stand must be a Model")
		local entry = entries[index]
		if entry == nil then
			stand:Destroy()
		else
			local placement = math.clamp(entry.placement, 1, 3)
			if placement ~= index then
				local position = stand:GetPivot()
				stand:Destroy()
				stand = template.Stands:WaitForChild("Stand" .. placement):Clone()
				stand.Name = "Stand" .. index
				stand:PivotTo(position)
				stand.Parent = stands
			end
			paintStand(stand, placement, entry.neutral)
			local marker = stand:WaitForChild("Avatar")
			assert(marker:IsA("BasePart"), "[PostMatchScene] stand Avatar must be a BasePart")
			local rank = stand:WaitForChild("Plaque"):WaitForChild("Label"):WaitForChild("Rank")
			assert(rank:IsA("TextLabel"), "[PostMatchScene] stand Rank must be a TextLabel")
			-- A neutral stand (a draw) has no rank to announce.
			rank.Text = if entry.neutral then "" else tostring(entry.placement)
			jobs[index] = task.defer(function()
				local display = EmoteRig.create(stage, entry.colorId, entry.costumeId)
				if not active then
					display.destroy()
					return
				end
				local bounds, size = display.model:GetBoundingBox()
				local bottom = bounds.Position.Y - size.Y / 2
				local origin = marker.CFrame * CFrame.new(0, -bottom, 0)
				display.setOrigin(origin)
				local confetti = {}
				for i = 1, confettiCap do
					local piece = confettiTemplate:Clone()
					piece.Parent = stage
					confetti[i] = piece
				end
				table.insert(
					rigs,
					{ display = display, entry = entry, origin = origin, marker = marker, confetti = confetti }
				)
			end)
		end
	end
	local time, accumulator = 0, 0
	local emoteConnection = Network.on("EmotePlayed", function(userId, emoteId)
		if type(userId) ~= "number" or type(emoteId) ~= "string" then
			return
		end
		for _, rig in rigs do
			if rig.entry.userId == userId then
				rig.display.playEmote(emoteId)
			end
		end
	end)
	local lease = Camera.acquire("Results", Camera.Priority.Results, function(camera, dt)
		local position = viewport.AbsolutePosition
		local size = viewport.AbsoluteSize
		position -= GuiService:GetInsetArea(Enum.ScreenInsets.None).Min
		local target = Config.StageOrigin:PointToWorldSpace(Config.StageTarget)
		camera.FieldOfView = Config.StageFieldOfView
		camera.CFrame =
			Framing.camera(target, Config.StageSpan, position, size, camera.ViewportSize, Config.StageFieldOfView)
		camera.Focus = CFrame.new(target)
		time += dt
		accumulator += dt
		if accumulator < 1 / Config.PodiumUpdateHz then
			return
		end
		accumulator = 0
		for _, rig in rigs do
			local reduced = GuiService.ReducedMotionEnabled
			for index, piece in rig.confetti do
				local visible = not reduced and index <= confettiCap
				piece.Transparency = if visible then 0 else 1
				if visible then
					local seed = index * 0.61803398875 % 1
					local phase = (time / 3.2 + seed) % 1
					piece.Color = ConfettiColors[index % #ConfettiColors + 1]
					piece.CFrame = rig.marker.CFrame
						* CFrame.new(
							(seed - 0.5) * 5 + math.sin(time + index) * 0.3,
							6 - phase * 6,
							(index * 0.37 % 1 - 0.5) * 3
						)
						* CFrame.Angles(time + index, index, time * 2)
				end
			end
		end
	end)
	return function()
		if not active then
			return
		end
		active = false
		emoteConnection:Disconnect()
		for _, job in jobs do
			if coroutine.status(job) ~= "dead" then
				task.cancel(job)
			end
		end
		for _, rig in rigs do
			rig.display.destroy()
		end
		stage:Destroy()
		Camera.release(lease)
	end
end

return Scene
