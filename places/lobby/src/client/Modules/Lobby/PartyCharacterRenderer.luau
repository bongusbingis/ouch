local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))

local USERNAME_LOOKUP_ATTEMPTS = 3
local USERNAME_RETRY_DELAY = 1

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
	}, PartyCharacterRenderer)

	self:Render({ members = {} })
	self:_faceLocalCharacterToCamera()
	self._renderConnection = RunService.RenderStepped:Connect(function()
		self:_faceLocalCharacterToCamera()
	end)
	return self
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
	if self._usernames[userId] or self._usernameRequests[userId] then
		return
	end

	self._usernameRequests[userId] = true
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

function PartyCharacterRenderer:_spawn(userId, slot)
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
	local animator = humanoid:WaitForChild("Animator")
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
	idleTrack:Play(0)

	self._characters[userId] = {
		rig = rig,
		idleTrack = idleTrack,
		nametag = nametag,
		usernameLabel = usernameLabel,
		crownLabel = crownLabel,
		kickButton = kickButton,
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
		character.idleTrack:Play(0)
	end
end

function PartyCharacterRenderer:Render(snapshot)
	local isLocalLeader = snapshot.leaderUserId == self._localUserId
	local orderedUserIds = { self._localUserId }
	local includedUserIds = {
		[self._localUserId] = true,
	}

	for _, member in snapshot.members do
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
		local character = self._characters[userId]
		if character then
			self:_move(character, slot)
		else
			self:_spawn(userId, slot)
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

return PartyCharacterRenderer
