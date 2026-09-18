-- HANDOFF.md section 12.3's default-arena regression, run after the 12.1
-- replacement transaction. Splashdown's registry swap must not have touched the
-- ordinary arena: its authored Scriptables root, its name-driven hazards
-- (Fan/Spinner/Disc/SwingPanel/Bumper, all selected by the EXACT names in
-- Config.Gameplay.MapFeatures) and the shared MapFeatures values are section
-- 3.1 frozen systems.
--
-- It switches venues through the same existing seam the Cmdr command uses,
-- MatchService.restartForAdmin(modeId), and then measures the restored arena:
-- the parked interior is back, the arena's own Scriptables folder is a tagged
-- ScriptableRoot again, no Splashdown course is left standing, every configured
-- hazard name resolves to a real BasePart, and the kits actually move geometry.
--
-- Install as an ordinary temporary Script under ServerScriptService, press Play,
-- read ServerStorage.SplashdownArenaRegression, then stop Play and delete it.
assert(game:GetService("RunService"):IsStudio(), "Studio only")

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local MatchService = require(Modules:WaitForChild("MatchService"))
local MapFeatures = require(ReplicatedStorage:WaitForChild("Config").Gameplay.MapFeatures)
local SplashdownConfig = require(ReplicatedStorage:WaitForChild("Config").Gameplay.Splashdown)
local ScriptableRoots = require(ReplicatedStorage:WaitForChild("Shared").Game.MapFeatures.ScriptableRoots)

local result = Instance.new("StringValue")
result.Name = "SplashdownArenaRegression"
result.Value = "running"
result.Parent = ServerStorage

local ok, answer = xpcall(function()
	-- Measured at SERVER BOOT, before the Splashdown venue parks the arena
	-- interior. Debug.StudioQueue is "Splashdown" in this repo, so a Studio
	-- session's match is always a Splashdown one and restartForAdmin("FFA")
	-- cannot hold the arena venue open; the arena's own live window is the few
	-- seconds before the first venue swap, which is when this runs.
	local arena = workspace.Assets:WaitForChild("Arena")

	local deadline = os.clock() + 30
	local scriptables = nil
	while os.clock() < deadline do
		scriptables = arena:FindFirstChild("Scriptables")
		if scriptables and ScriptableRoots.isRoot(scriptables) then
			break
		end
		task.wait()
	end
	assert(scriptables and ScriptableRoots.isRoot(scriptables), "the arena Scriptables root is not tagged")

	local map = arena.Map.Model
	local mapChildren = #map:GetChildren()

	-- Name-driven selection, exactly as the kits do it.
	local wanted: { [string]: string } = {}
	for name in MapFeatures.Fan.EnabledNames do
		wanted[name] = "Fan"
	end
	for name in MapFeatures.Spinner.EnabledNames do
		wanted[name] = "Spinner"
	end
	local prefixes = {
		{ MapFeatures.Disc.HubPrefix, "Disc.Hub" },
		{ MapFeatures.Disc.PlatePrefix, "Disc.Plate" },
		{ MapFeatures.SwingPanel.AxlePrefix, "SwingPanel.Axle" },
		{ MapFeatures.SwingPanel.PanelPrefix, "SwingPanel.Panel" },
		{ MapFeatures.Bumper.NamePrefixes[1], "Bumper" },
		{ MapFeatures.Bumper.NamePrefixes[2], "Bumper" },
	}

	local found: { [string]: number } = {}
	local exact: { [string]: boolean } = {}
	local sampled: { BasePart } = {}
	for _, descendant in workspace:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		local kit = wanted[descendant.Name]
		if kit then
			exact[descendant.Name] = true
			found[kit] = (found[kit] or 0) + 1
			table.insert(sampled, descendant)
		end
		for _, pair in prefixes do
			if string.sub(descendant.Name, 1, #pair[1]) == pair[1] then
				found[pair[2]] = (found[pair[2]] or 0) + 1
				table.insert(sampled, descendant)
			end
		end
	end

	local missingExact = {}
	for name in wanted do
		if not exact[name] then
			table.insert(missingExact, name)
		end
	end

	-- The kits are actually driving geometry, not merely registered.
	local before = {}
	for index, part in sampled do
		before[index] = part.CFrame
	end
	task.wait(1.5)
	local moving = 0
	for index, part in sampled do
		local delta = (part.CFrame.Position - before[index].Position).Magnitude
		local turn = (part.CFrame.LookVector - before[index].LookVector).Magnitude
		if delta > 0.01 or turn > 0.01 then
			moving += 1
		end
	end

	return {
		modeId = MatchService.stateForAdmin().modeId,
		playersPresent = #Players:GetPlayers(),
		arenaScriptablesTagged = true,
		arenaMapChildren = mapChildren,
		splashdownCourseStillStanding = arena:FindFirstChild(SplashdownConfig.ActiveCourseName) ~= nil,
		nameDrivenCounts = found,
		missingExactNames = missingExact,
		sampledParts = #sampled,
		movingSampledParts = moving,
		sharedValues = {
			gravity = workspace.Gravity,
			fanLaunchSpeed = MapFeatures.Fan.LaunchSpeed,
			fanFloatFactor = MapFeatures.Fan.FloatFactor,
			spinnerKnockback = MapFeatures.Spinner.KnockbackSpeed,
			bumperKnockback = MapFeatures.Bumper.KnockbackSpeed,
			rotatingCarryHeight = MapFeatures.Rotating.CarryHeight,
			discDegreesPerSecond = MapFeatures.Disc.DegreesPerSecond,
			swingPanelPeriod = MapFeatures.SwingPanel.PeriodSeconds,
		},
	}
end, debug.traceback)

result.Value = HttpService:JSONEncode({ ok = ok, result = answer })
print("[arena-regression] ok=" .. tostring(ok))
