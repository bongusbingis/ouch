-- Checks local release inputs without publishing or changing authored place files.
--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Loader = require("./loader")
local result = process.exec("rojo", { "sourcemap", "arena.project.json", "-o", "sourcemap.json" })
assert(result.ok, result.stderr)
local root, load = Loader.build("sourcemap.json")
local config = root.ReplicatedStorage.Config
local seasons = load(config.Progression.Seasons)
local modes = load(config.Gameplay.GameModes)
local failures = {}
local function check(ok: boolean, message: string)
	print((if ok then "PASS " else "BLOCKED ") .. message)
	if not ok then
		table.insert(failures, message)
	end
end
check(fs.isFile("wally.lock"), "Wally dependency lock is present")
local now = os.time()
local active = nil
for _, season in seasons.Definitions do
	if not season.Archived and now >= season.StartsAt and now < season.EndsAt then
		active = season
	end
end
check(active ~= nil, "A configured season is active at release time")
if active then
	print(
		`SEASON {active.Id} ends in {math.floor((active.EndsAt - now) / 86400)} days; preserve its paid identity when scheduling its successor`
	)
end
for _, place in { "arena", "lobby" } do
	local project = serde.decode("json", fs.readFile(place .. ".project.json"))
	check(#project.servePlaceIds == 1, place .. " has one explicit target place")
	check(
		project.tree.StarterGui["$properties"].ScreenOrientation == "LandscapeSensor",
		place .. " locks mobile to landscape"
	)
	local bases = {}
	for _, name in fs.readDir("places/" .. place) do
		if string.match(name, "%.rbxl$") then
			table.insert(bases, name)
		end
	end
	check(#bases == 1, place .. " has exactly one imported Studio-authored place base")
	if #bases == 1 then
		local bytes = fs.readFile("places/" .. place .. "/" .. bases[1])
		check(
			#bytes >= 10000 and string.sub(bytes, 1, 7) == "<roblox",
			place .. " base contains place data rather than an LFS pointer"
		)
	end
end
print(`ARENA capacity: {modes.MatchCapacity}; published place capacity and authored spawn contracts must match`)
check(
	type(process.env.ROBLOX_API_KEY) == "string" and process.env.ROBLOX_API_KEY ~= "",
	"Open Cloud deployment credentials are available"
)
print(
	"Platform billing, regional pricing, real teleports, and device/network load checks remain separate release evidence."
)
process.exit(if #failures == 0 then 0 else 1)
