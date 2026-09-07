--!strict

-- Owns one local audition scene and its camera, input, sound and effect lifetime.
-- Session ids make asynchronous setup and stale UI cleanup harmless.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Cosmetics = require(Config.Cosmetics.Cosmetics)
local EffectConfig = require(Config.Cosmetics.CosmeticEffects)
local PreviewConfig = require(Config.Cosmetics.CosmeticPreview)
local Audio = require(Config.Infra.Audio)
local CosmeticGame = script.Parent.Parent.Parent.Game.Cosmetics
local EffectFactory = require(CosmeticGame.CosmeticEffectFactory)
local EliminationAudio = require(CosmeticGame.EliminationAudio)
local Runtime = require(CosmeticGame.Effects.Runtime)
local PresentationCamera = require(script.Parent.PresentationCamera)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local CosmeticPreviewClient = {}
local REASON = "CosmeticPreview"
local INPUT_ACTION = "CosmeticPreviewMovement"

export type Snapshot = {
	sessionId: number,
	itemId: string?,
	category: string?,
	active: boolean,
	ready: boolean,
	canReplay: boolean,
	error: string?,
	closeReason: string?,
	replayRevision: number,
}

type Session = {
	id: number,
	itemId: string?,
	category: string,
	scene: Model?,
	impact: BasePart?,
	cameraMarker: BasePart?,
	lease: PresentationCamera.Token?,
	scope: Runtime.Scope?,
	sound: Sound?,
	connections: { RBXScriptConnection },
	replayAt: number,
	playback: number,
	threads: { [thread]: boolean },
}

local snapshot: Snapshot = { sessionId = 0, active = false, ready = false, canReplay = false, replayRevision = 0 }
local active: Session? = nil
local nextSession = 0
local listeners: { [(Snapshot) -> ()]: boolean } = {}
local clientAudio: any = nil

local function spawn(session: Session, callback: () -> ())
	local worker = coroutine.create(function()
		callback()
		session.threads[coroutine.running()] = nil
	end)
	session.threads[worker] = true
	task.spawn(worker)
end

local function publish(changes: { [string]: any })
	local nextSnapshot = table.clone(snapshot)
	for key, value in changes do
		(nextSnapshot :: any)[key] = value
	end
	snapshot = nextSnapshot
	for listener in table.clone(listeners) do
		local ok, err = pcall(listener, snapshot)
		if not ok then
			warn(`[CosmeticPreviewClient] listener failed: {err}`)
		end
	end
end

local function stopPlayback(session: Session)
	if session.scope then
		Runtime.destroyScope(session.scope)
		session.scope = nil
	end
	if session.sound then
		clientAudio.stop(session.sound)
		session.sound = nil
	end
end

function CosmeticPreviewClient.close(sessionId: number?, reason: string?)
	local session = active
	if session == nil or (sessionId ~= nil and session.id ~= sessionId) then
		return
	end
	active = nil
	for worker in session.threads do
		if worker ~= coroutine.running() and coroutine.status(worker) ~= "dead" then
			task.cancel(worker)
		end
	end
	table.clear(session.threads)
	for _, connection in session.connections do
		connection:Disconnect()
	end
	stopPlayback(session)
	if session.lease then
		PresentationCamera.release(session.lease)
	end
	if session.scene then
		session.scene:Destroy()
	end
	ContextActionService:UnbindAction(INPUT_ACTION)
	Combat.releaseMovementSuppression(REASON)
	Combat.releaseCursor(REASON)
	publish({ active = false, ready = false, canReplay = false, closeReason = reason or "closed" })
end

function CosmeticPreviewClient.canPreview(itemId: string?, category: string?): boolean
	local item = if itemId then Cosmetics.Items[itemId] else nil
	if itemId and item == nil then
		return false
	end
	local slot = if item then item.Category else category
	if slot == "ElimEffectAssets" then
		return true
	end
	for _, definition in EffectConfig.Categories do
		if definition.Slot == slot then
			return true
		end
	end
	return false
end

local function audioPlayer()
	if clientAudio == nil then
		clientAudio = require(
			Players.LocalPlayer
				:WaitForChild("PlayerScripts")
				:WaitForChild("Client")
				:WaitForChild("Modules")
				:WaitForChild("Presentation")
				:WaitForChild("ClientAudio")
		)
	end
	return clientAudio
end

local function play(session: Session, playback: number)
	local scene, impact, marker = session.scene, session.impact, session.cameraMarker
	if scene == nil or impact == nil or marker == nil then
		return
	end
	stopPlayback(session)
	if session.category == "ElimEffectAssets" then
		local audio = audioPlayer()
		if active ~= session or playback ~= session.playback then
			return
		end
		local effect = EliminationAudio.effectFor(Cosmetics, session.itemId)
		local sound = Audio.Gameplay[effect.DodgeballSound]
		assert(sound and #sound.AssetIds > 0, "[CosmeticPreviewClient] elimination sound must have audio assets")
		session.sound = audio.play({
			name = "CosmeticAudition",
			assetId = sound.AssetIds[1],
			category = "Effects",
			volume = sound.Volume,
			maxLifetimeSeconds = PreviewConfig.SoundLifetimeSeconds,
		})
	else
		local scope = Runtime.createScope(scene, function()
			return marker.CFrame
		end)
		session.scope = scope
		for categoryId, definition in EffectConfig.Categories do
			if definition.Slot == session.category then
				local succeeded, err = EffectFactory.play(
					categoryId,
					EffectFactory.effectIdForItem(Cosmetics.Items, session.category, session.itemId),
					{
						position = impact.Position,
						direction = impact.CFrame.LookVector,
						scope = scope,
					}
				)
				assert(succeeded, err or "[CosmeticPreviewClient] requested effect failed")
				break
			end
		end
	end
	if active == session and playback == session.playback then
		publish({ replayRevision = snapshot.replayRevision + 1, error = "" })
	end
end

function CosmeticPreviewClient.replay()
	local session = active
	if session == nil or not snapshot.ready or os.clock() < session.replayAt then
		return
	end
	session.replayAt = os.clock() + PreviewConfig.ReplayCooldownSeconds
	session.playback += 1
	local playback = session.playback
	publish({ canReplay = false })
	spawn(session, function()
		task.wait(PreviewConfig.ReplayCooldownSeconds)
		if active == session and playback == session.playback then
			publish({ canReplay = true })
		end
	end)
	spawn(session, function()
		if active ~= session or playback ~= session.playback then
			return
		end
		local ok, err = pcall(play, session, playback)
		if not ok and active == session and playback == session.playback then
			warn(`[CosmeticPreviewClient] playback failed: {err}`)
			stopPlayback(session)
			publish({ error = "This preview could not play. Please try again." })
		end
	end)
end

local function marker(scene: Model, name: string): BasePart
	local part = scene:WaitForChild(name)
	assert(part:IsA("BasePart"), `[CosmeticPreviewClient] PreviewScene.{name} must be a BasePart`)
	return part
end

local function prepare(session: Session)
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Cosmetics"):WaitForChild("PreviewScene")
	assert(template:IsA("Model"), "[CosmeticPreviewClient] Assets.Cosmetics.PreviewScene must be a Model")
	if active ~= session then
		return
	end
	local scene = template:Clone()
	session.scene = scene
	local origin = marker(scene, "Origin")
	local cameraMarker = marker(scene, "CameraMarker")
	local impact = marker(scene, "ImpactMarker")
	if active ~= session then
		scene:Destroy()
		return
	end
	for _, descendant in scene:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	scene:PivotTo(PreviewConfig.WorldOrigin * origin.CFrame:ToObjectSpace(scene:GetPivot()))
	scene.Name = "CosmeticPreviewScene"
	scene.Parent = Workspace
	session.impact = impact
	session.cameraMarker = cameraMarker
	local lease = PresentationCamera.acquire(REASON, PresentationCamera.Priority.Preview, function(camera)
		local viewport = camera.ViewportSize
		local aspect = viewport.X / math.max(viewport.Y, 1)
		local distanceScale = math.max(1, 1 / math.max(aspect, 0.25))
		local offset = cameraMarker.Position - impact.Position
		camera.CFrame = cameraMarker.CFrame.Rotation + impact.Position + offset * distanceScale
		camera.Focus = impact.CFrame
		camera.FieldOfView = PreviewConfig.FieldOfView
	end, function()
		CosmeticPreviewClient.close(session.id, "preempted")
	end)
	session.lease = lease
	if active ~= session or not PresentationCamera.isCurrent(lease) then
		PresentationCamera.release(lease)
		CosmeticPreviewClient.close(session.id, "preempted")
		return
	end
	publish({ ready = true, canReplay = true })
	if not GuiService.ReducedMotionEnabled and session.category ~= "ElimEffectAssets" then
		CosmeticPreviewClient.replay()
	end
end

function CosmeticPreviewClient.open(itemId: string?, category: string?): number
	CosmeticPreviewClient.close(nil, "replaced")
	nextSession += 1
	local item = if itemId then Cosmetics.Items[itemId] else nil
	local slot = if item then item.Category else category
	snapshot = {
		sessionId = nextSession,
		itemId = itemId,
		category = slot,
		active = true,
		ready = false,
		canReplay = false,
		replayRevision = 0,
	}
	local session: Session = {
		id = nextSession,
		itemId = itemId,
		category = slot or "",
		connections = {},
		replayAt = 0,
		playback = 0,
		threads = {},
	}
	active = session
	if not CosmeticPreviewClient.canPreview(itemId, category) then
		publish({ error = "This item has no effect preview." })
		return session.id
	end
	Combat.requestCursor(REASON)
	Combat.requestMovementSuppression(REASON)
	ContextActionService:BindActionAtPriority(
		INPUT_ACTION,
		function()
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 2,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump,
		Enum.KeyCode.Thumbstick1
	)
	local player = Players.LocalPlayer
	local character = player.Character
	if character then
		table.insert(
			session.connections,
			character:GetAttributeChangedSignal("CombatAlive"):Connect(function()
				if character:GetAttribute("CombatAlive") == false then
					CosmeticPreviewClient.close(session.id, "death")
				end
			end)
		)
	end
	table.insert(
		session.connections,
		player.CharacterAdded:Connect(function()
			CosmeticPreviewClient.close(session.id, "character_changed")
		end)
	)
	publish({})
	if character and character:GetAttribute("CombatAlive") == false then
		CosmeticPreviewClient.close(session.id, "death")
		return session.id
	end
	spawn(session, function()
		local ok, err = pcall(prepare, session)
		if not ok and active == session then
			warn(`[CosmeticPreviewClient] scene setup failed: {err}`)
			stopPlayback(session)
			publish({ error = "This preview could not load. Please return and try again." })
		end
	end)
	return session.id
end

function CosmeticPreviewClient.getSnapshot(): Snapshot
	return snapshot
end

function CosmeticPreviewClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	listeners[listener] = true
	return function()
		listeners[listener] = nil
	end
end

return CosmeticPreviewClient
