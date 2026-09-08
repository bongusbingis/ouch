-- Description: Renders the lobby party members as posed character models, applying each member's equipped cosmetics and character color, and drives the inventory skin preview.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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

local USERNAME_LOOKUP_ATTEMPTS = 3
local USERNAME_RETRY_DELAY = 1
local IDLE_PLAYBACK_SPEED = 0.85

local PartyCharacterRenderer = {}
PartyCharacterRenderer.__index = PartyCharacterRenderer

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
		_onKick = onKick,
		_compactParty = false,
		_usernames = {
			[localUserId] = Players.LocalPlayer.Name,
		},
		_usernameRequests = {},
		_usernameListeners = {},
		_skinsPreview = nil,
		_destroyed = false,
		_generation = 0,
		_appearanceRevision = 0,
	}, PartyCharacterRenderer)

	self:Render({ members = {} })
	self:_faceLocalCharacterToCamera()
	self._renderConnection = RunService.RenderStepped:Connect(function()
		self:_faceLocalCharacterToCamera()
		self:_updateSkinsPreview()
		self:_layoutNametags()
	end)
	return self
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
				local alignment = Vector2.new(
					if child.TextXAlignment == Enum.TextXAlignment.Center
						then 0.5
						elseif child.TextXAlignment == Enum.TextXAlignment.Right then 1
						else 0,
					if child.TextYAlignment == Enum.TextYAlignment.Center
						then 0.5
						elseif child.TextYAlignment == Enum.TextYAlignment.Bottom then 1
						else 0
				)
				topLeft += (child.AbsoluteSize - child.TextBounds) * alignment
				bottomRight = topLeft + child.TextBounds + Vector2.one
				topLeft -= Vector2.one
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
	end
	table.sort(characters, function(a, b)
		return a.slot < b.slot
	end)
	local envelope = UIConfig.Layout.WorldFraming.CharacterBody
	local bodyFrame = CFrame.new((envelope.Minimum + envelope.Maximum) / 2)
	local bodySize = envelope.Maximum - envelope.Minimum
	for _, character in characters do
		if character.rig.Parent then
			local bounds = projectedBody(camera, character.rig:GetPivot() * bodyFrame, bodySize)
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
		if self._compactParty and not character.crownLabel.Visible then
			character.nametag.StudsOffset = self._nametagStudsOffset
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
				local placement = safe
				local body = bodies[character]
				if self._compactParty and body then
					local crownBottom = math.min(safe.Max.Y, body.Min.Y - config.GapPx)
					if crownBottom - safe.Min.Y >= bounds.Max.Y - bounds.Min.Y then
						placement = Rect.new(safe.Min, Vector2.new(safe.Max.X, crownBottom))
					end
				end
				offset = nameOffset(bounds, occupied, placement, config.GapPx)
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

function PartyCharacterRenderer:_updateNametagPresentation()
	local localCharacter = self._characters[self._localUserId]
	local localLeader = localCharacter and localCharacter.crownLabel.Visible
	for _, character in self._characters do
		local canKick = not self._compactParty and localLeader and not character.crownLabel.Visible
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

	character.rig:PivotTo(CFrame.lookAt(spawnPosition, spawnPosition + direction, Vector3.yAxis))
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

function PartyCharacterRenderer:_remove(userId)
	local character = self._characters[userId]
	if not character then
		return
	end

	self._characters[userId] = nil
	character.idleTrack:Stop(0)
	character.idleTrack:Destroy()
	character.nametag:Destroy()
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
	local usernameLabel = nametag:WaitForChild("Username")
	local crownLabel = nametag:WaitForChild("Crown")
	local kickButton = nametag:WaitForChild("KickButton")
	humanoid.AutoRotate = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rootPart.Anchored = true
	nametag.Active = false
	nametag.Adornee = spawn
	nametag.Parent = self._playerGui
	usernameLabel.Active = false
	usernameLabel.Selectable = false
	usernameLabel.Text = self._usernames[userId] or "..."
	usernameLabel.TextScaled = false
	usernameLabel.TextWrapped = false
	crownLabel.Active = false
	crownLabel.Selectable = false
	crownLabel.Visible = false
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
		rig = rig,
		appearance = CharacterAppearance.create(
			rig,
			{ characterColorId = characterColorId, costumeId = costumeId },
			{ live = true }
		),
		idleTrack = idleTrack,
		nametag = nametag,
		usernameLabel = usernameLabel,
		crownLabel = crownLabel,
		kickButton = kickButton,
		leftHand = leftHand,
		rightHand = rightHand,
		slot = slot,
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
		else
			self:_spawn(userId, slot, characterColorId, costumeId)
			character = self._characters[userId]
		end
		character.crownLabel.Visible = userId == snapshot.leaderUserId
	end
	self:_updateNametagPresentation()
end

function PartyCharacterRenderer:destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:_destroySkinsPreview()
	self._generation += 1
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
