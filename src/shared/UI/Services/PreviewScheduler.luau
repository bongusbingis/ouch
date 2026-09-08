-- One bounded update loop serves visible UI previews and stops when the last preview unmounts.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI")).Preview
local PreviewScheduler = {}
local active = {}
local connection: RBXScriptConnection? = nil
local accumulator = 0

local function overlaps(position: Vector2, size: Vector2, clipPosition: Vector2, clipSize: Vector2): boolean
	return position.X < clipPosition.X + clipSize.X
		and position.X + size.X > clipPosition.X
		and position.Y < clipPosition.Y + clipSize.Y
		and position.Y + size.Y > clipPosition.Y
end

function PreviewScheduler.isVisible(viewport: GuiObject): boolean
	if viewport.Parent == nil then
		return false
	end
	local ancestor: Instance? = viewport
	while ancestor do
		if ancestor:IsA("GuiObject") then
			if not ancestor.Visible then
				return false
			end
			if ancestor ~= viewport and (ancestor.ClipsDescendants or ancestor:IsA("ScrollingFrame")) then
				local size = if ancestor:IsA("ScrollingFrame")
					then ancestor.AbsoluteWindowSize
					else ancestor.AbsoluteSize
				if not overlaps(viewport.AbsolutePosition, viewport.AbsoluteSize, ancestor.AbsolutePosition, size) then
					return false
				end
			end
		elseif ancestor:IsA("ScreenGui") and not ancestor.Enabled then
			return false
		end
		ancestor = ancestor.Parent
	end
	local camera = Workspace.CurrentCamera
	return camera ~= nil
		and overlaps(viewport.AbsolutePosition, viewport.AbsoluteSize, Vector2.zero, camera.ViewportSize)
end

function PreviewScheduler.register(viewport: GuiObject, update: (number) -> (), rate: number?): () -> ()
	local entry = {
		viewport = viewport,
		update = update,
		interval = 1 / math.clamp(rate or Config.MaxHz, 1, Config.MaxHz),
		elapsed = 0,
	}
	active[entry] = true
	if connection == nil then
		connection = RunService.RenderStepped:Connect(function(dt)
			accumulator += dt
			if accumulator < 1 / Config.MaxHz then
				return
			end
			local step = math.min(accumulator, Config.MaxDeltaSeconds)
			accumulator = 0
			for preview in active do
				if PreviewScheduler.isVisible(preview.viewport) then
					preview.elapsed += step
					if preview.elapsed >= preview.interval then
						local elapsed = preview.elapsed
						preview.elapsed = 0
						local ok, err = pcall(preview.update, elapsed)
						if not ok then
							active[preview] = nil
							warn(`[PreviewScheduler] preview update failed: {err}`)
						end
					end
				else
					preview.elapsed = 0
				end
			end
			if next(active) == nil and connection then
				connection:Disconnect()
				connection = nil
				accumulator = 0
			end
		end)
	end
	return function()
		active[entry] = nil
		if next(active) == nil and connection then
			connection:Disconnect()
			connection = nil
			accumulator = 0
		end
	end
end

return PreviewScheduler
