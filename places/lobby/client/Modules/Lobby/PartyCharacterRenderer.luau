-- Description: Renders the lobby party members as posed character models, applying each member's equipped cosmetics and character color, and drives the inventory skin preview.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local T = require(ReplicatedStorage.Shared.UI.Tokens)
local CandyMotion = require(ReplicatedStorage.Shared.UI.Motion)
local CandyStage = require(script.Parent.CandyStage)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local InventoryConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))
local CharacterAppearance = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CharacterAppearance")
)
local CosmeticVisualFactory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CosmeticVisualFactory")
)
local HammerGrip = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics"):WaitForChild("HammerGrip")
)
local EmotePlayer = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics"):WaitForChild("EmotePlayer")
)
local PartyBubblePolicy = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Models"):WaitForChild("PartyBubblePolicy")
)
local PartyVisibilityPolicy = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Models")
		:WaitForChild("PartyVisibilityPolicy")
)

local USERNAME_LOOKUP_ATTEMPTS = 3
local USERNAME_RETRY_DELAY = 1
local USERNAME_RECOVERY_DELAY = 10
local IDLE_PLAYBACK_SPEED = 0.85
local IDLE_BOUNDS_PADDING = Vector3.new(1, 0.5, 1)
local BUBBLE_ANCHOR_OFFSET = Vector3.new(0, 1.25, 0)
local BUBBLE_CAMERA_CLEARANCE = 2

local PartyCharacterRenderer = {}
PartyCharacterRenderer.__index = PartyCharacterRenderer

local function corner(parent, radius)
	local result = Instance.new("UICorner")
	result.CornerRadius = UDim.new(0, radius)
	result.Parent = parent
	return result
end

local function kickLayer(name, color, position, size, zIndex, parent)
	local layer = Instance.new("Frame")
	layer.Name = name
	layer.BackgroundColor3 = color
	layer.BorderSizePixel = 0
	layer.Position = position
	layer.Size = size
	layer.ZIndex = zIndex
	corner(layer, T.Shape.RadiusPill)
	layer.Parent = parent
	return layer
end

local function configureKickButton(kickButton)
	local tokens = T.PartyNametag
	kickButton:ClearAllChildren()
	kickButton.AutoButtonColor = false
	kickButton.BackgroundTransparency = 1
	kickButton.Image = ""
	kickButton.Size = UDim2.fromOffset(tokens.KickSize, tokens.KickSize)

	local visual = Instance.new("Frame")
	visual.Name = "CandyFace"
	visual.AnchorPoint = Vector2.new(0.5, 0.5)
	visual.BackgroundTransparency = 1
	visual.Position = UDim2.fromScale(0.5, 0.5)
	visual.Rotation = tokens.KickTilt
	visual.Size = UDim2.fromScale(1, 1)
	visual.ZIndex = kickButton.ZIndex
	visual.Parent = kickButton

	local scale = Instance.new("UIScale")
	scale.Parent = visual

	local shadow = kickLayer(
		"Shadow",
		T.Colors.Ink,
		UDim2.fromOffset(tokens.KickShadowOffset.X, tokens.KickShadowOffset.Y),
		UDim2.fromScale(1, 1),
		kickButton.ZIndex,
		visual
	)
	shadow.BackgroundTransparency = T.Shape.ShadowTransparency

	local lip = kickLayer(
		"Lip",
		T.Colors.OrangeLip,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		kickButton.ZIndex + 1,
		visual
	)
	local outline = Instance.new("UIStroke")
	outline.Name = "CandyOutline"
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = T.Colors.Ink
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Thickness = T.Shape.StrokeTab
	outline.Parent = lip

	local fill = kickLayer(
		"Fill",
		T.Colors.Orange,
		UDim2.fromScale(0, 0),
		UDim2.new(1, 0, 1, -T.Shape.LipHeight),
		kickButton.ZIndex + 2,
		visual
	)
	local highlight = kickLayer(
		"Highlight",
		T.Colors.Surface,
		UDim2.fromOffset(T.Shape.StrokeTab, T.Shape.StrokeTab),
		UDim2.new(1, -T.Shape.StrokeTab * 2, T.Shape.HighlightHeight, 0),
		kickButton.ZIndex + 3,
		fill
	)
	highlight.BackgroundTransparency = T.Shape.HighlightTransparency
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(0, 1)
	fade.Parent = highlight

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = T.Type.Display
	label.Position = UDim2.fromOffset(0, -2)
	label.Size = UDim2.new(1, 0, 1, -T.Shape.LipHeight)
	label.Text = "X"
	label.TextColor3 = T.Colors.Surface
	label.TextSize = T.Type.Tab
	label.ZIndex = kickButton.ZIndex + 5
	label.Parent = visual
	local labelOutline = Instance.new("UIStroke")
	labelOutline.Color = T.Colors.Ink
	labelOutline.Thickness = T.Type.Outline
	labelOutline.Parent = label

	local activeTween = nil
	local function setScale(target, duration)
		if activeTween then
			activeTween:Cancel()
			activeTween = nil
		end
		if GuiService.ReducedMotionEnabled then
			scale.Scale = target
		else
			activeTween = TweenService:Create(
				scale,
				TweenInfo.new(duration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
				{ Scale = target }
			)
			activeTween:Play()
		end
	end
	kickButton.MouseEnter:Connect(function()
		if kickButton.Active then
			setScale(T.Motion.HoverScale, T.Motion.Hover)
		end
	end)
	kickButton.MouseLeave:Connect(function()
		setScale(1, T.Motion.Release)
	end)
	kickButton.MouseButton1Down:Connect(function()
		if kickButton.Active then
			setScale(T.Motion.PressScale, T.Motion.Press)
		end
	end)
	kickButton.MouseButton1Up:Connect(function()
		setScale(if kickButton.Active then T.Motion.HoverScale else 1, T.Motion.Release)
	end)
	kickButton.SelectionGained:Connect(function()
		if kickButton.Active then
			setScale(T.Motion.HoverScale, T.Motion.Hover)
		end
	end)
	kickButton.SelectionLost:Connect(function()
		setScale(1, T.Motion.Release)
	end)
	kickButton:GetPropertyChangedSignal("Active"):Connect(function()
		if not kickButton.Active then
			setScale(1, T.Motion.Release)
		end
	end)
end

function PartyCharacterRenderer.new(localUserId, onKick, getWorldBounds)
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local partyView = Workspace:WaitForChild("Views"):WaitForChild("Party")
	local characterContainer = partyView:WaitForChild("Players")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local characterTemplate = assets:WaitForChild("Rigs"):WaitForChild("CharacterRig")
	local nametagTemplate = assets:WaitForChild("UI"):WaitForChild("Nametag")
	local nametagPositions = {}
	for _, name in { "Username", "Crown", "KickButton" } do
		nametagPositions[name] = nametagTemplate:WaitForChild(name).Position
	end
	nametagPositions.Crown += UDim2.fromOffset(0, -T.PartyNametag.CrownLift)
	local spawns = {}

	for index = 1, Config.PartyMaxPlayers do
		spawns[index] = characterContainer:WaitForChild(("Player%d"):format(index))
	end

	local self = setmetatable({
		_localUserId = localUserId,
		_characterTemplate = characterTemplate,
		_idleAnimation = assets:WaitForChild("Animations"):WaitForChild("Idle"),
		_nametagTemplate = nametagTemplate,
		_nametagPositions = nametagPositions,
		_nametagStudsOffset = nametagTemplate.StudsOffset,
		_getWorldBounds = getWorldBounds,
		_characterContainer = characterContainer,
		_playerGui = playerGui,
		_spawns = spawns,
		_characters = {},
		_bodyBoundsByCostume = {},
		_onKick = onKick,
		_compactParty = false,
		_usernames = {
			[localUserId] = Players.LocalPlayer.Name,
		},
		_usernameRequests = {},
		_usernameListeners = {},
		_skinsPreview = nil,
		_candyStage = CandyStage.new(partyView),
		_previewAngle = 0,
		_backpackActive = false,
		_celebrateAt = -math.huge,
		_destroyed = false,
		_generation = 0,
		_appearanceRevision = 0,
	}, PartyCharacterRenderer)

	self._disconnectCelebrate = CandyMotion.onCelebrate(function(category, itemId)
		if self._backpackActive then
			self._celebrateAt = os.clock()
			self._candyStage.burst()
			if category == "EmoteAssets" and itemId then
				self:PlayEmote(localUserId, itemId)
				local character = self._characters[localUserId]
				local track = if character then character.emoteTrack else nil
				task.delay(T.Stage.EmoteReaction, function()
					if not self._destroyed and character and character.emoteTrack == track then
						EmotePlayer.stop(track)
						character.emoteTrack = nil
					end
				end)
			end
		end
	end)
	local dragX = nil
	self._dragBegin = UserInputService.InputBegan:Connect(function(input, processed)
		if not self._backpackActive or processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local bounds = if self._getWorldBounds then self._getWorldBounds() else nil
		local point = UserInputService:GetMouseLocation()
		if
			bounds
			and point.X >= bounds.Min.X
			and point.X <= bounds.Max.X
			and point.Y >= bounds.Min.Y
			and point.Y <= bounds.Max.Y
		then
			dragX = point.X
		end
	end)
	self._dragMove = UserInputService.InputChanged:Connect(function(input)
		if dragX and input.UserInputType == Enum.UserInputType.MouseMovement then
			self._previewAngle += (input.Position.X - dragX) * 0.012
			dragX = input.Position.X
		end
	end)
	self._dragEnd = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragX = nil
		end
	end)
	self:Render({ members = {} })
	self:_faceLocalCharacterToCamera()
	self._renderConnection = RunService.RenderStepped:Connect(function()
		self:_faceLocalCharacterToCamera()
		self:_updateSkinsPreview()
		self:_layoutNametags()
	end)
	-- This event contains this viewer's delivered, filtered TextChannel result.
	-- Never mirror SendingMessage, Player.Chatted, raw remotes, or cross-server party events.
	self._bubbleConnection = TextChatService.MessageReceived:Connect(function(message)
		local channels = TextChatService:FindFirstChild("TextChannels")
		local publicChannel = channels and channels:FindFirstChild("RBXGeneral")
		local userId = PartyBubblePolicy.senderId(message, publicChannel, self._characters, Players)
		local character = userId and self._characters[userId]
		if not self._destroyed and character and character.bubbleAnchor.Parent then
			TextChatService:DisplayBubble(character.bubbleAnchor, message.Text)
		end
	end)
	return self
end

function PartyCharacterRenderer:_bodyBounds(costumeId)
	local key = costumeId or ""
	local cached = self._bodyBoundsByCostume[key]
	if cached then
		return cached
	end
	-- Measure a neutral copy once per outfit. Animated bounds can make collision
	-- placement alternate between opposite sides of the character during idle.
	local rig = self._characterTemplate:Clone()
	local appearance = CharacterAppearance.create(rig, { costumeId = costumeId })
	local frame, size = rig:GetBoundingBox()
	local bounds = {
		frame = rig:GetPivot():ToObjectSpace(frame),
		size = size + IDLE_BOUNDS_PADDING,
	}
	appearance.destroy()
	rig:Destroy()
	self._bodyBoundsByCostume[key] = bounds
	return bounds
end

local function halfExtents(frame, size)
	local right = frame.RightVector * size.X / 2
	local up = frame.UpVector * size.Y / 2
	local back = frame.ZVector * size.Z / 2
	return Vector3.new(
		math.abs(right.X) + math.abs(up.X) + math.abs(back.X),
		math.abs(right.Y) + math.abs(up.Y) + math.abs(back.Y),
		math.abs(right.Z) + math.abs(up.Z) + math.abs(back.Z)
	)
end

local function projectedNametag(camera, nametag, spawn, studsOffset)
	local worldExtents = halfExtents(spawn.CFrame, spawn.Size)
	local cameraExtents = halfExtents(camera.CFrame:ToObjectSpace(spawn.CFrame), spawn.Size)
	local point = spawn.Position
		+ nametag.StudsOffsetWorldSpace
		+ nametag.ExtentsOffsetWorldSpace * worldExtents
		+ camera.CFrame:VectorToWorldSpace(studsOffset + nametag.ExtentsOffset * cameraExtents)
	local projected = camera:WorldToViewportPoint(point)
	local size = nametag.AbsoluteSize
	return Vector2.new(projected.X, projected.Y) - size / 2 + size * nametag.SizeOffset, size, projected.Z
end

local function projectedBody(camera, frame, size)
	local minimum, maximum = Vector2.one * math.huge, Vector2.one * -math.huge
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local point = camera:WorldToViewportPoint(frame:PointToWorldSpace(size * Vector3.new(x, y, z) / 2))
				if point.Z <= 0 then
					return nil
				end
				minimum = Vector2.new(math.min(minimum.X, point.X), math.min(minimum.Y, point.Y))
				maximum = Vector2.new(math.max(maximum.X, point.X), math.max(maximum.Y, point.Y))
			end
		end
	end
	return Rect.new(minimum, maximum)
end

local function nametagBounds(children, positions, origin, size)
	local minimum, maximum = Vector2.one * math.huge, Vector2.one * -math.huge
	for _, child in children do
		if child.Visible then
			local position = positions[child.Name]
			local topLeft = origin
				+ Vector2.new(
					position.X.Scale * size.X + position.X.Offset,
					position.Y.Scale * size.Y + position.Y.Offset
				)
				- child.AbsoluteSize * child.AnchorPoint
			local bottomRight = topLeft + child.AbsoluteSize
			if child.Name == "Username" then
				-- The sticker is the label's whole box plus its outline and tilt, not just the glyphs:
				-- measuring only the text let the sticker poke past the stage window edge and be cropped.
				local tilt = math.abs(math.sin(math.rad(child.Rotation)))
				local labelSize = child.AbsoluteSize
				local grow = Vector2.new(
					T.Shape.StrokeCard + tilt * labelSize.Y / 2,
					T.Shape.StrokeCard + tilt * labelSize.X / 2
				)
				topLeft -= grow
				bottomRight += grow
			end
			minimum = Vector2.new(math.min(minimum.X, topLeft.X), math.min(minimum.Y, topLeft.Y))
			maximum = Vector2.new(math.max(maximum.X, bottomRight.X), math.max(maximum.Y, bottomRight.Y))
		end
	end
	return if minimum.X < math.huge then Rect.new(minimum, maximum) else nil
end

local function nameOffset(bounds, occupied, safe, gap)
	local left, top, right, bottom = bounds.Min.X, bounds.Min.Y, bounds.Max.X, bounds.Max.Y
	local lowX, highX = safe.Min.X - left, safe.Max.X - right
	local lowY, highY = safe.Min.Y - top, safe.Max.Y - bottom
	local function clampX(x)
		return if lowX <= highX then math.clamp(x, lowX, highX) else (lowX + highX) / 2
	end
	local function clampY(y)
		return if lowY <= highY then math.clamp(y, lowY, highY) else (lowY + highY) / 2
	end
	local function append(values, seen, value)
		if not seen[value] then
			seen[value] = true
			table.insert(values, value)
		end
	end
	local xs, ys, seenX, seenY, obstacles = {}, {}, {}, {}, {}
	for _, x in { clampX(0), clampX(lowX), clampX(highX) } do
		append(xs, seenX, x)
	end
	for _, y in { clampY(0), clampY(lowY), clampY(highY) } do
		append(ys, seenY, y)
	end
	for _, other in occupied do
		local obstacle = { left = other.Min.X, top = other.Min.Y, right = other.Max.X, bottom = other.Max.Y }
		table.insert(obstacles, obstacle)
		append(xs, seenX, clampX(obstacle.left - gap - right))
		append(xs, seenX, clampX(obstacle.right + gap - left))
		append(ys, seenY, clampY(obstacle.top - gap - bottom))
		append(ys, seenY, clampY(obstacle.bottom + gap - top))
	end
	local bestX, bestY = xs[1], ys[1]
	local bestOverlap, bestDistance = math.huge, math.huge
	for _, x in xs do
		for _, y in ys do
			local distance = x * x + y * y
			if bestOverlap == 0 and distance > bestDistance then
				continue
			end
			local overlap = 0
			for _, other in obstacles do
				local width = math.min(right + x, other.right) + gap - math.max(left + x, other.left)
				local height = math.min(bottom + y, other.bottom) + gap - math.max(top + y, other.top)
				overlap += math.max(0, width) * math.max(0, height)
				if overlap > bestOverlap then
					break
				end
			end
			if
				overlap < bestOverlap
				or (
					overlap == bestOverlap
					and (
						distance < bestDistance
						or (distance == bestDistance and (y < bestY or (y == bestY and x < bestX)))
					)
				)
			then
				bestX, bestY = x, y
				bestOverlap, bestDistance = overlap, distance
				if overlap == 0 and x == xs[1] and y == ys[1] then
					return Vector2.new(x, y)
				end
			end
		end
	end
	return Vector2.new(bestX, bestY)
end

function PartyCharacterRenderer:_layoutNametags()
	local camera = Workspace.CurrentCamera
	if not camera or camera.ViewportSize.X <= 1 or camera.ViewportSize.Y <= 1 then
		return
	end
	local config = UIConfig.Layout.PartyNametags
	local insets = GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
	local viewportOrigin = GuiService:GetInsetArea(Enum.ScreenInsets.None).Min
	local padding = Vector2.one * config.ViewportPaddingPx
	if insets.Max.X - insets.Min.X <= padding.X * 2 or insets.Max.Y - insets.Min.Y <= padding.Y * 2 then
		return
	end
	local safe = Rect.new(insets.Min - viewportOrigin + padding, insets.Max - viewportOrigin - padding)
	local world = if self._getWorldBounds then self._getWorldBounds() else nil
	if world then
		local minimum =
			Vector2.new(math.max(safe.Min.X, world.Min.X + padding.X), math.max(safe.Min.Y, world.Min.Y + padding.Y))
		local maximum =
			Vector2.new(math.min(safe.Max.X, world.Max.X - padding.X), math.min(safe.Max.Y, world.Max.Y - padding.Y))
		if minimum.X >= maximum.X or minimum.Y >= maximum.Y then
			return
		end
		safe = Rect.new(minimum, maximum)
	end
	local characters, occupied, bodies = {}, {}, {}
	for _, character in self._characters do
		table.insert(characters, character)
		-- No stage window (e.g. Settings) means nothing is framed for these names to sit over.
		self:_applyNametagVisibility(character, world ~= nil or not self._getWorldBounds)
	end
	table.sort(characters, function(a, b)
		return a.slot < b.slot
	end)
	for _, character in characters do
		if character.rig.Parent then
			local anchor = character.rig:GetPivot().Position + BUBBLE_ANCHOR_OFFSET
			local towardCamera = camera.CFrame.Position - anchor
			if towardCamera.Magnitude > BUBBLE_CAMERA_CLEARANCE then
				anchor += towardCamera.Unit * BUBBLE_CAMERA_CLEARANCE
			end
			character.bubbleAnchor.Position = anchor
			local body = character.bodyBounds
			local bounds = projectedBody(camera, character.rig:GetPivot() * body.frame, body.size)
			if bounds then
				bodies[character] = bounds
				table.insert(occupied, bounds)
			end
		end
	end
	for _, character in characters do
		if not character.nametag.Enabled or not character.nametag.Parent then
			continue
		end
		local children = { character.usernameLabel, character.crownLabel, character.kickButton }
		local origin, size, depth =
			projectedNametag(camera, character.nametag, self._spawns[character.slot], self._nametagStudsOffset)
		local positions = self._nametagPositions
		if character.kickButton.Visible then
			local name = nametagBounds({ character.usernameLabel }, positions, Vector2.zero, size)
			local kick = nametagBounds({ character.kickButton }, positions, Vector2.zero, size)
			if name and kick and kick.Max.Y + config.GapPx > name.Min.Y then
				positions = table.clone(positions)
				positions.KickButton += UDim2.fromOffset(0, math.floor(name.Min.Y - config.GapPx - kick.Max.Y))
			end
		end
		local offset = Vector2.zero
		local stagePoint = camera:WorldToViewportPoint(self._spawns[character.slot].Position)
		local inWindow = not world
			or (
				stagePoint.X >= world.Min.X
				and stagePoint.X <= world.Max.X
				and stagePoint.Y >= world.Min.Y
				and stagePoint.Y <= world.Max.Y
			)
		if inWindow and depth > 0 and size.X > 1 and size.Y > 1 then
			local bounds = nametagBounds(children, positions, origin, size)
			if bounds then
				local body = bodies[character]
				local preferred = if body
					then Vector2.new(
						(body.Min.X + body.Max.X - bounds.Min.X - bounds.Max.X) / 2,
						body.Min.Y - config.GapPx - 1 - bounds.Max.Y
					)
					else Vector2.zero
				local anchoredBounds = Rect.new(bounds.Min + preferred, bounds.Max + preferred)
				-- Keep names above their owner when viewport headroom is constrained.
				-- Only other characters and nameplates should push them sideways.
				local obstacles = {}
				for _, obstacle in occupied do
					if obstacle ~= body then
						table.insert(obstacles, obstacle)
					end
				end
				offset = preferred + nameOffset(anchoredBounds, obstacles, safe, config.GapPx)
				table.insert(occupied, Rect.new(bounds.Min + offset, bounds.Max + offset))
			end
		end
		local studsPerPixel = 2
			* math.max(depth, 0)
			* math.tan(math.rad(camera.FieldOfView / 2))
			/ camera.ViewportSize.Y
		local studsOffset = self._nametagStudsOffset + Vector3.new(offset.X, -offset.Y, 0) * studsPerPixel
		if character.nametag.StudsOffset ~= studsOffset then
			character.nametag.StudsOffset = studsOffset
		end
		for _, child in children do
			local position = positions[child.Name]
			if child == character.crownLabel and self._backpackActive and not GuiService.ReducedMotionEnabled then
				position += UDim2.fromOffset(
					0,
					math.sin(os.clock() * math.pi * 2 / T.Motion.CrownPeriod) * T.Motion.CrownAmplitude
				)
			end
			if child.Position ~= position then
				child.Position = position
			end
		end
	end
end

function PartyCharacterRenderer:GetUsername(userId)
	return self._usernames[userId]
end

function PartyCharacterRenderer:SubscribeUsernames(listener)
	if self._destroyed then
		return function() end
	end
	local token = {}
	self._usernameListeners[token] = listener
	return function()
		self._usernameListeners[token] = nil
	end
end

function PartyCharacterRenderer:_applyNametagVisibility(character, stageAvailable)
	local show = character.nametagWanted == true and stageAvailable
	if character.nametag.Enabled ~= show then
		character.nametag.Enabled = show
	end
end

function PartyCharacterRenderer:_updateNametagPresentation()
	local stageAvailable = not self._getWorldBounds or self._getWorldBounds() ~= nil
	local localCharacter = self._characters[self._localUserId]
	local localLeader = localCharacter and localCharacter.crownLabel.Visible
	for _, character in self._characters do
		local visible =
			PartyVisibilityPolicy.shouldShowCharacter(character.userId, self._localUserId, self._backpackActive)
		local parent = if visible then self._characterContainer else nil
		if character.rig.Parent ~= parent then
			character.rig.Parent = parent
		end
		if character.bubbleAnchor.Parent ~= parent then
			character.bubbleAnchor.Parent = parent
		end
		local canKick = not self._compactParty and localLeader and not character.crownLabel.Visible
		-- Compact layouts show names and leadership in the party modal at readable sizes.
		character.nametagWanted = not self._compactParty and visible
		self:_applyNametagVisibility(character, stageAvailable)
		character.usernameLabel.Visible = not self._compactParty
		character.kickButton.Visible = canKick == true
		character.kickButton.Active = canKick == true
		character.kickButton.Selectable = canKick == true
		character.nametag.Active = canKick == true
	end
end

function PartyCharacterRenderer:SetCompactParty(compact)
	if self._destroyed or self._compactParty == (compact == true) then
		return
	end
	self._compactParty = compact == true
	self:_updateNametagPresentation()
end

local function configureHeldVisual(visual)
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanQuery = false
	visual.CanTouch = false
	visual.Massless = true
end

local function attachmentCFrame(part, name)
	local attachment = part:FindFirstChild(name)
	return if attachment and attachment:IsA("Attachment") then part.CFrame * attachment.CFrame else nil
end

local function hammerGripCFrame(hammer)
	local attachment = hammer:FindFirstChild("GripAttachment")
	if attachment then
		assert(attachment:IsA("Attachment"), "[PartyCharacterRenderer] Hammer GripAttachment must be an Attachment")
		return attachment.CFrame
	end
	local config = Combat.Hammer.AutoGrip
	local solution = HammerGrip.solve(
		hammer.Size.X,
		hammer.Size.Y,
		hammer.Size.Z,
		config.MinAxisDominanceRatio,
		InventoryConfig.WorldPreview.HammerGripAlongLongAxis
	)
	assert(solution ~= nil, "[PartyCharacterRenderer] ambiguous hammer requires GripAttachment")
	return CFrame.new(solution.position.x, solution.position.y, solution.position.z)
		* CFrame.Angles(
			math.rad(solution.rotationDeg.x),
			math.rad(solution.rotationDeg.y),
			math.rad(solution.rotationDeg.z)
		)
end

local function effectiveItemId(category, itemId)
	if typeof(itemId) == "string" and CosmeticVisualFactory.definition(category, itemId) ~= nil then
		return itemId
	end
	return ""
end

function PartyCharacterRenderer:_destroySkinsPreview()
	local preview = self._skinsPreview
	if not preview then
		return
	end
	preview.hammer:Destroy()
	preview.ball:Destroy()
	self._skinsPreview = nil
end

function PartyCharacterRenderer:SetSkinsPreview(active, ballItemId, hammerItemId)
	if self._destroyed or not active then
		self:_destroySkinsPreview()
		return
	end
	local normalizedBallId = effectiveItemId("BallAssets", ballItemId)
	local normalizedHammerId = effectiveItemId("HammerAssets", hammerItemId)
	local preview = self._skinsPreview
	if preview and preview.ballItemId == normalizedBallId and preview.hammerItemId == normalizedHammerId then
		return
	end

	self:_destroySkinsPreview()
	local ball = CosmeticVisualFactory.create("BallAssets", normalizedBallId)
	local hammer = CosmeticVisualFactory.create("HammerAssets", normalizedHammerId)
	configureHeldVisual(ball)
	configureHeldVisual(hammer)
	ball.Name = "LobbySkinsDodgeball"
	hammer.Name = "LobbySkinsHammer"
	ball.Parent = self._characterContainer
	hammer.Parent = self._characterContainer
	self._skinsPreview = {
		ball = ball,
		ballSize = ball.Size,
		popAt = os.clock(),
		hammer = hammer,
		ballItemId = normalizedBallId,
		hammerItemId = normalizedHammerId,
		hammerGrip = hammerGripCFrame(hammer),
	}
	self:_updateSkinsPreview()
end

function PartyCharacterRenderer:_updateSkinsPreview()
	local preview = self._skinsPreview
	local character = self._characters[self._localUserId]
	if not preview or not character then
		return
	end
	local leftHand = character.leftHand
	local rightHand = character.rightHand

	local hammerHand = attachmentCFrame(leftHand, "LeftGripAttachment")
		or leftHand.CFrame
			* CFrame.new(
				Combat.Hammer.HandGripFallbackOffset.x,
				Combat.Hammer.HandGripFallbackOffset.y,
				Combat.Hammer.HandGripFallbackOffset.z
			)
	preview.hammer.CFrame = CFrame.new(hammerHand.Position)
		* character.rig:GetPivot().Rotation
		* preview.hammerGrip:Inverse()
	local age = os.clock() - preview.popAt
	local pop = if GuiService.ReducedMotionEnabled then 1 else math.min(age / T.Motion.Stamp, 1)
	preview.ball.Size = preview.ballSize * (if pop < 1 then math.max(0.15, pop + math.sin(pop * math.pi) * 0.2) else 1)
	local ballOffset = Combat.Dodgeball.HeldVisualHandOffset
	preview.ball.CFrame = attachmentCFrame(rightHand, "DodgeballGrip")
		or rightHand.CFrame * CFrame.new(ballOffset.x, ballOffset.y, ballOffset.z)
end

function PartyCharacterRenderer:_faceLocalCharacterToCamera()
	local character = self._characters[self._localUserId]
	local camera = Workspace.CurrentCamera
	if not character or character.slot ~= 1 or not character.rig.Parent or not camera then
		return
	end

	local spawnPosition = self._spawns[1].Position
	local cameraPosition = camera.CFrame.Position
	local direction = Vector3.new(cameraPosition.X - spawnPosition.X, 0, cameraPosition.Z - spawnPosition.Z)
	if direction.Magnitude <= 0.001 then
		return
	end

	local elapsed = os.clock() - self._celebrateAt
	local hop = if self._backpackActive
			and not GuiService.ReducedMotionEnabled
			and elapsed < T.Stage.HopDuration
		then math.sin(math.pi * elapsed / T.Stage.HopDuration) * T.Stage.Hop
		else 0
	character.rig:PivotTo(
		CFrame.new(0, hop, 0)
			* CFrame.lookAt(spawnPosition, spawnPosition + direction, Vector3.yAxis)
			* CFrame.Angles(0, if self._backpackActive then self._previewAngle else 0, 0)
	)
end

function PartyCharacterRenderer:_requestUsername(userId)
	if self._destroyed or self._usernames[userId] or self._usernameRequests[userId] then
		return
	end

	self._usernameRequests[userId] = true
	local generation = self._generation
	task.spawn(function()
		local username
		for attempt = 1, USERNAME_LOOKUP_ATTEMPTS do
			local success, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
			if success then
				username = result
				break
			end
			if attempt < USERNAME_LOOKUP_ATTEMPTS then
				task.wait(USERNAME_RETRY_DELAY)
			end
		end

		if self._destroyed or generation ~= self._generation then
			return
		end
		self._usernameRequests[userId] = nil
		if not username then
			warn(("[PartyCharacterRenderer] Could not load username for %d"):format(userId))
			-- Keep trying while the member is still in the party: a throttled
			-- lookup must not leave the nametag on "..." and the party modal's
			-- REMOVE disabled for the rest of their stay.
			task.delay(USERNAME_RECOVERY_DELAY, function()
				if not self._destroyed and generation == self._generation and self._characters[userId] then
					self:_requestUsername(userId)
				end
			end)
			return
		end

		self._usernames[userId] = username
		local character = self._characters[userId]
		if character then
			character.usernameLabel.Text = username
		end
		for _, listener in self._usernameListeners do
			local ok, message = pcall(listener, userId, username)
			if not ok then
				warn("[PartyCharacterRenderer] Username listener failed:", message)
			end
		end
	end)
end

function PartyCharacterRenderer:PlayEmote(userId, emoteId)
	local character = self._characters[userId]
	if character == nil then
		return
	end
	EmotePlayer.stop(character.emoteTrack)
	character.emoteTrack = EmotePlayer.play(character.animator, emoteId)
end

function PartyCharacterRenderer:_remove(userId)
	local character = self._characters[userId]
	if not character then
		return
	end

	self._characters[userId] = nil
	character.idleTrack:Stop(0)
	character.idleTrack:Destroy()
	character.nametag:Destroy()
	character.bubbleAnchor:Destroy()
	character.appearance.destroy()
	character.rig:Destroy()
end

function PartyCharacterRenderer:_spawn(userId, slot, characterColorId, costumeId)
	local rig = self._characterTemplate:Clone()
	rig.Name = ("PartyCharacter_%d"):format(userId)
	rig:SetAttribute("UserId", userId)
	rig:SetAttribute("PartySlot", slot)

	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end

	local humanoid = rig:WaitForChild("Humanoid")
	local rootPart = rig:WaitForChild("HumanoidRootPart")
	local leftHand = rig:WaitForChild("LeftHand")
	local rightHand = rig:WaitForChild("RightHand")
	local animator = humanoid:WaitForChild("Animator")
	assert(leftHand:IsA("BasePart"), "[PartyCharacterRenderer] CharacterRig.LeftHand must be a BasePart")
	assert(rightHand:IsA("BasePart"), "[PartyCharacterRenderer] CharacterRig.RightHand must be a BasePart")
	local spawn = self._spawns[slot]
	local nametag = self._nametagTemplate:Clone()
	-- A stationary anchor keeps chat out of the animated head and crown.
	local bubbleAnchor = Instance.new("Part")
	bubbleAnchor.Name = ("PartyBubbleAnchor_%d"):format(userId)
	bubbleAnchor.Size = Vector3.one * 0.1
	bubbleAnchor.Transparency = 1
	bubbleAnchor.Anchored = true
	bubbleAnchor.CanCollide = false
	bubbleAnchor.CanQuery = false
	bubbleAnchor.CanTouch = false
	bubbleAnchor.CFrame = spawn.CFrame * CFrame.new(BUBBLE_ANCHOR_OFFSET)
	bubbleAnchor.Parent = self._characterContainer
	local usernameLabel = nametag:WaitForChild("Username")
	local crownLabel = nametag:WaitForChild("Crown")
	local kickButton = nametag:WaitForChild("KickButton")
	humanoid.AutoRotate = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rootPart.Anchored = true
	nametag.Active = false
	nametag.ResetOnSpawn = false
	-- A held hammer or an animated limb must never hide the name behind it.
	nametag.AlwaysOnTop = true
	nametag.Adornee = spawn
	nametag.Parent = self._playerGui
	usernameLabel.Active = false
	usernameLabel.Selectable = false
	usernameLabel.Text = self._usernames[userId] or "..."
	usernameLabel.TextScaled = false
	usernameLabel.TextWrapped = false
	usernameLabel.Font = T.Type.Display
	usernameLabel.TextSize = T.Type.TileLabel
	usernameLabel.TextColor3 = T.Colors.Surface
	usernameLabel.BackgroundColor3 = T.Colors.Ink
	usernameLabel.BackgroundTransparency = 0
	usernameLabel.Rotation = -T.Shape.TiltTab
	usernameLabel.Size = UDim2.new(1, 20, 0, 40)
	local pill = Instance.new("UICorner")
	pill.CornerRadius = UDim.new(1, 0)
	pill.Parent = usernameLabel
	local outline = Instance.new("UIStroke")
	outline.Name = "CandyStickerOutline"
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = T.Colors.Surface
	outline.Thickness = T.Shape.StrokeCard
	outline.Parent = usernameLabel
	crownLabel.Active = false
	crownLabel.Selectable = false
	crownLabel.Visible = false
	configureKickButton(kickButton)
	kickButton.Active = false
	kickButton.Selectable = false
	kickButton.Visible = false
	kickButton.MouseButton1Click:Connect(function()
		if kickButton.Active and kickButton.Visible then
			self._onKick(userId, self._usernames[userId] or ("USER %d"):format(userId))
		end
	end)

	rig.Parent = self._characterContainer
	rig:PivotTo(spawn.CFrame)

	local idleTrack = animator:LoadAnimation(self._idleAnimation)
	idleTrack.Looped = true
	idleTrack.Priority = Enum.AnimationPriority.Idle
	idleTrack:Play(0, 1, IDLE_PLAYBACK_SPEED)

	self._characters[userId] = {
		userId = userId,
		rig = rig,
		appearance = CharacterAppearance.create(
			rig,
			{ characterColorId = characterColorId, costumeId = costumeId },
			{ live = true }
		),
		animator = animator,
		idleTrack = idleTrack,
		emoteTrack = nil :: AnimationTrack?,
		nametag = nametag,
		nametagWanted = false,
		bubbleAnchor = bubbleAnchor,
		usernameLabel = usernameLabel,
		crownLabel = crownLabel,
		kickButton = kickButton,
		leftHand = leftHand,
		rightHand = rightHand,
		slot = slot,
		bodyBounds = self:_bodyBounds(costumeId),
	}
	self:_requestUsername(userId)
end

function PartyCharacterRenderer:_move(character, slot)
	local spawn = self._spawns[slot]
	character.slot = slot
	character.rig:SetAttribute("PartySlot", slot)
	character.rig:PivotTo(spawn.CFrame)
	character.nametag.Adornee = spawn
	character.nametag.Parent = self._playerGui

	if not character.idleTrack.IsPlaying then
		character.idleTrack:Play(0, 1, IDLE_PLAYBACK_SPEED)
	end
end

function PartyCharacterRenderer:Render(snapshot)
	if self._destroyed then
		return
	end
	self._appearanceRevision += 1
	local revision = self._appearanceRevision
	local orderedUserIds = { self._localUserId }
	local includedUserIds = {
		[self._localUserId] = true,
	}
	local appearances = {}

	for _, member in snapshot.members do
		appearances[member.userId] = member
		if #orderedUserIds >= Config.PartyMaxPlayers then
			break
		end
		if not includedUserIds[member.userId] then
			includedUserIds[member.userId] = true
			table.insert(orderedUserIds, member.userId)
		end
	end

	for _, userId in orderedUserIds do
		CharacterAppearance.prepare(appearances[userId] or {})
	end
	if self._destroyed or self._appearanceRevision ~= revision then
		return
	end

	local removals = {}
	for userId in self._characters do
		if not includedUserIds[userId] then
			table.insert(removals, userId)
		end
	end
	for _, userId in removals do
		self:_remove(userId)
	end

	for slot, userId in orderedUserIds do
		local appearance = appearances[userId] or {}
		local characterColorId, costumeId = appearance.characterColorId, appearance.costumeId
		local character = self._characters[userId]
		if character then
			self:_move(character, slot)
			character.appearance.update({ characterColorId = characterColorId, costumeId = costumeId })
			character.bodyBounds = self:_bodyBounds(costumeId)
		else
			self:_spawn(userId, slot, characterColorId, costumeId)
			character = self._characters[userId]
		end
		character.crownLabel.Visible = userId == snapshot.leaderUserId
	end
	self:_updateNametagPresentation()
end

function PartyCharacterRenderer:SetBackpackActive(value)
	self._backpackActive = value
	self._candyStage.setEnabled(value)
	self:_updateNametagPresentation()
	local background = Workspace.Views.Party.Background
	background:SetAttribute("CandyBackpackActive", value)
end

function PartyCharacterRenderer:destroy()
	self._candyStage.destroy()
	self._disconnectCelebrate()
	self._dragBegin:Disconnect()
	self._dragMove:Disconnect()
	self._dragEnd:Disconnect()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:_destroySkinsPreview()
	self._generation += 1
	if self._bubbleConnection then
		self._bubbleConnection:Disconnect()
		self._bubbleConnection = nil
	end
	if self._renderConnection then
		self._renderConnection:Disconnect()
		self._renderConnection = nil
	end
	local removals = {}
	for userId in self._characters do
		table.insert(removals, userId)
	end
	for _, userId in removals do
		self:_remove(userId)
	end
	table.clear(self._usernameRequests)
	table.clear(self._usernameListeners)
end

return PartyCharacterRenderer
