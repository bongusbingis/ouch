local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PartyBackgroundController = {}
PartyBackgroundController.__index = PartyBackgroundController

local CAMERA_DISTANCE = 50
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
				offsetU = descendant.OffsetStudsU,
				offsetV = descendant.OffsetStudsV,
				travelU = descendant.StudsPerTileU * U_TRAVEL_IN_TILES,
				travelV = descendant.StudsPerTileV * V_TRAVEL_IN_TILES,
			})
		end
	end

	local elapsed = 0

	local self = setmetatable({ _connection = nil }, PartyBackgroundController)
	self._connection = RunService.RenderStepped:Connect(function(deltaTime)
		elapsed = (elapsed + deltaTime) % LOOP_DURATION
		local phase = elapsed / LOOP_DURATION * TAU
		local camera = Workspace.CurrentCamera

		if camera then
			local cameraCFrame = camera.CFrame
			local position = cameraCFrame.Position + cameraCFrame.LookVector * CAMERA_DISTANCE
			background.CFrame = CFrame.new(position)
				* cameraCFrame.Rotation
				* CFrame.Angles(0, 0, math.sin(phase) * MAX_ROLL)
		end

		for _, texture in textures do
			if texture.instance.Parent then
				texture.instance.OffsetStudsU = texture.offsetU + math.sin(phase) * texture.travelU
				texture.instance.OffsetStudsV = texture.offsetV + (1 - math.cos(phase)) * texture.travelV
			end
		end
	end)
	return self
end

function PartyBackgroundController:destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

return PartyBackgroundController
