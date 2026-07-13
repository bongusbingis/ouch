local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = Shared:WaitForChild("Classes")
local UnitsClass = require(Classes:WaitForChild("UnitClass"))
local PacksClass = require(Classes:WaitForChild("PackClass"))

local ViewportUtil = require(Knit.Util.Viewport)

local SharedStorage: Folder = ReplicatedStorage:WaitForChild("SharedStorage")
local ReplicatedFolder: Folder = ReplicatedStorage:WaitForChild("Replicated")

local WeaponStorage: Folder = ReplicatedStorage:WaitForChild("Weapons")
local PacksStorage: Folder = ReplicatedFolder:WaitForChild("Packs")
local UnitsStorage: Folder = SharedStorage:WaitForChild("Units")

local function getUnitIdleAnimationByName(unitInfo: {})
	local animationKey = unitInfo.Animations.Idle
	if type(animationKey) == "string" and animationKey == "Default" then
		return UnitsClass.DefaultAnimations.Idle
	elseif typeof(animationKey) == "Instance" and animationKey:IsA("Animation") then
		return animationKey
	end
end

local function getClassDataForViewportItem(itemName: string, classModule: {})
	return classModule[itemName]
end

return {
	Weapons = function(viewportFrame: ViewportFrame, viewportCamera: Camera, weaponName: string)
		local wepaonModel: Model = WeaponStorage:FindFirstChild(weaponName, true)
		if wepaonModel then
			local thisWeapon = wepaonModel:Clone()
			thisWeapon:PivotTo(thisWeapon:GetPivot() * CFrame.Angles(0, math.rad(15), math.rad(-45)))
			thisWeapon.Parent = viewportFrame.WorldModel

			local viewModel = ViewportUtil.Create(viewportFrame, viewportCamera)
			viewModel.SetModel(thisWeapon)
			viewModel.Calibrate()

			local distance = viewModel.GetFitDistance()
			local center = thisWeapon:GetBoundingBox()
			local direction = Vector3.new(0, 0, 1)
			viewportCamera.CFrame = CFrame.new(center.Position + direction * distance / 1.2, center.Position)
		end
	end,
	Packs = function(viewportFrame: ViewportFrame, viewportCamera: Camera, packName: string)
		local packModel: Model = PacksClass[packName].PackTemplate
		if packModel then
			local thisPack = packModel:Clone()
			thisPack.Parent = viewportFrame.WorldModel
			thisPack:PivotTo(thisPack:GetPivot() * CFrame.Angles(0, math.rad(5), math.rad(-5)))

			local viewModel = ViewportUtil.Create(viewportFrame, viewportCamera)
			viewModel.SetModel(thisPack)
			viewModel.Calibrate()

			local distance = viewModel.GetFitDistance()
			local center = thisPack:GetBoundingBox()
			local direction = Vector3.new(0, 0, 1)
			viewportCamera.CFrame = CFrame.new(center.Position + direction * distance / 1.2, center.Position)
		end
	end,
	Units = function(viewportFrame: ViewportFrame, viewportCamera: Camera, unitName: string)
		local unitModel: Model = UnitsStorage:FindFirstChild(unitName, true)
		local inventorySlot: ImageButton = viewportFrame.Parent
		local animationToPreload: Animation? = nil
		if unitModel then
			local thisUnit = unitModel:Clone()
			thisUnit.Parent = viewportFrame.WorldModel
			viewportCamera.CFrame = thisUnit.Head.CFrame * CFrame.new(-0.5, -0.75, -2.75)
			viewportCamera.CFrame = CFrame.new(viewportCamera.CFrame.Position, thisUnit.Head.Position)

			local humanoidAnimator = thisUnit.Humanoid:FindFirstChildWhichIsA("Animator")
			if humanoidAnimator then
				local idleAnimation = getUnitIdleAnimationByName(getClassDataForViewportItem(unitName, UnitsClass))
				animationToPreload = idleAnimation
				if idleAnimation and idleAnimation:IsA("Animation") then
					viewportFrame.Parent = workspace
					local animationTrack = humanoidAnimator:LoadAnimation(idleAnimation)
					animationTrack.Looped = true
					animationTrack:Play()
					viewportFrame.Parent = inventorySlot
				end
			end
			return animationToPreload
		end
	end,
}
