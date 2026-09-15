-- Description: Renders cosmetic inventory previews, using shared character appearance and marking effects that open in the live preview scene.

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local InventoryConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))
local CosmeticsModules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics")
local CosmeticVisualFactory = require(CosmeticsModules:WaitForChild("CosmeticVisualFactory"))
local CharacterAppearance = require(CosmeticsModules:WaitForChild("CharacterAppearance"))
local CelebrationAvatar = require(script.Parent.Arena.CelebrationAvatar)
local PreviewScheduler = require(script.Parent.Parent.Services.PreviewScheduler)
local T = require(script.Parent.Parent.Tokens)

local Icon = require(script.Parent.Icon)
local CandyEffectPreview = require(script.Parent.CandyEffectPreview)

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

local function characterPreview(): Model
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs"):WaitForChild("CharacterRig")
	assert(template:IsA("Model"), "[InventoryPreview] Assets.Rigs.CharacterRig must be a Model")
	local rig = template:Clone()
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			preparePart(descendant)
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
	Playing: boolean?,
	Candy: boolean?,
	ItemId: string?,
	Category: string,
	Definition: any,
	ZIndex: number,
	ColorId: string?,
	CostumeId: string?,
	TextColor: Color3?,
	TextStroke: number?,
}

local function effectPreview(props: Props)
	local palette = UI.ProgressionStyle
	local definition = props.Definition or {}
	local accent = definition.PreviewColor or InventoryConfig.RarityColors[definition.Rarity] or palette.Yellow
	local icon = definition.Icon or (if props.Category == "ElimEffectAssets" then "Speaker" else "Explosion")
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = props.ZIndex }, {
		Tile = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if props.Candy
				then (if props.Category == "ElimEffectAssets" then T.Colors.Cyan else T.Colors.Grape)
				else palette.Ink,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.72, 0.84),
			ZIndex = props.ZIndex,
		}, {
			Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Corner = c(
				"UICorner",
				{ CornerRadius = if props.Candy then UDim.new(0.4, 0) else UDim.new(0, UI.Radius.Tile) }
			),
			Outline = c("UIStroke", {
				Color = if props.Candy then T.Colors.Ink else accent,
				Thickness = if props.Candy then T.Shape.StrokeCard else 2,
				Transparency = 0,
			}),
			Glyph = c(Icon, {
				Name = icon,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.82, 0.82),
					ZIndex = props.ZIndex + 1,
				},
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
		local appearance = nil
		local resize = nil
		local preparation = task.defer(function()
			local prepared: Model | BasePart
			if props.Category == "CharacterColor" or props.Category == "CostumeAssets" then
				local look = {
					characterColorId = if props.Category == "CharacterColor" then props.ItemId else props.ColorId,
					costumeId = if props.Category == "CostumeAssets" then props.ItemId else props.CostumeId,
				}
				CharacterAppearance.prepare(look)
				prepared = characterPreview()
				object = prepared
				appearance = CharacterAppearance.create(prepared, look)
			else
				prepared = CosmeticVisualFactory.create(props.Category, props.ItemId)
			end
			object = prepared
			setScale(prepared, config.Scale)
			prepared.Parent = world
			local basePivot = centerObject(prepared)
			local extent = if prepared:IsA("Model") then select(2, prepared:GetBoundingBox()) else prepared.Size
			local function frameCamera()
				local size = viewport.AbsoluteSize
				local aspect = math.max(size.X, 1) / math.max(size.Y, 1)
				local target = config.TargetOffset
				local radius = Vector2.new(extent.X, extent.Z).Magnitude / 2
				local tangent = math.tan(math.rad(camera.FieldOfView / 2)) * InventoryConfig.ViewportFill
				local distance = math.max((extent.Y / 2 + math.abs(target.Y)) / tangent, radius / (tangent * aspect))
					+ radius
				camera.CFrame = CFrame.lookAt(
					target + config.CameraOffset.Unit * distance * (if props.Candy then 0.76 else 1),
					target
				)
			end
			frameCamera()
			resize = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameCamera)
			unregister = register({
				object = prepared,
				viewport = viewport,
				scroller = viewport:FindFirstAncestorWhichIsA("ScrollingFrame"),
				category = props.Category,
				config = config,
				basePivot = basePivot,
				baseRotation = math.rad(config.RotationDegrees),
				elapsed = 0,
				updateAccumulator = 0,
			})
		end)
		return function()
			if coroutine.status(preparation) ~= "dead" then
				task.cancel(preparation)
			end
			if resize then
				resize:Disconnect()
			end
			if unregister then
				unregister()
			end
			if appearance then
				appearance.destroy()
			end
			if object then
				object:Destroy()
			end
			if viewport.CurrentCamera == camera then
				viewport.CurrentCamera = nil
			end
		end
	end, { props.Category, props.ItemId, props.Definition, props.ColorId, props.CostumeId })

	return c("ViewportFrame", {
		ref = viewportRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.475),
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex,
	}, {
		PreviewCamera = c("Camera", { ref = cameraRef, FieldOfView = InventoryConfig.ViewportFieldOfView }),
		PreviewWorld = c("WorldModel", { ref = worldRef }),
	})
end)

return React.memo(function(props: Props)
	if props.Category == "EmoteAssets" then
		return c(CelebrationAvatar, {
			EmoteId = props.ItemId,
			ColorId = props.ColorId,
			CostumeId = props.CostumeId,
			ZIndex = props.ZIndex,
			Playing = props.Playing,
		})
	end
	if props.Category == "ImpactEffectAssets" or props.Category == "ElimEffectAssets" then
		if props.Candy then
			return c(CandyEffectPreview, props)
		end
		return effectPreview(props)
	end
	return c(ViewportPreview, props)
end)
