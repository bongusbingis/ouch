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
	ItemId: string?,
	Category: string,
	Definition: any,
	ZIndex: number,
	ColorId: string?,
	CostumeId: string?,
	TextColor: Color3?,
	TextStroke: number?,
}

local function previewStroke(thickness: number?)
	return if thickness
		then c("UIStroke", {
			Color = UI.ProgressionStyle.Ink,
			Thickness = thickness,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		})
		else nil
end

local function effectPreview(props: Props)
	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex,
	}, {
		Symbol = c(ResponsiveText, {
			MeasurementFont = Enum.Font.SourceSansBold,
			MaxTextSize = 76,
			Native = {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.15, 0.1),
				Size = UDim2.fromScale(0.7, 0.52),
				Font = Enum.Font.SourceSansBold,
				Text = if props.Category == "ElimEffectAssets" then "SFX" else "★",
				TextColor3 = props.TextColor or Color3.new(1, 1, 1),
				ZIndex = props.ZIndex,
			},
		}, { Outline = previewStroke(props.TextStroke) }),
		Caption = c(ResponsiveText, {
			Wrapped = true,
			MeasurementFont = UI.Text.BodyFont,
			MaxTextSize = 18,
			Native = {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.1, 0.62),
				Size = UDim2.fromScale(0.8, 0.26),
				Font = UI.Text.BodyFont,
				Text = if props.Category == "ElimEffectAssets" then "ELIMINATION SOUND" else "IMPACT EFFECT",
				TextWrapped = true,
				TextColor3 = props.TextColor or Color3.new(1, 1, 1),
				ZIndex = props.ZIndex,
			},
		}, { Outline = previewStroke(props.TextStroke) }),
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
				camera.CFrame = CFrame.lookAt(target + config.CameraOffset.Unit * distance, target)
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
		return c(
			CelebrationAvatar,
			{ EmoteId = props.ItemId, ColorId = props.ColorId, CostumeId = props.CostumeId, ZIndex = props.ZIndex }
		)
	end
	if props.Category == "ImpactEffectAssets" or props.Category == "ElimEffectAssets" then
		return effectPreview(props)
	end
	return c(ViewportPreview, props)
end)
