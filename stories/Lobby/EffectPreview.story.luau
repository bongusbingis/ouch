--[[
    CandyEffectPreview, the art for effect cosmetics that have no authored image: the candy effect
    seal (Explosion silhouette, ink outline, the effect's own two accent colours, pale core with the
    glyph in ink and two sparks), playing its hover animation. Shown at a Backpack card's art size
    for a spread of impact effects -- each EffectId picks its pair from T.Collectible.EffectAccent,
    so the row should read as a varied, intentional set -- plus the default impact and an
    elimination sound (cyan/yellow, equalizer animation).

    Migrated from CandyEffectPreview.story (current version: Definition { Icon = "Sparkle",
    EffectId = "Starlight" }; its Category attribute -> the impact / elimination states).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)

local React = StoryRoot.React
local CandyEffectPreview = require(StoryRoot.Components:WaitForChild("CandyEffectPreview"))

local c = React.createElement

local TILE = Vector2.new(180, 180)

local function preview(category: string, definition: { [string]: any }): any
	return c(CandyEffectPreview, {
		Category = category,
		Definition = definition,
		Playing = true,
		ZIndex = 1,
	})
end

local IMPACTS = {
	{ "Starlight", "Sparkle" },
	{ "Galaxy", "Sparkle" },
	{ "BubbleBurst", "Explosion" },
	{ "ConfettiImpact", "Explosion" },
	{ "JellySplash", "Explosion" },
	{ "Prismatic", "Sparkle" },
}

local states = {}
for _, entry in IMPACTS do
	table.insert(states, {
		Name = entry[1],
		Note = "Impact effect.",
		Size = TILE,
		Element = preview("ImpactEffectAssets", { Icon = entry[2], EffectId = entry[1] }),
	})
end
table.insert(states, {
	Name = "Default impact",
	Note = "No EffectId: DefaultImpact pair.",
	Size = TILE,
	Element = preview("ImpactEffectAssets", { Icon = "Explosion" }),
})
table.insert(states, {
	Name = "Elimination sound",
	Note = "Sound accent, equalizer.",
	Size = TILE,
	Element = preview("ElimEffectAssets", { Icon = "Sparkle" }),
})

return StoryRoot.story({
	Title = "Effect seals",
	Summary = "CandyEffectPreview for several impact effects, the default impact and an elimination sound.",
	States = states,
})
