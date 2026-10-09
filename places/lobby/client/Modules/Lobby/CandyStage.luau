--!strict
-- Local, reversible set dressing; all authored camera/spawn/rig instances are preserved.
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local T = require(RS.Shared.UI.Tokens)
local C = T.Colors
local CandyStage = {}

local function part(parent, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = false
	p.Parent = parent
	return p
end

function CandyStage.new(party)
	local model = Instance.new("Folder")
	model.Name = "CandyPodium"
	local spawn = party.Players.Player1
	local center = spawn.Position - Vector3.new(0, 2.62, 0)
	local radius, height = T.Stage.Radius, T.Stage.Height
	local function cylinder(name, y, thickness, r, color)
		local p = part(
			model,
			name,
			Vector3.new(thickness, r * 2, r * 2),
			CFrame.new(center + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			color
		)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	cylinder("BottomLip", -height + 0.1, 0.22, radius + 0.08, C.PinkLip)
	cylinder("Riser", -height / 2, height, radius, C.Pink)
	for stripe = 0, T.Stage.StripeCount - 1 do
		if stripe % 2 == 0 then
			local angle = stripe / T.Stage.StripeCount * math.pi * 2
			local position = center
				+ Vector3.new(math.sin(angle) * (radius + 0.02), -height / 2, math.cos(angle) * (radius + 0.02))
			part(
				model,
				"CandyStripe",
				Vector3.new(radius * math.pi * 2 / T.Stage.StripeCount * 0.85, height * 1.12, 0.08),
				CFrame.new(position) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0, 0, math.rad(-25)),
				C.SurfaceWarm
			)
		end
	end
	cylinder("TopRim", 0, T.Stage.TopHeight, radius + 0.1, C.SurfaceWarm)
	cylinder("PastelTop", T.Stage.TopHeight / 2, 0.04, radius - 0.18, C.BackdropMid)
	cylinder("LandingSpot", T.Stage.TopHeight / 2 + 0.025, 0.03, radius * 0.55, C.Well)
	local lightPart = part(model, "Spotlight", Vector3.one * 0.1, CFrame.new(center + Vector3.new(0, 12, 0)), C.Surface)
	lightPart.Transparency = 1
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Color = C.SurfaceWarm
	light.Range = 24
	light.Angle = 48
	light.Brightness = 2
	light.Parent = lightPart
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PodiumConfetti"
	emitter.Color = ColorSequence.new(C.Pink, C.Yellow)
	emitter.Size = NumberSequence.new(0.09)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(2, 3)
	emitter.Rate = 2
	emitter.Speed = NumberRange.new(0.5, 1)
	emitter.Acceleration = Vector3.new(0, -2, 0)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Parent = lightPart
	local function updateMotion()
		emitter.Enabled = not GuiService.ReducedMotionEnabled
	end
	updateMotion()
	local motionConnection = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(updateMotion)
	local original = party:FindFirstChild("podium_002")
	local originalModifier = if original then original.LocalTransparencyModifier else 0
	local enabled = false
	local circles = {}
	for _, object in workspace:GetChildren() do
		if object.Name == "PlayerCircle" and object:IsA("BasePart") and (object.Position - center).Magnitude < 25 then
			for _, decal in object:GetChildren() do
				if decal:IsA("Decal") then
					circles[decal] = decal.Transparency
				end
			end
		end
	end
	return {
		setEnabled = function(value)
			enabled = value
			if value then
				for _, object in workspace:GetChildren() do
					if
						object.Name == "PlayerCircle"
						and object:IsA("BasePart")
						and (object.Position - center).Magnitude < 25
					then
						for _, decal in object:GetChildren() do
							if decal:IsA("Decal") and circles[decal] == nil then
								circles[decal] = decal.Transparency
							end
						end
					end
				end
			end
			for decal, transparency in circles do
				decal.Transparency = if value then 1 else transparency
			end
			model.Parent = if value then party else nil
			if original then
				original.LocalTransparencyModifier = if value then 1 else originalModifier
			end
		end,
		burst = function()
			if enabled and not GuiService.ReducedMotionEnabled then
				emitter:Emit(T.Motion.BurstCount)
			end
		end,
		destroy = function()
			motionConnection:Disconnect()
			if original then
				original.LocalTransparencyModifier = originalModifier
			end
			for decal, transparency in circles do
				if decal.Parent then
					decal.Transparency = transparency
				end
			end
			model:Destroy()
		end,
	}
end

return CandyStage
