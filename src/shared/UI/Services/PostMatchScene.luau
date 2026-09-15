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
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Scene = {}

function Scene.create(entries: { any }, viewport: GuiObject)
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("ResultsStage")
	assert(template:IsA("Model"), "[PostMatchScene] Assets.UI.ResultsStage must be a Model")
	local stage = template:Clone()
	stage.Name = "PostMatchStage"
	stage:PivotTo(Config.StageOrigin)
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
			local marker = stand:WaitForChild("Avatar")
			assert(marker:IsA("BasePart"), "[PostMatchScene] stand Avatar must be a BasePart")
			local rank = stand:WaitForChild("Plaque"):WaitForChild("Label"):WaitForChild("Rank")
			assert(rank:IsA("TextLabel"), "[PostMatchScene] stand Rank must be a TextLabel")
			rank.Text = tostring(entry.placement)
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
					piece.Color = ({
						Presentation.Colors.Cyan,
						Presentation.Colors.Yellow,
						Presentation.Colors.White,
					})[index % 3 + 1]
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
