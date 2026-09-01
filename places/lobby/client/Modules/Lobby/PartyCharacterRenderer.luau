-- Name: PartyCharacterRenderer.luau
-- Author: Jack C.
-- Description: Renders the lobby party members as posed character models, applying each member's equipped cosmetics and character color, and drives the inventory skin preview.
-- Created: 2026-08-15

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local CharacterColorLogic = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Economy")
		:WaitForChild("CharacterColorLogic")
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

function PartyCharacterRenderer.new(localUserId, onKick)
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local partyView = Workspace:WaitForChild("Views"):WaitForChild("Party")
	local characterContainer = partyView:WaitForChild("Players")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local spawns = {}

	for index = 1, Config.PartyMaxPlayers do
		spawns[index] = characterContainer:WaitForChild(("Player%d"):format(index))
	end

	local self = setmetatable({
		_localUserId = localUserId,
		_characterTemplate = assets:WaitForChild("Rigs"):WaitForChild("CharacterRig"),
		_idleAnimation = assets:WaitForChild("Animations"):WaitForChild("Idle"),
		_nametagTemplate = assets:WaitForChild("UI"):WaitForChild("Nametag"),
		_characterContainer = characterContainer,
		_playerGui = playerGui,
		_spawns = spawns,
		_characters = {},
		_onKick = onKick,
		_usernames = {
			[localUserId] = Players.LocalPlayer.Name,
		},
		_usernameRequests = {},
		_skinsPreview = nil,
		_destroyed = false,
		_generation = 0,
	}, PartyCharacterRenderer)

	self:Render({ members = {} })
	self:_faceLocalCharacterToCamera()
	self._renderConnection = RunService.RenderStepped:Connect(function()
		self:_faceLocalCharacterToCamera()
		self:_updateSkinsPreview()
	end)
	return self
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
		config.GripAlongLongAxis
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
	preview.hammer.CFrame = hammerHand * preview.hammerGrip:Inverse()
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
	character.rig:Destroy()
end

function PartyCharacterRenderer:_spawn(userId, slot, characterColorId)
	local rig = self._characterTemplate:Clone()
	rig.Name = ("PartyCharacter_%d"):format(userId)
	rig:SetAttribute("UserId", userId)
	rig:SetAttribute("PartySlot", slot)

	local color = CharacterColorLogic.resolve(Cosmetics, characterColorId)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
		if descendant:IsA("MeshPart") then
			descendant.Color = color
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
		idleTrack = idleTrack,
		nametag = nametag,
		usernameLabel = usernameLabel,
		crownLabel = crownLabel,
		kickButton = kickButton,
		leftHand = leftHand,
		rightHand = rightHand,
		slot = slot,
		characterColorId = characterColorId or "",
	}
	self:_requestUsername(userId)
end

function PartyCharacterRenderer:_setCharacterColor(character, characterColorId)
	local normalizedId = characterColorId or ""
	if character.characterColorId == normalizedId then
		return
	end
	character.characterColorId = normalizedId
	local color = CharacterColorLogic.resolve(Cosmetics, normalizedId)
	for _, descendant in character.rig:GetDescendants() do
		if descendant:IsA("MeshPart") then
			descendant.Color = color
		end
	end
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
	local isLocalLeader = snapshot.leaderUserId == self._localUserId
	local orderedUserIds = { self._localUserId }
	local includedUserIds = {
		[self._localUserId] = true,
	}
	local characterColors = {}

	for _, member in snapshot.members do
		characterColors[member.userId] = member.characterColorId
		if #orderedUserIds >= Config.PartyMaxPlayers then
			break
		end
		if not includedUserIds[member.userId] then
			includedUserIds[member.userId] = true
			table.insert(orderedUserIds, member.userId)
		end
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
		local characterColorId = characterColors[userId]
		local character = self._characters[userId]
		if character then
			self:_move(character, slot)
			self:_setCharacterColor(character, characterColorId)
		else
			self:_spawn(userId, slot, characterColorId)
			character = self._characters[userId]
		end
		local canKick = isLocalLeader and userId ~= snapshot.leaderUserId
		character.crownLabel.Visible = userId == snapshot.leaderUserId
		character.kickButton.Visible = canKick
		character.kickButton.Active = canKick
		character.kickButton.Selectable = canKick
		character.nametag.Active = canKick
	end
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
end

return PartyCharacterRenderer
