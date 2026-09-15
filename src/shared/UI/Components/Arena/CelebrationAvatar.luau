-- Shared victory-emote preview and result avatar; a capped visible-only scheduler owns playback.
--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Emotes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Emotes"))
local Colors =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation")).Colors
local EmoteRig = require(script.Parent.Parent.Parent.Services.EmoteRig)
local PreviewScheduler = require(script.Parent.Parent.Parent.Services.PreviewScheduler)
local c = React.createElement

return React.memo(function(props)
	local viewportRef, cameraRef, worldRef = React.useRef(nil), React.useRef(nil), React.useRef(nil)
	local displayRef = React.useRef(nil)
	local playingRef = React.useRef(props.Playing)
	playingRef.current = props.Playing
	local elapsed, setElapsed = React.useBinding(0)
	React.useEffect(function()
		local viewport, camera, world = viewportRef.current, cameraRef.current, worldRef.current
		if not viewport or not camera or not world then
			return
		end
		viewport.CurrentCamera = camera
		local function frameCamera()
			local size = viewport.AbsoluteSize
			local aspect = math.max(size.X, 1) / math.max(size.Y, 1)
			local span = math.max(Emotes.Preview.HeightStuds, Emotes.Preview.WidthStuds / aspect)
			local distance = span / (2 * math.tan(math.rad(Emotes.Preview.FieldOfView / 2)))
			local target = Emotes.Preview.TargetOffset
			camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 0.4, distance), target)
		end
		frameCamera()
		local resize = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameCamera)
		local display, unregister = nil, nil
		local preparation = task.defer(function()
			display = EmoteRig.create(world, props.ColorId, props.CostumeId)
			if props.Playing ~= nil then
				display.setOrigin(CFrame.identity)
			end
			displayRef.current = display
			if props.EmoteId and playingRef.current ~= false then
				display.playEmote(props.EmoteId)
			end
			local time = 0
			local function update(dt)
				time += dt
				setElapsed(
					if props.Static or playingRef.current == false or GuiService.ReducedMotionEnabled then 0 else time
				)
			end
			update(0)
			if not props.Static then
				unregister = PreviewScheduler.register(viewport, update, Emotes.Preview.UpdateHz)
			end
		end)
		return function()
			resize:Disconnect()
			if coroutine.status(preparation) ~= "dead" then
				task.cancel(preparation)
			end
			if unregister then
				unregister()
			end
			if display then
				displayRef.current = nil
				display.destroy()
			end
			if viewport.CurrentCamera == camera then
				viewport.CurrentCamera = nil
			end
		end
	end, { props.EmoteId, props.ColorId, props.CostumeId, props.Static })
	React.useEffect(function()
		local display = displayRef.current
		if display and props.EmoteId then
			if props.Playing == false then
				display.stopEmote()
			else
				display.playEmote(props.EmoteId)
			end
		end
	end, { props.Playing })
	local z = props.ZIndex or 3
	local confetti = {}
	for index = 1, 14 do
		local seed = index * 0.61803398875 % 1
		confetti["Piece" .. index] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = ({ Colors.Cyan, Colors.Yellow, Colors.White })[index % 3 + 1],
			BackgroundTransparency = elapsed:map(function(t)
				return if t == 0 then 1 else 0.08
			end),
			BorderSizePixel = 0,
			Position = elapsed:map(function(t)
				local phase = (t / 3.2 + seed) % 1
				return UDim2.fromScale(0.08 + seed * 0.84 + math.sin(t * 2 + index) * 0.035, phase)
			end),
			Size = UDim2.fromOffset(if index % 2 == 0 then 4 else 6, if index % 2 == 0 then 4 else 6),
			ZIndex = z + 1,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
	end
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.Size = native.Size or UDim2.fromScale(1, 1)
	native.ClipsDescendants = true
	native.ZIndex = z
	return c("Frame", native, {
		Avatar = c("ViewportFrame", {
			ref = viewportRef,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Ambient = Color3.fromRGB(205, 205, 225),
			LightColor = Color3.fromRGB(255, 246, 230),
			LightDirection = Vector3.new(-1, -1, -1),
			ZIndex = z,
		}, {
			Camera = c("Camera", { ref = cameraRef, FieldOfView = Emotes.Preview.FieldOfView }),
			World = c("WorldModel", { ref = worldRef }),
		}),
		Confetti = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 1 }, confetti),
	})
end)
