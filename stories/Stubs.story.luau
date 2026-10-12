--[[
    The shared fixtures every story draws from (stories/Fixtures.luau), laid out as plain data cards
    so a reviewer can see exactly what the screens are fed before judging a screen: the eight
    players, one real catalog cosmetic per rarity (with its RarityRibbon), the quest board in each
    state, the daily strip, the season projection and its reward entries, the arena ballot (three
    modes, CANDY BOWL / BAMBOO ISLE and the long third map), the Splashdown course rotation, the
    post-match scenarios and the shop cards the economy fixture builds.

    The cards are story chrome (plain ink text on cream); only the rarity ribbons are the real
    component. Nothing talks to the game.
]]

local StoryRoot = require(script.Parent.StoryRoot)
local Fixtures = require(script.Parent.Fixtures)

local React = StoryRoot.React
local T = StoryRoot.Tokens
local RarityRibbon = require(StoryRoot.Components:WaitForChild("RarityRibbon"))

local c = React.createElement
local C = T.Colors

local CARD = Vector2.new(420, 360)
local ROW = 24

local function Card(props: { Rows: { string }, Ribbons: { string }? })
	local children: { [string]: any } = {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
		Stroke = c("UIStroke", { Color = C.Ink, Thickness = T.Shape.StrokeInner }),
		Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 12),
		}),
		Layout = c("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, line in props.Rows do
		local rarity = props.Ribbons and props.Ribbons[index]
		children[`Row{index}`] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ROW),
		}, {
			Ribbon = if rarity
				then c(RarityRibbon, {
					Rarity = rarity,
					TextSize = 14,
					Native = { Size = UDim2.fromOffset(104, ROW - 2) },
				})
				else nil,
			Text = StoryRoot.Text({
				Position = UDim2.fromOffset(if rarity then 112 else 0, 0),
				Size = UDim2.new(1, if rarity then -112 else 0, 1, 0),
				Text = line,
				TextSize = 15,
			}),
		})
	end
	return c("Frame", { BackgroundColor3 = C.SurfaceWarm, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, children)
end

--> Built during render, inside the stage's error boundary, so a broken fixture shows in its card.
local function Lazy(props: { Build: () -> ({ string }, { string }?) })
	local rows, ribbons = props.Build()
	return c(Card, { Rows = rows, Ribbons = ribbons })
end

local function state(name: string, note: string, build: () -> ({ string }, { string }?), size: Vector2?)
	return { Name = name, Note = note, Size = size or CARD, Element = c(Lazy, { Build = build }) }
end

local function players()
	local rows = {}
	for _, player in Fixtures.Players do
		table.insert(
			rows,
			`#{player.userId}  {player.displayName}  · {player.teamId} · {player.score} elims{if player.alive
				then ""
				else " · down"}`
		)
	end
	return rows
end

local function cosmetics()
	local rows, ribbons = {}, {}
	for _, entry in Fixtures.rarityRow() do
		table.insert(rows, `{entry.displayName} ({entry.category})`)
		table.insert(ribbons, entry.rarity)
	end
	return rows, ribbons
end

local function quests()
	local rows = {}
	for _, kind in { "Mixed", "AllClaimable", "AllClaimed", "Empty" } do
		local board = Fixtures.quests(kind)
		table.insert(rows, `{string.upper(kind)}: {#board.quests} quests`)
		for _, quest in board.quests do
			if kind == "Mixed" then
				table.insert(
					rows,
					`   {quest.title} {quest.progress}/{quest.goal}{if quest.claimed then " ✓" else ""} · {quest.reward.amount}`
				)
			end
		end
	end
	return rows
end

local function daily()
	local rows = {}
	local strip = Fixtures.daily(4, 3)
	table.insert(rows, `DAY {strip.currentDay} · claimed through {strip.totalClaimed} · canClaim {strip.canClaim}`)
	for _, day in strip.days do
		table.insert(
			rows,
			`   day {day.day}: {day.reward.amount} bonks{if day.claimed
				then " ✓"
				elseif day.available then " ← claim"
				else ""}`
		)
	end
	return rows
end

local function season()
	local projection = Fixtures.season()
	local entries = Fixtures.seasonEntries()
	local claimable = 0
	for _, entry in entries do
		if entry.claimable then
			claimable += 1
		end
	end
	return {
		projection.displayName,
		`tier {projection.tier} / {projection.tierCount} · {projection.xpIntoTier}/{projection.xpForNextTier} XP`,
		`premium: {projection.hasPremium}`,
		`{#projection.tiers} tiers projected · {#entries} reward entries · {claimable} claimable`,
		`card: {Fixtures.SeasonCard.id} · R$ {Fixtures.SeasonCard.robuxPrice}`,
	}
end

local function ballot()
	local rows = {}
	for _, mode in Fixtures.ballotModes("TDM") do
		table.insert(rows, `MODE {mode.Title} · {mode.VoteCount} votes{if mode.Selected then " ← you" else ""}`)
	end
	for _, map in Fixtures.ballotMaps(3, "Bowl") or {} do
		table.insert(rows, `MAP {map.Title} ({map.ShortName}){if map.Selected then " ← you" else ""}`)
	end
	return rows
end

local function courses()
	local rows = {}
	for index, course in Fixtures.courses() do
		table.insert(rows, `{index}. {course.DisplayName} ({course.Id})`)
	end
	return rows
end

local function results()
	local rows = {}
	for _, scenario in Fixtures.postMatchScenarios() do
		table.insert(rows, scenario.name)
	end
	return rows
end

local function shop()
	local model = Fixtures.economy("Ready")
	local rows = {}
	local ids = {}
	for id in model.byId do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		table.insert(rows, id)
	end
	return rows
end

return StoryRoot.story({
	Title = "Stubs",
	Summary = "The data every story is fed (stories/Fixtures.luau). Change it here once; every screen story follows.",
	States = {
		state("Players", "Fixtures.Players — local player is #1", players),
		state("Cosmetics", "Fixtures.rarityRow() — real catalog items", cosmetics),
		state("Quests", "Fixtures.quests(state)", quests),
		state("Daily rewards", "Fixtures.daily(4, 3)", daily),
		state("Season", "Fixtures.season() / seasonEntries()", season),
		state("Ballot", "Fixtures.ballotModes / ballotMaps", ballot),
		state("Splashdown courses", "Fixtures.courses() — live CourseOrder", courses),
		state("Post-match scenarios", "Fixtures.postMatchScenarios()", results, Vector2.new(CARD.X, 820)),
		state("Shop cards", "Fixtures.economy('Ready').byId", shop, Vector2.new(CARD.X, 640)),
	},
})
