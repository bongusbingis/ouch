--!strict

-- Scores which enemy a tap meant. Pure: the caller does the projection, the
-- visibility raycast, and the team filtering, then hands over plain numbers.
--
-- The selection radius scales with how large the target actually appears, not a
-- flat pixel count, so a distant enemy needs a more accurate tap than one
-- filling the screen. World distance carries a small weight so a far enemy does
-- not beat a near one purely for being closer to the finger.
--
-- This chooses among targets the player pointed at. It does not choose a target
-- for them: with no candidate under the tap it returns nothing and the throw
-- goes where the camera was aimed.

local TapTarget = {}

export type Candidate = {
	id: string,
	screenX: number,
	screenY: number,
	-- On-screen height of the character in pixels, which stands in for how big
	-- a tap target it is.
	apparentHeightPixels: number,
	worldDistance: number,
}

export type Settings = {
	RadiusScale: number,
	MinRadiusPixels: number,
	MaxRadiusPixels: number,
	WorldDistanceWeight: number,
}

function TapTarget.radiusFor(candidate: Candidate, settings: Settings): number
	return math.clamp(
		candidate.apparentHeightPixels * settings.RadiusScale,
		settings.MinRadiusPixels,
		settings.MaxRadiusPixels
	)
end

-- Returns the chosen candidate id, or nil when the tap landed near nothing.
function TapTarget.pick(
	candidates: { Candidate },
	tapX: number,
	tapY: number,
	maxWorldDistance: number,
	settings: Settings
): string?
	local best: string? = nil
	local bestScore = math.huge

	for _, candidate in candidates do
		local dx = candidate.screenX - tapX
		local dy = candidate.screenY - tapY
		local screenDistance = math.sqrt(dx * dx + dy * dy)
		local radius = TapTarget.radiusFor(candidate, settings)
		if screenDistance > radius then
			continue
		end

		local nearness = screenDistance / radius
		local range = if maxWorldDistance > 0 then math.min(candidate.worldDistance / maxWorldDistance, 1) else 0
		local score = nearness + settings.WorldDistanceWeight * range
		if score < bestScore then
			best = candidate.id
			bestScore = score
		end
	end
	return best
end

return table.freeze(TapTarget)
