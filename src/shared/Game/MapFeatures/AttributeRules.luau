-- Declarative course preflight; reports errors instead of silently defaulting typos.
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
	FoamPit = true,
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
	RotorAxis = true,
	RotorProfile = true,
	FanAxis = true,
	ConveyorAxis = true,
	SeesawAxis = true,
	PauseWaypoints = true,
	ShoveContact = true,
}
local positive = {
	RotorPeriod = true,
	PistonPeriod = true,
	WindupSeconds = true,
	StrikeSeconds = true,
	LaunchSpeed = true,
	BounceSpeed = true,
	RollOffSpeed = true,
	RetriggerCooldown = true,
	GuardSeconds = true,
	DropDelaySeconds = true,
	SeesawResponse = true,
	RiseStudsPerSecond = true,
	MaxHeight = true,
}
local nonnegative = { HoldSeconds = true, PistonExtendStuds = true, RespawnSeconds = true, StartDelaySeconds = true }
function Rules.validate(
	a: { [string]: any },
	registered: { [string]: string },
	metadata: { [string]: boolean }?
): { string }
	local errors = {}
	local known = {}
	for _, key in registered do
		known[key] = true
	end
	local function fail(message: string)
		table.insert(errors, message)
	end
	for key, value in a do
		if not known[key] then
			if not (metadata and metadata[key]) then
				fail("unknown attribute " .. key)
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
	for _, key in { "RotorAxis", "FanAxis", "ConveyorAxis", "SeesawAxis" } do
		if a[key] ~= nil and a[key] ~= "X" and a[key] ~= "Y" and a[key] ~= "Z" then
			fail(key .. " must be X/Y/Z")
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
	if a.FanDirection ~= nil and a.FanDirection ~= 1 and a.FanDirection ~= -1 then
		fail("FanDirection must be +/-1")
	end
	if a.SeesawAxis == "Y" then
		fail("SeesawAxis must be X or Z")
	end
	if a.FloatFactor ~= nil and typeof(a.FloatFactor) == "number" and (a.FloatFactor < 0 or a.FloatFactor > 0.9) then
		fail("FloatFactor must be 0..0.9")
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
	return errors
end
return Rules
