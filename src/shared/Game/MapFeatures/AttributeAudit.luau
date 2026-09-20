-- Engine-side authoring preflight. Invalid feature configuration is returned as
-- errors; harmless stale attributes are returned as warnings and do not block
-- tagging or activation.
--!strict
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Config.Gameplay.MapFeatures)
local Rules = require(script.Parent.AttributeRules)
local Liquid = require(script.Parent.RisingLiquid)
local Audit = {}
local metadata = {
	SourceAsset = true,
	CheckpointCount = true,
	CriticalRoute = true,
}
local rotatingMarkers =
	{ "Rotor", "Fan", "FanBlade", "Bumper", "BigBall", "BeachBall", "Conveyor", "FallingTile", "Seesaw" }
local function emitWarnings(warnings: { string })
	for _, message in warnings do
		warn("[AttributeAudit] " .. message)
	end
end

-- Activation-only scan. Legacy Arena geometry and the strict Splashdown rotor
-- contract stay in their existing audit paths.
function Audit.checkFeatureValues(root: Instance): { string }
	local errors = {}
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, instance in all do
		for key, value in instance:GetAttributes() do
			if Rules.isFeatureValueKey(key) then
				local reason = Rules.checkPresentValue(instance:GetFullName(), key, value)
				if reason then
					table.insert(errors, reason)
				end
			end
		end
	end
	return errors
end

function Audit.check(root: Instance, extraMetadata: { [string]: boolean }?): ({ string }, { string })
	local allowed = table.clone(metadata)
	for key, value in extraMetadata or {} do
		allowed[key] = value
	end
	local errors = {}
	local warnings = {}
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, part in all do
		local a = part:GetAttributes()
		local function fail(message: string)
			table.insert(errors, part:GetFullName() .. ": " .. message)
		end
		local ruleErrors, ruleWarnings = Rules.validate(a, Config.Attributes, allowed, part:GetFullName())
		for _, message in ruleErrors do
			table.insert(errors, message)
		end
		for _, message in ruleWarnings do
			table.insert(warnings, part:GetFullName() .. ": " .. message)
		end
		if a.ScriptableRoot ~= nil then
			fail("ScriptableRoot must be a CollectionService tag, not a boolean attribute")
		end
		local assembly = part:FindFirstAncestor("Assembly")
		local group = assembly and assembly.Parent
		local origin = group and group:FindFirstChild("Origin")
		local model = part:FindFirstAncestorOfClass("Model")
		local modelIsMoving = model ~= nil
		local motionOwner = if modelIsMoving then model else assembly
		local metadataOwner = if modelIsMoving then model else origin
		if part.Name == "Origin" and part.Parent and part.Parent:FindFirstChild("Assembly") then
			if a.RotationSpeed ~= 0 then
				fail("course Origins use RotationSpeed=0; put motion on attribute Rotors")
			end
		end
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
			if not motionOwner then
				fail("motion marker is not beneath a discoverable rotating assembly")
			elseif modelIsMoving and model ~= root and not model:IsDescendantOf(root) then
				fail("moving model is outside the audited root")
			elseif
				not modelIsMoving
				and (not assembly or not assembly:IsA("Model") or not origin or not origin:IsA("BasePart"))
			then
				fail("missing Rotating/<group>/Origin + Assembly")
			end
			if part:IsA("BasePart") and not part.Anchored then
				fail("author parts anchored; BeachBall unanchors at runtime")
			end
		end
		if a.RotorCarries or a.Seesaw then
			if not metadataOwner or metadataOwner:GetAttribute("ServerCarries") ~= true then
				fail("course rides require ServerCarries=true on the moving model or legacy Origin")
			end
		end
		if
			a.RotorAccel
			and a.RotorAccel ~= 0
			and (not metadataOwner or typeof(metadataOwner:GetAttribute("MotionEpoch")) ~= "number")
		then
			fail("accelerating rotors require synchronized MotionEpoch on the moving model or legacy Origin")
		end
		if a.Seesaw and metadataOwner and metadataOwner:GetAttribute("RotationSpeed") ~= 0 then
			fail("Seesaw requires a stationary moving model or legacy Origin")
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
	emitWarnings(warnings)
	return errors, warnings
end

local canonicalRoots = {
	Motion = true,
	Conveyors = true,
	Fans = true,
	Bumpers = true,
	BigBalls = true,
	FallingTiles = true,
	Seesaws = true,
	BeachBalls = true,
	Static = true,
	Doors = true,
	JumpPads = true,
}

local markerRoots = {
	Rotor = "Motion",
	Fan = "Fans",
	FanBlade = "Fans",
	Conveyor = "Conveyors",
	Bumper = "Bumpers",
	BigBall = "BigBalls",
	FallingTile = "FallingTiles",
	Seesaw = "Seesaws",
	BeachBall = "BeachBalls",
}

local legacyLiquidAttributes = {
	RiseStuds = true,
	RiseDelaySeconds = true,
	RiseSeconds = true,
}

local splashdownLegacyAttributes = table.clone(metadata)
for key in legacyLiquidAttributes do
	splashdownLegacyAttributes[key] = true
end
splashdownLegacyAttributes.RotationSpeed = true
splashdownLegacyAttributes.ServerCarries = true

-- Published course templates carry display/timing metadata alongside the
-- active Splashdown config. It is valid only on the course model itself.
local splashdownCourseMetadata = table.clone(splashdownLegacyAttributes)
splashdownCourseMetadata.DisplayName = true
splashdownCourseMetadata.CapSeconds = true
splashdownCourseMetadata.CloseWindowSeconds = true

local function finiteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function canonicalRotorErrors(part: Instance, attributes: { [string]: any }, fail: (string) -> ())
	if attributes.Rotor == nil then
		return
	end
	if not part:IsA("BasePart") then
		fail("Rotor must be authored on a BasePart")
		return
	end
	if attributes.RotorAxis ~= "X" and attributes.RotorAxis ~= "Y" and attributes.RotorAxis ~= "Z" then
		fail("RotorAxis is required and must be X, Y, or Z")
	end
	-- Spin is speed driven, and a piston uses PistonPeriod. Any optional
	-- RotorPeriod still has to satisfy the runtime's minimum period.
	if
		(attributes.RotorPeriod ~= nil or (attributes.Rotor ~= "spin" and attributes.RotorProfile ~= "piston"))
		and (not finiteNumber(attributes.RotorPeriod) or attributes.RotorPeriod < 0.05)
	then
		fail("RotorPeriod is required when used and must be a finite number at least 0.05")
	end
	if attributes.Rotor == "spin" then
		if not finiteNumber(attributes.RotorSpeed) then
			fail("RotorSpeed is required for spin rotors")
		end
	elseif attributes.RotorProfile ~= "piston" and not finiteNumber(attributes.RotorAmplitude) then
		fail("RotorAmplitude is required for rock and slide rotors")
	end
	if attributes.RotorProfile == "hammer" then
		if not finiteNumber(attributes.WindupSeconds) or attributes.WindupSeconds <= 0 then
			fail("WindupSeconds is required for hammer rotors")
		end
		if not finiteNumber(attributes.StrikeSeconds) or attributes.StrikeSeconds <= 0 then
			fail("StrikeSeconds is required for hammer rotors")
		end
	elseif attributes.RotorProfile == "piston" then
		if not finiteNumber(attributes.PistonPeriod) or attributes.PistonPeriod < 0.1 then
			fail("PistonPeriod is required for piston rotors and must be at least 0.1")
		end
		if not finiteNumber(attributes.PistonExtendStuds) or attributes.PistonExtendStuds <= 0 then
			fail("PistonExtendStuds is required for piston rotors")
		end
	end
end

-- Strict Splashdown-only audit. Arena's old Origin/Assembly contract is
-- intentionally kept in check() until the Arena assets are migrated.
function Audit.checkSplashdownCourse(course: Instance, definition: { [string]: any }): ({ string }, { string })
	local errors = {}
	local warnings = {}
	local function fail(instance: Instance, message: string)
		table.insert(errors, instance:GetFullName() .. ": " .. message)
	end
	local function warning(instance: Instance, message: string)
		table.insert(warnings, instance:GetFullName() .. ": " .. message)
	end
	local function checkAttributes(instance: Instance)
		local attributes = instance:GetAttributes()
		local ruleErrors, ruleWarnings = Rules.validate(
			attributes,
			Config.Attributes,
			if instance == course then splashdownCourseMetadata else splashdownLegacyAttributes,
			instance:GetFullName()
		)
		for _, message in ruleErrors do
			table.insert(errors, message)
		end
		for _, message in ruleWarnings do
			warning(instance, message)
		end
		for key in legacyLiquidAttributes do
			if attributes[key] ~= nil then
				warning(instance, key .. " is obsolete; remove it and use the explicit Splashdown liquid schema")
			end
		end
		if attributes.RotationSpeed ~= nil or attributes.ServerCarries ~= nil then
			warning(instance, "Arena legacy motion metadata is stale in Splashdown and is ignored")
		end
		if instance == course then
			if
				attributes.DisplayName ~= nil
				and (typeof(attributes.DisplayName) ~= "string" or attributes.DisplayName == "")
			then
				fail(instance, "DisplayName must be a nonempty string")
			end
			if
				attributes.CapSeconds ~= nil and (not finiteNumber(attributes.CapSeconds) or attributes.CapSeconds <= 0)
			then
				fail(instance, "CapSeconds must be a positive finite number")
			end
			if
				attributes.CloseWindowSeconds ~= nil
				and (not finiteNumber(attributes.CloseWindowSeconds) or attributes.CloseWindowSeconds < 0)
			then
				fail(instance, "CloseWindowSeconds must be a nonnegative finite number")
			end
		end
	end

	local scriptables = course:FindFirstChild("Scriptables")
	if not scriptables or not scriptables:IsA("Folder") then
		fail(course, "Scriptables folder is required")
		emitWarnings(warnings)
		return errors, warnings
	end
	for _, child in scriptables:GetChildren() do
		if not child:IsA("Folder") or not canonicalRoots[child.Name] then
			fail(child, "unknown or legacy Scriptables root; use a canonical feature root")
		end
	end

	local all = course:GetDescendants()
	table.insert(all, course)
	for _, instance in all do
		checkAttributes(instance)
		if instance:IsA("BasePart") and instance:IsDescendantOf(scriptables) and not instance.Anchored then
			fail(instance, "authored feature parts must be anchored")
		end
		if instance:IsDescendantOf(scriptables) and (instance.Name == "Origin" or instance.Name == "Assembly") then
			fail(instance, "Origin/Assembly wrappers are not allowed under Splashdown Scriptables")
		end
		if instance:IsA("BasePart") or instance:IsA("Model") then
			local attributes = instance:GetAttributes()
			if attributes.Seesaw == true then
				if not instance:IsA("BasePart") then
					fail(instance, "Seesaw marker belongs on the plank BasePart")
				elseif not instance.Parent or not instance.Parent:IsA("BasePart") or not instance.Parent.Anchored then
					fail(instance, "Seesaw plank requires an anchored BasePart pedestal parent")
				end
				if attributes.SeesawAxis ~= "X" then
					fail(instance, "SeesawAxis must be X for the authored plank axle")
				end
			end
			canonicalRotorErrors(instance, attributes, function(message)
				fail(instance, message)
			end)
			for marker, rootName in markerRoots do
				if attributes[marker] ~= true then
					continue
				end
				local owner: Instance? = instance
				while owner and owner.Parent ~= scriptables do
					owner = owner.Parent
				end
				if not owner or owner.Name ~= rootName then
					fail(instance, marker .. " belongs under Scriptables/" .. rootName)
				end
			end
		end
	end

	local hazards = course:FindFirstChild("Hazards")
	local rising = {}
	if hazards then
		for _, instance in hazards:GetDescendants() do
			if instance:IsA("BasePart") and instance:GetAttribute("RisingLiquid") == true then
				table.insert(rising, instance)
			end
		end
	end
	if definition.LavaRise == nil then
		if #rising > 0 then
			for _, instance in rising do
				fail(instance, "RisingLiquid is not allowed on a course without LavaRise configuration")
			end
		end
	elseif #rising ~= 1 then
		fail(hazards or course, "configured LavaRise requires exactly one Hazards part with RisingLiquid=true")
	else
		local liquid = rising[1]
		local ok, reason = pcall(Liquid.resolve, liquid:GetAttributes())
		if not ok then
			fail(liquid, tostring(reason))
		end
	end
	emitWarnings(warnings)
	return errors, warnings
end

return Audit
