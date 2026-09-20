-- Declarative course preflight; reports invalid feature configuration as errors
-- and harmless unknown attributes as warnings instead of stopping gameplay.
--!strict
local Rules = {}
local booleans = {
	RotorCarries = true,
	ServerCarries = true,
	Shove = true,
	Bumper = true,
	Fan = true,
	FanBlade = true,
	JumpPad = true,
	BeachBall = true,
	BigBall = true,
	Conveyor = true,
	FallingTile = true,
	Seesaw = true,
	ImpactVisual = true,
	RisingLiquid = true,
	ScriptableRoot = true,
}
local strings = {
	Rotor = true,
	RotorProfile = true,
	PauseWaypoints = true,
	ShoveContact = true,
}
local positive = {
	RotorPeriod = true,
	PistonPeriod = true,
	WindupSeconds = true,
	StrikeSeconds = true,
	RiseStudsPerSecond = true,
	MaxHeight = true,
}
local nonnegative = { HoldSeconds = true, PistonExtendStuds = true, StartDelaySeconds = true }

type Bounds = { min: number, max: number }
local numericBounds: { [string]: Bounds } = {
	CapDegrees = { min = 10, max = 80 },
	RetriggerCooldown = { min = 0.1, max = 10 },
	BounceSpeed = { min = 1, max = 160 },
	FloatFactor = { min = 0, max = 0.9 },
	RollOffSpeed = { min = 8, max = 80 },
	ShoveSeconds = { min = 0.08, max = 0.4 },
	GuardSeconds = { min = 0.3, max = 10 },
	ConveyorSpeed = { min = -80, max = 80 },
	RespawnSeconds = { min = 0, max = 120 },
	DropDelaySeconds = { min = 0.1, max = 10 },
	FanDirection = { min = -1, max = 1 },
	FanColumnHeight = { min = 1, max = 100 },
	FanBallSpeed = { min = 0, max = 80 },
	LaunchSpeed = { min = 1, max = 160 },
	MaxTiltDegrees = { min = 1, max = 85 },
	SeesawResponse = { min = 0.1, max = 10 },
}
local axisKeys = { RotorAxis = true, FanAxis = true, ConveyorAxis = true, SeesawAxis = true }

function Rules.isFeatureValueKey(key: string): boolean
	return numericBounds[key] ~= nil or axisKeys[key] == true
end

-- The caller owns optionality. A present authored override must not be
-- replaced by its configured default after a failed type or range check.
function Rules.checkPresentValue(instancePath: string, key: string, value: any): string?
	local path = if instancePath == "" then key else `{instancePath}.{key}`
	if value == nil then
		error(`[AttributeRules] {path}: checkPresentValue requires a present value`, 2)
	end
	local bounds = numericBounds[key]
	if bounds then
		local permitted = if key == "FanDirection" then "-1 or 1" else `{bounds.min}..{bounds.max}`
		if
			typeof(value) ~= "number"
			or value ~= value
			or math.abs(value) == math.huge
			or value < bounds.min
			or value > bounds.max
			or (key == "FanDirection" and value ~= -1 and value ~= 1)
		then
			return `{path}: received {tostring(value)} ({typeof(value)}); expected finite number {permitted}; set {key} to {permitted} or remove the optional override`
		end
		return nil
	end
	if axisKeys[key] then
		local permitted = if key == "SeesawAxis" then "X or Z" else "X, Y, or Z"
		if value ~= "X" and value ~= "Z" and (key == "SeesawAxis" or value ~= "Y") then
			return `{path}: received {tostring(value)} ({typeof(value)}); expected {permitted}; set {key} to {permitted} or remove the optional override`
		end
		return nil
	end
	error(`[AttributeRules] {path}: unregistered feature override key; declare its rule before reading it`, 2)
end

function Rules.validate(
	a: { [string]: any },
	registered: { [string]: string },
	metadata: { [string]: boolean }?,
	instancePath: string?
): ({ string }, { string })
	local errors = {}
	local warnings = {}
	local known = {}
	for _, key in registered do
		known[key] = true
	end
	local function fail(message: string)
		table.insert(errors, if instancePath then `{instancePath}: {message}` else message)
	end
	for key, value in a do
		if not known[key] then
			if not (metadata and metadata[key]) then
				table.insert(warnings, "unknown attribute " .. key)
			end
		elseif Rules.isFeatureValueKey(key) then
			local reason = Rules.checkPresentValue(instancePath or "", key, value)
			if reason then
				table.insert(errors, reason)
			end
		elseif booleans[key] then
			if typeof(value) ~= "boolean" then
				fail(key .. " must be boolean")
			end
		elseif strings[key] then
			if typeof(value) ~= "string" then
				fail(key .. " must be a string")
			end
		elseif typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
			fail(key .. " must be finite numeric")
		elseif positive[key] and value <= 0 then
			fail(key .. " must be positive")
		elseif nonnegative[key] and value < 0 then
			fail(key .. " must not be negative")
		end
	end
	if a.Rotor ~= nil and a.Rotor ~= "spin" and a.Rotor ~= "rock" and a.Rotor ~= "slide" then
		fail("invalid Rotor mode")
	end
	if a.RotorProfile ~= nil then
		if
			not (
				(a.RotorProfile == "hammer" and a.Rotor == "rock")
				or (a.RotorProfile == "piston" and a.Rotor == "slide")
			)
		then
			fail("RotorProfile requires its matching mode")
		end
	end
	if a.Shove == true and not a.Rotor then
		fail("Shove requires Rotor")
	end
	if a.ShoveContact ~= nil and a.ShoveContact ~= "mesh" then
		fail("ShoveContact must be mesh or omitted")
	end
	if a.RotorCarries == true and not a.Rotor then
		fail("RotorCarries requires Rotor")
	end
	if a.RotorAccel ~= nil and a.Rotor ~= "spin" then
		fail("RotorAccel requires spin")
	end
	if a.Rotor and (a.FallingTile or a.Seesaw or a.BeachBall or a.Conveyor) then
		fail("conflicting motion owners")
	end
	if a.BigBall and (a.BeachBall or a.Bumper) then
		fail("conflicting ball contact kits")
	end
	local primaryCount = 0
	for _, key in { "Bumper", "Fan", "BigBall", "BeachBall", "Conveyor", "FallingTile", "Seesaw" } do
		if a[key] == true then
			primaryCount += 1
		end
	end
	if primaryCount > 1 then
		fail("multiple contact/state kits on one part")
	end
	if a.Shove and (a.Bumper or a.BigBall) then
		fail("two shove owners on one part")
	end
	if a.FallingTile and a.Seesaw then
		fail("conflicting stateful supports")
	end
	if typeof(a.HoldSeconds) == "number" and typeof(a.PistonPeriod) == "number" and a.HoldSeconds >= a.PistonPeriod then
		fail("piston hold must leave travel time")
	end
	for _, key in { "DoorRow", "DoorIndex" } do
		local v = a[key]
		if v ~= nil and (typeof(v) ~= "number" or v < 1 or v % 1 ~= 0) then
			fail(key .. " must be a positive integer")
		end
	end
	if (a.DoorRow == nil) ~= (a.DoorIndex == nil) then
		fail("DoorRow and DoorIndex must be paired")
	end
	return errors, warnings
end
return Rules
