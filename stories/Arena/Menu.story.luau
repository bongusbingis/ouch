--[[
    The in-combat overlay menu (CombatMenu): the MENU toggle in the HUD, and when open, the TopBar
    with the Shop / Backpack / Settings pages and their modals, shared by the arena and the lobby's
    training session.

    Why: the menu is one component driven by a module-level store (CombatMenuClient), so it can
    only be mounted once at a time -- this story is a Switch: each state mounts the menu fresh,
    pre-navigates the store to a page and opens it, and closes it again on unmount.

    States
      Arena · Closed      just the MENU toggle at its HUD slot (Available, menu shut).
      Arena · Shop        open on the Shop page (shop view model from Fixtures.economy).
      Arena · Backpack    open on the Backpack (InventoryPage).
      Arena · Settings    open on Settings with the arena's setting list.
      Lobby · Settings    Place = "Lobby": the lobby's setting list (the old story's Place switch).
      Shop · Pending      the Shop with a crate purchase pending (Fixtures.economy("Pending")).

    The ShopClient is Fixtures.shopClient: reads work, every purchase returns "preview_only". The
    Backpack reads the controller's economy data (none in a story, so default items only). Escape /
    ButtonB close it; MENU re-opens. Screen frames because the menu lays out from the safe area.
]]

--!strict

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local CombatMenu = require(StoryRoot.Components:WaitForChild("CombatMenu"))
local CombatMenuClient = require(StoryRoot.UI:WaitForChild("Services"):WaitForChild("CombatMenuClient"))

local c = React.createElement

local function Menu(props: { Place: string, Page: string?, Economy: string? })
	local _, snapshot = Fixtures.economy(props.Economy)
	local client = React.useMemo(function()
		return Fixtures.shopClient(snapshot)
	end, {})

	-- Parent effects run after the menu's own (which marks it available), so open lands.
	React.useEffect(function()
		if props.Page then
			CombatMenuClient.navigate(props.Page :: any)
			CombatMenuClient.open()
		end
		return function()
			CombatMenuClient.close()
		end
	end, {})

	return c(CombatMenu, {
		Available = true,
		Place = props.Place,
		ShopClient = client,
	})
end

local function state(name: string, note: string, props: { [string]: any }): StoryRoot.State
	return { Name = name, Note = note, Screen = true, Element = c(Menu, props) }
end

return StoryRoot.story({
	Title = "Combat Menu",
	Summary = "CombatMenu in the arena and lobby: closed toggle, then open on Shop / Backpack / Settings. "
		.. "One at a time (it shares one store).",
	Mode = "Switch",
	States = {
		state("Arena · Closed", "MENU toggle only", { Place = "Arena" }),
		state("Arena · Shop", "Open on Shop", { Place = "Arena", Page = "Shop" }),
		state("Arena · Backpack", "Open on Backpack", { Place = "Arena", Page = "Inventory" }),
		state("Arena · Settings", "Arena setting list", { Place = "Arena", Page = "Settings" }),
		state("Lobby · Settings", "Place = Lobby", { Place = "Lobby", Page = "Settings" }),
		state("Shop · Pending", "Crate purchase pending", { Place = "Arena", Page = "Shop", Economy = "Pending" }),
	},
})
