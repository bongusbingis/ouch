-- Prism Cloud / rigid R15 outfit adapter
-- ModuleScript only: does nothing until a function is called.
-- Import the supplied FBX with all 10 mesh names preserved.
-- This is NOT a layered-clothing or Marketplace-ready accessory.
local PrismCloud = {}
local pieces = {
    {name="PC_Head", target="Head", size=Vector3.new(2.565000057, 2.501309872, 1.597642183), offset=Vector3.new(-0.000000060, 0.131844997, 0.296135038)},
    {name="PC_UpperTorso", target="UpperTorso", size=Vector3.new(2.770000219, 1.605000019, 2.434928417), offset=Vector3.new(0.000000000, 0.273299068, -0.002112299)},
    {name="PC_RightUpperArm", target="RightUpperArm", size=Vector3.new(1.133000374, 1.058400035, 1.089000106), offset=Vector3.new(-0.000000119, 0.000000000, -0.005499884)},
    {name="PC_RightLowerArm", target="RightLowerArm", size=Vector3.new(1.048000216, 0.245999992, 1.088999987), offset=Vector3.new(0.000000000, -0.122999996, -0.010499924)},
    {name="PC_RightLowerLeg", target="RightLowerLeg", size=Vector3.new(1.219751239, 0.636422396, 1.369545817), offset=Vector3.new(-0.000000060, -0.023211122, -0.042827070)},
    {name="PC_RightFoot", target="RightFoot", size=Vector3.new(1.209100008, 0.544350386, 1.353550076), offset=Vector3.new(0.000000000, 0.029925108, -0.045474991)},
    {name="PC_LeftUpperArm", target="LeftUpperArm", size=Vector3.new(1.133000374, 1.058400035, 1.089000106), offset=Vector3.new(-0.000000119, 0.000000000, -0.005499884)},
    {name="PC_LeftLowerArm", target="LeftLowerArm", size=Vector3.new(1.048000216, 0.245999992, 1.088999987), offset=Vector3.new(0.000000000, -0.122999996, -0.010499924)},
    {name="PC_LeftLowerLeg", target="LeftLowerLeg", size=Vector3.new(1.219751239, 0.636422396, 1.369545817), offset=Vector3.new(0.000000060, -0.023211122, -0.042827070)},
    {name="PC_LeftFoot", target="LeftFoot", size=Vector3.new(1.209100008, 0.544350386, 1.353550076), offset=Vector3.new(0.000000000, 0.029924870, -0.045474991)},
}

-- Validate everything before creating or modifying instances.
local function validate(character, template)
    assert(character and character:IsA("Model"), "Expected character Model")
    assert(template and template:IsA("Model"), "Expected imported outfit Model")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    assert(humanoid and humanoid.RigType == Enum.HumanoidRigType.R15, "Requires R15")
    for _, spec in ipairs(pieces) do
        local target = character:FindFirstChild(spec.target)
        assert(target and target:IsA("BasePart"), "Missing body part: " .. spec.target)
        local matches = {}
        for _, item in ipairs(template:GetDescendants()) do
            if item.Name == spec.name and item:IsA("MeshPart") then
                table.insert(matches, item)
            end
        end
        assert(#matches == 1, "Expected exactly one imported MeshPart named " .. spec.name)
    end
end

-- Changes only the supplied character by adding a new outfit Model.
-- Call CreatePreview first to preserve the original character.
function PrismCloud.Attach(character, template)
    validate(character, template)
    assert(not character:FindFirstChild("PrismCloud_Outfit"), "Character already has this outfit")
    local outfit = Instance.new("Model")
    outfit.Name = "PrismCloud_Outfit"
    for _, spec in ipairs(pieces) do
        local target = character:FindFirstChild(spec.target)
        local source
        for _, item in ipairs(template:GetDescendants()) do
            if item.Name == spec.name and item:IsA("MeshPart") then source = item; break end
        end
        local piece = source:Clone()
        -- The source is an imported mesh. Retain only its appearance children.
        for _, child in ipairs(piece:GetChildren()) do
            if not child:IsA("SurfaceAppearance") then child:Destroy() end
        end
        piece.Size = spec.size
        piece.CFrame = target.CFrame * CFrame.new(spec.offset)
        piece.Anchored = false
        piece.CanCollide = false
        piece.CanTouch = false
        piece.CanQuery = false
        piece.Massless = true
        piece.CastShadow = true
        piece.Parent = outfit
        local weld = Instance.new("WeldConstraint")
        weld.Name = "PrismCloudMount"
        weld.Part0 = target
        weld.Part1 = piece
        weld.Parent = piece
    end
    outfit.Parent = character
    return outfit
end

-- Creates a separate static fitting copy. Original character is untouched.
-- Does not save, publish, start a playtest, or alter scripts on the original.
function PrismCloud.CreatePreview(character, template, offset)
    validate(character, template)
    assert(character.Archivable, "Character must be Archivable before cloning")
    local clone = character:Clone()
    assert(clone, "Could not clone character")
    clone.Name = "CharacterRig_PrismCloud_PREVIEW"
    for _, item in ipairs(clone:GetDescendants()) do
        if item:IsA("BaseScript") or item:IsA("ModuleScript") then
            item:Destroy()
        end
    end
    local root = clone:FindFirstChild("HumanoidRootPart")
    if root then root.Anchored = true end
    clone:PivotTo(character:GetPivot() * (offset or CFrame.new(6,0,0)))
    PrismCloud.Attach(clone, template)
    clone.Parent = character.Parent
    return clone
end

return PrismCloud
