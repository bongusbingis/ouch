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

-- Effect cards cannot render the live effect, so each one gets a flat badge from a
-- small family of shapes keyed by the effect, tinted with the item's colour. The
-- shapes are circles and pills only: rotated GuiObjects escape ClipsDescendants and
-- would paint over the page when a card scrolls half out of the Backpack list.
local EFFECT_FAMILIES = {
	{ "Confetti", "confetti" },
	{ "Party", "confetti" },
	{ "Royal", "confetti" },
	{ "Star", "sparkle" },
	{ "Prism", "sparkle" },
	{ "Sugar", "sparkle" },
	{ "Candy", "sparkle" },
	{ "Foam", "bubbles" },
	{ "Bubble", "bubbles" },
	{ "Jelly", "bubbles" },
	{ "Splash", "bubbles" },
}

local function effectFamily(effectId: string?): string
	for _, entry in EFFECT_FAMILIES do
		if effectId and string.find(effectId, entry[1]) then
			return entry[2]
		end
	end
	return "burst"
end

local function dot(
	symbol,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	z: number,
	transparency: number?
)
	symbol[name] = c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		ZIndex = z,
	}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

local function effectPreview(props: Props)
	local palette = UI.ProgressionStyle
	local definition = props.Definition or {}
	local accent = definition.PreviewColor or InventoryConfig.RarityColors[definition.Rarity] or palette.Yellow
	local z = props.ZIndex + 1
	local symbol = {
		Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Outline = c("UIStroke", { Color = accent, Thickness = 2, Transparency = 0.2 }),
	}
	local family = if props.Category == "ElimEffectAssets" then "wave" else effectFamily(definition.EffectId)
	if family == "wave" then
		for index, height in { 0.18, 0.38, 0.62, 0.8, 0.52, 0.3, 0.14 } do
			dot(
				symbol,
				`Wave{index}`,
				0.2 + (index - 1) * 0.1,
				0.5,
				0.055,
				height * 0.75,
				if index == 4 then accent else palette.White,
				z
			)
		end
	elseif family == "sparkle" then
		dot(symbol, "Beam1", 0.5, 0.5, 0.1, 0.62, palette.White, z)
		dot(symbol, "Beam2", 0.5, 0.5, 0.62, 0.1, palette.White, z)
		dot(symbol, "Core", 0.5, 0.5, 0.22, 0.22, accent, z + 1)
		for index, offset in { { 0.26, 0.26 }, { 0.74, 0.26 }, { 0.26, 0.74 }, { 0.74, 0.74 } } do
			dot(symbol, `Spark{index}`, offset[1], offset[2], 0.09, 0.09, accent, z)
		end
	elseif family == "bubbles" then
		dot(symbol, "Big", 0.4, 0.56, 0.36, 0.36, palette.White, z, 0.15)
		dot(symbol, "Mid", 0.7, 0.36, 0.24, 0.24, accent, z)
		dot(symbol, "Small", 0.66, 0.7, 0.14, 0.14, palette.White, z, 0.1)
		dot(symbol, "Shine", 0.34, 0.48, 0.08, 0.08, accent, z + 1)
	elseif family == "confetti" then
		local pieces = {
			{ 0.3, 0.28, true },
			{ 0.52, 0.2, false },
			{ 0.72, 0.34, true },
			{ 0.24, 0.52, false },
			{ 0.5, 0.5, true },
			{ 0.76, 0.58, false },
			{ 0.36, 0.74, true },
			{ 0.6, 0.78, false },
		}
		for index, piece in pieces do
			local tall = index % 2 == 0
			dot(
				symbol,
				`Piece{index}`,
				piece[1],
				piece[2],
				if tall then 0.08 else 0.16,
				if tall then 0.16 else 0.08,
				if piece[3] then accent else palette.White,
				z
			)
		end
	else
		dot(symbol, "Core", 0.5, 0.5, 0.32, 0.32, accent, z + 1)
		dot(symbol, "Hot", 0.5, 0.5, 0.12, 0.12, palette.White, z + 2)
		for index = 1, 8 do
			local angle = (index - 1) / 8 * math.pi * 2 + math.pi / 8
			local major = index % 2 == 1
			local side = if major then 0.11 else 0.07
			local radius = if major then 0.4 else 0.33
			dot(
				symbol,
				`Ray{index}`,
				0.5 + math.cos(angle) * radius,
				0.5 + math.sin(angle) * radius,
				side,
				side,
				if major then palette.White else accent,
				z
			)
		end
	end
	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex,
	}, {
		Symbol = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = palette.Surface,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.72, 0.84),
			ZIndex = props.ZIndex,
		}, symbol),
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
