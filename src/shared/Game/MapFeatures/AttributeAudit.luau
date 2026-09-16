-- Engine-side authoring preflight. Runtime keeps legacy names; new course builders
-- call this before tagging/activating a clone and fail on any returned error.
--!strict
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Config.Gameplay.MapFeatures)
local Rules = require(script.Parent.AttributeRules)
local Liquid = require(script.Parent.RisingLiquid)
local Audit = {}
local metadata = {
	SourceAsset = true,
	RotationSpeed = true,
	RiseStuds = true,
	RiseDelaySeconds = true,
	RiseSeconds = true,
	CheckpointCount = true,
	CriticalRoute = true,
}
local rotatingMarkers =
	{ "Rotor", "Fan", "FanBlade", "Bumper", "BigBall", "BeachBall", "Conveyor", "FallingTile", "Seesaw" }
function Audit.check(root: Instance, extraMetadata: { [string]: boolean }?): { string }
	local allowed = table.clone(metadata)
	for key, value in extraMetadata or {} do
		allowed[key] = value
	end
	local errors = {}
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, part in all do
		local a = part:GetAttributes()
		local function fail(message: string)
			table.insert(errors, part:GetFullName() .. ": " .. message)
		end
		for _, message in Rules.validate(a, Config.Attributes, allowed) do
			fail(message)
		end
		if a.ScriptableRoot ~= nil then
			fail("ScriptableRoot must be a CollectionService tag, not a boolean attribute")
		end
		local assembly = part:FindFirstAncestor("Assembly")
		local group = assembly and assembly.Parent
		local origin = group and group:FindFirstChild("Origin")
		local rotating = false
		for _, key in rotatingMarkers do
			if a[key] then
				rotating = true
			end
		end
		if rotating then
			if not part:IsA("BasePart") then
				fail("rotating-folder markers require BaseParts")
			end
			if not assembly or not assembly:IsA("Model") or not origin or not origin:IsA("BasePart") then
				fail("missing Rotating/<group>/Origin + Assembly")
			end
			if part:IsA("BasePart") and not part.Anchored then
				fail("author parts anchored; BeachBall unanchors at runtime")
			end
		end
		if a.RotorCarries or a.Seesaw then
			if not origin or origin:GetAttribute("ServerCarries") ~= true then
				fail("course rides require ServerCarries=true on Origin")
			end
		end
		if
			a.RotorAccel
			and a.RotorAccel ~= 0
			and (not origin or typeof(origin:GetAttribute("MotionEpoch")) ~= "number")
		then
			fail("accelerating rotors require synchronized MotionEpoch on Origin")
		end
		if a.Seesaw and origin and origin:GetAttribute("RotationSpeed") ~= 0 then
			fail("Seesaw requires a stationary group Origin")
		end
		if a.Seesaw or a.BeachBall or a.Conveyor or a.FallingTile then
			local ancestor = part.Parent
			while ancestor and ancestor ~= assembly do
				if
					ancestor:GetAttribute("Rotor")
					or ancestor:GetAttribute("Seesaw")
					or ancestor:GetAttribute("FallingTile")
				then
					fail("stateful/physics support cannot also inherit a moving parent")
					break
				end
				ancestor = ancestor.Parent
			end
		end
		if a.JumpPad and (not part:IsA("Model") or not part.Parent or part.Parent.Name ~= "JumpPads") then
			fail("JumpPad model must be in Scriptables/JumpPads")
		end
		if a.FoamPit and (not part:IsA("BasePart") or not part.Parent or part.Parent.Name ~= "FoamPits") then
			fail("FoamPit volume must be in Scriptables/FoamPits")
		end
		if a.FallingTile and a.RespawnSeconds == 0 and a.CriticalRoute == true then
			fail("never-respawn tile would strand checkpoint runners")
		end
		if a.RisingLiquid then
			local ok, reason = pcall(Liquid.resolve, a)
			if not ok then
				fail(tostring(reason))
			end
		end
	end
	return errors
end
return Audit
