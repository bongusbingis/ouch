-- Name: InventoryPreview.luau
-- Author: Jack C.
-- Description: Renders cosmetic inventory previews, using live 3D models where available and static badges for script effects and sounds.
-- Created: 2026-08-17

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local InventoryConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))
local CosmeticsModules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics")
local CosmeticVisualFactory = require(CosmeticsModules:WaitForChild("CosmeticVisualFactory"))
local ResponsiveText = require(script.Parent.ResponsiveText)
local CelebrationAvatar = require(script.Parent.Arena.CelebrationAvatar)
local PreviewScheduler = require(script.Parent.Parent.Services.PreviewScheduler)

local c = React.createElement
local function setPivot(object: Model | BasePart, pivot: CFrame)
	if object:IsA("Model") then
		object:PivotTo(pivot)
	else
		object.CFrame = pivot
	end
end

local function update(state, dt: number)
	if GuiService.ReducedMotionEnabled then
		setPivot(state.object, CFrame.Angles(0, state.baseRotation, 0) * state.basePivot)
		return
	end
	state.elapsed += dt
	local spin = math.rad(state.config.SpinDegreesPerSecond) * state.elapsed
	setPivot(state.object, CFrame.Angles(0, state.baseRotation + spin, 0) * state.basePivot)
end

local function register(state)
	update(state, 0)
	return PreviewScheduler.register(state.viewport, function(dt)
		update(state, dt)
	end, state.config.UpdateHz)
end

local function preparePart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function characterPreview(color: Color3): Model
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs"):WaitForChild("CharacterRig")
	assert(template:IsA("Model"), "[InventoryPreview] Assets.Rigs.CharacterRig must be a Model")
	local rig = template:Clone()
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			preparePart(descendant)
			if descendant.Transparency < 1 then
				descendant.Color = color
			end
		end
	end
	return rig
end

local function setScale(object: Model | BasePart, scale: number)
	if object:IsA("Model") then
		object:ScaleTo(scale)
	else
		object.Size *= scale
	end
end

local function centerObject(object: Model | BasePart): CFrame
	if object:IsA("Model") then
		object:PivotTo(CFrame.identity)
		local bounds = object:GetBoundingBox()
		object:PivotTo(CFrame.new(-bounds.Position) * object:GetPivot())
		return object:GetPivot()
	end
	object.CFrame = CFrame.identity
	return object.CFrame
end

export type Props = {
	ItemId: string?,
	Category: string,
	Definition: any,
	ZIndex: number,
	ColorId: string?,
}

local function impactPreview(props: Props)
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(0.72, 0.58),
		ZIndex = props.ZIndex,
	}, {
		Burst = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 40,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = -8,
				Size = UDim2.fromScale(1, 0.72),
				Text = "HIT!",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = props.ZIndex,
			},
		}, {
			UIStroke = c("UIStroke", {
				Color = Color3.fromRGB(30, 30, 30),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.08,
			}),
		}),
	})
end

local function eliminationSoundPreview(props: Props)
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(35, 47, 62),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.45),
		Rotation = -6,
		Size = UDim2.fromScale(0.58, 0.58),
		ZIndex = props.ZIndex,
	}, {
		UICorner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		UIStroke = c("UIStroke", {
			Color = Color3.new(1, 1, 1),
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.075,
		}),
		Label = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 36,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.5, 0.54),
				Size = UDim2.fromScale(0.8, 0.5),
				Text = "SFX!",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = props.ZIndex + 1,
			},
		}, {
			UIStroke = c("UIStroke", {
				Color = Color3.fromRGB(20, 24, 34),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.08,
			}),
		}),
	})
end

local ViewportPreview = React.memo(function(props: Props)
	local viewportRef = React.useRef(nil)
	local cameraRef = React.useRef(nil)
	local worldRef = React.useRef(nil)
	local config = InventoryConfig.Viewport[props.Category]
	assert(config ~= nil, `[InventoryPreview] no preview config for {props.Category}`)

	React.useEffect(function()
		local viewport: ViewportFrame = viewportRef.current
		local camera: Camera = cameraRef.current
		local world: WorldModel = worldRef.current
		if not viewport or not camera or not world then
			return
		end
		viewport.CurrentCamera = camera
		local object: (Model | BasePart)? = nil
		local unregister: (() -> ())? = nil
		local preparation = task.defer(function()
			local prepared: Model | BasePart
			if props.Category == "CharacterColor" then
				local color = props.Definition.PreviewColor
				assert(color ~= nil, "[InventoryPreview] character colors require PreviewColor")
				prepared = characterPreview(color)
			else
				prepared = CosmeticVisualFactory.create(props.Category, props.ItemId)
			end
			object = prepared
			setScale(prepared, config.Scale)
			prepared.Parent = world
			local target = config.TargetOffset
			camera.CFrame = CFrame.lookAt(target + config.CameraOffset, target)
			unregister = register({
				object = prepared,
				viewport = viewport,
				scroller = viewport:FindFirstAncestorWhichIsA("ScrollingFrame"),
				category = props.Category,
				config = config,
				basePivot = centerObject(prepared),
				baseRotation = math.rad(config.RotationDegrees),
				elapsed = 0,
				updateAccumulator = 0,
			})
		end)
		return function()
			if coroutine.status(preparation) ~= "dead" then
				task.cancel(preparation)
			end
			if unregister then
				unregister()
			end
			if object then
				object:Destroy()
			end
			if viewport.CurrentCamera == camera then
				viewport.CurrentCamera = nil
			end
		end
	end, { props.Category, props.ItemId, props.Definition })

	return c("ViewportFrame", {
		ref = viewportRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.475),
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex,
	}, {
		UIScale = c("UIScale", { Scale = 2 }),
		PreviewCamera = c("Camera", { ref = cameraRef }),
		PreviewWorld = c("WorldModel", { ref = worldRef }),
	})
end)

return React.memo(function(props: Props)
	if props.Category == "EmoteAssets" then
		return c(CelebrationAvatar, { EmoteId = props.ItemId, ColorId = props.ColorId, ZIndex = props.ZIndex })
	end
	if props.Category == "ImpactEffectAssets" then
		return impactPreview(props)
	end
	if props.Category == "ElimEffectAssets" then
		return eliminationSoundPreview(props)
	end
	return c(ViewportPreview, props)
end)
