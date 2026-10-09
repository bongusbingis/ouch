-- Description: Controls the lobby background scene camera and its transitions while the party and matchmaking UI is shown. Sole owner of the backdrop's placement and visibility, so anything that needs the lobby view out of the way -- onboarding, for one -- switches it off here rather than moving the part itself.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PresentationCamera = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Services")
		:WaitForChild("PresentationCamera")
)

local UIConfig = require(ReplicatedStorage.Config.Interface.UI)
local CandyBackdrop = require(script.Parent.CandyBackdrop)

local PartyBackgroundController = {}
PartyBackgroundController.__index = PartyBackgroundController

local CAMERA_DISTANCE = 150
local LOOP_DURATION = 25
local MAX_ROLL = math.rad(4)
local U_TRAVEL_IN_TILES = 0.3
local V_TRAVEL_IN_TILES = 0.2
local TAU = math.pi * 2

function PartyBackgroundController.start()
	local background = Workspace:WaitForChild("Views"):WaitForChild("Party"):WaitForChild("Background")
	assert(
		background:IsA("BasePart"),
		"[PartyBackgroundController] Workspace.Views.Party.Background must be a BasePart"
	)

	local textures = {}
	for _, descendant in background:GetDescendants() do
		if descendant:IsA("Texture") then
			table.insert(textures, {
				instance = descendant,
				transparency = descendant.Transparency,
				mutedTransparency = 1 - (1 - descendant.Transparency) * UIConfig.Backdrop.PatternOpacityScale,
				offsetU = descendant.OffsetStudsU,
				offsetV = descendant.OffsetStudsV,
				travelU = descendant.StudsPerTileU * U_TRAVEL_IN_TILES,
				travelV = descendant.StudsPerTileV * V_TRAVEL_IN_TILES,
			})
		end
	end

	local elapsed = 0
	local candy = CandyBackdrop.new(background)
	local originalSize = background.Size

	local self = setmetatable({
		_connection = nil,
		_candy = candy,
		_originalSize = originalSize,
		_enabled = true,
		_visible = true,
		_background = background,
		_baseTransparency = background.Transparency,
		_textures = textures,
	}, PartyBackgroundController)
	self._connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not self._visible then
			return
		end
		elapsed = (elapsed + deltaTime) % LOOP_DURATION
		local phase = elapsed / LOOP_DURATION * TAU
		local candyActive = background:GetAttribute("CandyBackpackActive") == true
		candy.gui.Enabled = candyActive
		if candyActive and not game:GetService("GuiService").ReducedMotionEnabled then
			candy.update(elapsed)
		end
		local camera = Workspace.CurrentCamera

		if camera then
			local cameraCFrame = camera.CFrame
			if candyActive then
				local h = 2 * CAMERA_DISTANCE * math.tan(math.rad(camera.FieldOfView / 2)) * 1.08
				background.Size = Vector3.new(h * camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1), h, 2)
			else
				background.Size = originalSize
			end
			local position = cameraCFrame.Position + cameraCFrame.LookVector * CAMERA_DISTANCE
			background.CFrame = CFrame.new(position)
				* cameraCFrame.Rotation
				* CFrame.Angles(0, 0, if candyActive then 0 else math.sin(phase) * MAX_ROLL)
		end

		for _, texture in textures do
			if texture.instance.Parent then
				texture.instance.Transparency = if candyActive then 1 else texture.mutedTransparency
				texture.instance.OffsetStudsU = texture.offsetU + math.sin(phase) * texture.travelU
				texture.instance.OffsetStudsV = texture.offsetV + (1 - math.cos(phase)) * texture.travelV
			end
		end
	end)
	self._unsubscribeCamera = PresentationCamera.subscribe(function()
		self:_refreshVisibility()
	end)
	self:_refreshVisibility()
	return self
end

-- The backdrop is pinned a fixed distance ahead of the camera every frame, so
-- leaving it running anywhere other than the lobby parks a wall in front of the
-- player. Disabling stops driving it and hides it outright, textures included,
-- because a Texture's transparency is independent of the part it sits on.
function PartyBackgroundController:setEnabled(value)
	if self._enabled == value then
		return
	end
	self._enabled = value
	self:_refreshVisibility()
end

function PartyBackgroundController:_refreshVisibility()
	local visible = self._enabled and PresentationCamera.getOwner() ~= "CosmeticPreview"
	self._visible = visible
	self._candy.gui.Enabled = visible and self._background:GetAttribute("CandyBackpackActive") == true
	self._background.Transparency = if visible then self._baseTransparency else 1
	for _, texture in self._textures do
		if texture.instance.Parent then
			texture.instance.Transparency = if visible then texture.mutedTransparency else 1
		end
	end
end

function PartyBackgroundController:destroy()
	self._candy.destroy()
	self._background.Size = self._originalSize
	for _, texture in self._textures do
		if texture.instance.Parent then
			texture.instance.Transparency = texture.transparency
		end
	end
	if self._unsubscribeCamera then
		self._unsubscribeCamera()
		self._unsubscribeCamera = nil
	end
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

return PartyBackgroundController
