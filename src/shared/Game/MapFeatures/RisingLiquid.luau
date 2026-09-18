-- Reusable course trajectory. Heights are stud offsets above the authored liquid.
--!strict
local Liquid = {}
export type Pause = { height: number, seconds: number }
export type Config = { studs: number, delaySeconds: number, seconds: number, pauses: { Pause }? }
function Liquid.parsePauses(text: string, maxHeight: number): { Pause }
	local pauses = {}
	local previous = -1
	for item in string.gmatch(text, "[^,]+") do
		local h, s = string.match(item, "^%s*([%d%.]+)%s*:%s*([%d%.]+)%s*$")
		local height, seconds = tonumber(h), tonumber(s)
		assert(
			height and seconds and height > previous and height >= 0 and height <= maxHeight and seconds >= 0,
			"[RisingLiquid] pauses must be increasing height:seconds pairs"
		)
		table.insert(pauses, { height = height, seconds = seconds })
		previous = height
	end
	return pauses
end
function Liquid.resolve(attributes: { [string]: any }): Config?
	if attributes.RisingLiquid == true then
		local height = attributes.MaxHeight
		local speed = attributes.RiseStudsPerSecond
		local delay = attributes.StartDelaySeconds or 0
		assert(
			typeof(height) == "number" and height > 0 and height < math.huge,
			"[RisingLiquid] positive finite MaxHeight required"
		)
		assert(
			typeof(speed) == "number" and speed > 0 and speed < math.huge,
			"[RisingLiquid] positive finite rise speed required"
		)
		assert(typeof(delay) == "number" and delay >= 0 and delay < math.huge, "[RisingLiquid] invalid start delay")
		return {
			studs = height,
			seconds = height / speed,
			delaySeconds = delay,
			pauses = Liquid.parsePauses(attributes.PauseWaypoints or "", height),
		}
	end
	-- Existing Summit attributes retain exactly their previous interpretation.
	local studs = tonumber(attributes.RiseStuds)
	if studs and studs > 0 then
		return {
			studs = studs,
			delaySeconds = tonumber(attributes.RiseDelaySeconds) or 0,
			seconds = math.max(tonumber(attributes.RiseSeconds) or 1, 1),
		}
	end
	return nil
end
function Liquid.heightAt(elapsed: number, config: Config): number
	local travel = math.max(elapsed, 0)
	local speed = config.studs / config.seconds
	for _, pause in config.pauses or {} do
		local reach = pause.height / speed
		if travel < reach then
			break
		end
		if travel < reach + pause.seconds then
			return pause.height
		end
		travel -= pause.seconds
	end
	return math.clamp(travel / config.seconds, 0, 1) * config.studs
end
return Liquid
