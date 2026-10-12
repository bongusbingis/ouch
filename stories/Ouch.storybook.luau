--[[
    Tells UI Labs where the Ouch! UI stories live: this folder (repo `stories/`, mapped by both place
    projects to ServerStorage.UIStories so it reaches Studio but never a client). Folders under it
    -- Primitives, Lobby, Arena -- show as groups in the UI Labs explorer; Index.story lists them all.
]]

return {
	name = "Ouch! UI",
	storyRoots = { script.Parent },
}
