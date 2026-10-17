-- Cosmic Arcade / rigid R15 outfit adapter
-- ModuleScript only: does nothing until a function is called.
-- Import the supplied FBX with all 10 mesh names preserved.
-- This is NOT a layered-clothing or Marketplace-ready accessory.
local CosmicArcade = {}
local pieces = {
    {name="CA_Head", target="Head", size=Vector3.new(2.394999981, 2.136141777, 1.704998136), offset=Vector3.new(0.000000000, 0.005858660, 0.222499400)},
    {name="CA_UpperTorso", target="UpperTorso", size=Vector3.new(2.753549814, 1.535567284, 2.737592220), offset=Vector3.new(0.000000000, 0.260785192, 0.192723960)},
    {name="CA_RightUpperArm", target="RightUpperArm", size=Vector3.new(1.116499305, 1.015200138, 1.075249672), offset=Vector3.new(0.000000119, 0.000000030, -0.006875172)},
    {name="CA_RightLowerArm", target="RightLowerArm", size=Vector3.new(0.993999958, 0.142035604, 1.013999939), offset=Vector3.new(0.000000000, 0.071779758, 0.000000015)},
    {name="CA_LeftUpperArm", target="LeftUpperArm", size=Vector3.new(1.116499424, 1.015200138, 1.075249672), offset=Vector3.new(0.000000119, 0.000000030, -0.006875172)},
    {name="CA_LeftLowerArm", target="LeftLowerArm", size=Vector3.new(0.993999958, 0.142035604, 1.013999939), offset=Vector3.new(0.000000000, 0.071779758, 0.000000015)},
    {name="CA_RightLowerLeg", target="RightLowerLeg", size=Vector3.new(1.171611309, 0.698252439, 1.246506691), offset=Vector3.new(0.000000000, 0.027937293, -0.005371600)},
    {name="CA_RightFoot", target="RightFoot", size=Vector3.new(1.195725083, 0.502739906, 1.332149982), offset=Vector3.new(0.009362519, 0.011970282, -0.050825015)},
    {name="CA_LeftLowerLeg", target="LeftLowerLeg", size=Vector3.new(1.171611309, 0.698252439, 1.246506691), offset=Vector3.new(0.000000000, 0.027937293, -0.005371600)},
    {name="CA_LeftFoot", target="LeftFoot", size=Vector3.new(1.195725083, 0.502739906, 1.332149982), offset=Vector3.new(-0.009362519, 0.011970282, -0.050825015)},
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
function CosmicArcade.Attach(character, template)
    validate(character, template)
    assert(not character:FindFirstChild("CosmicArcade_Outfit"), "Character already has this outfit")
    local outfit = Instance.new("Model")
    outfit.Name = "CosmicArcade_Outfit"
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
        weld.Name = "CosmicArcadeMount"
        weld.Part0 = target
        weld.Part1 = piece
        weld.Parent = piece
    end
    outfit.Parent = character
    return outfit
end

-- Creates a separate static fitting copy. Original character is untouched.
-- Does not save, publish, start a playtest, or alter scripts on the original.
function CosmicArcade.CreatePreview(character, template, offset)
    validate(character, template)
    assert(character.Archivable, "Character must be Archivable before cloning")
    local clone = character:Clone()
    assert(clone, "Could not clone character")
    clone.Name = "CharacterRig_CosmicArcade_PREVIEW"
    for _, item in ipairs(clone:GetDescendants()) do
        if item:IsA("BaseScript") or item:IsA("ModuleScript") then
            item:Destroy()
        end
    end
    local root = clone:FindFirstChild("HumanoidRootPart")
    if root then root.Anchored = true end
    clone:PivotTo(character:GetPivot() * (offset or CFrame.new(6,0,0)))
    CosmicArcade.Attach(clone, template)
    clone.Parent = character.Parent
    return clone
end

return CosmicArcade
