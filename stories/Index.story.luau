--[[
    The table of contents: every story in this storybook, grouped by surface (Primitives, Lobby,
    Arena, and the root Index/Stubs), each with the one line that says what it shows. The list is
    read from the storybook folder itself (every ModuleScript named *.story), so a new story shows
    up here automatically; its line comes from SUMMARIES below and reads "(no summary yet)" until
    one is added -- that gap is the reminder.

    One card per group, at reading size. Pure story chrome; nothing renders a game component.
]]

local StoryRoot = require(script.Parent.StoryRoot)

local React = StoryRoot.React
local T = StoryRoot.Tokens

local c = React.createElement
local C = T.Colors

local ROW = 44
local WIDTH = 620

--> "Group/Name" -> one line. Keep in step with each story's header comment.
local SUMMARIES: { [string]: string } = {
	["Index"] = "This page: every story, grouped by surface.",
	["Stubs"] = "The shared fixture data every story is fed.",

	["Primitives/Badges"] = "Badge stickers (check, slot, NEW!, lock, colours) and the Bonks chip / label.",
	["Primitives/Buttons"] = "PuffyButton in every candy colour, AnimatedButton, ModalClose, shop price and arena action buttons.",
	["Primitives/Collectibles"] = "The collectible card: every rarity, tile states, art kinds and desktop / compact / portrait sizes.",
	["Primitives/Progress"] = "CandyProgressBar, OuchProgressBar, the ballot countdown bar and activity dots.",
	["Primitives/RarityRibbons"] = "The puffy rarity tag for every rarity plus odds / OWNED / NEW product labels.",
	["Primitives/Surfaces"] = "CandySurface, CandyPanel, OuchPanel, PanelFrame, CandyTitle and the arena HUD surfaces.",
	["Primitives/Tabs"] = "TabPill states and the real Backpack tab row.",
	["Primitives/Text"] = "Type scale, text components, section headers and the Tokens palette.",
	["Primitives/Wells"] = "Recessed wells and scrolling wells with overflowing content.",

	["Lobby/Backpack"] = "InventoryPage on each tab with live equip.",
	["Lobby/CrateReveal"] = "Crate reveal: single new / dupe, batch, pity and open-again.",
	["Lobby/EconomyMenuModals"] = "Crate details → buy with Bonks → reveal → close, on a stub controller.",
	["Lobby/EffectPreview"] = "CandyEffectPreview effect seals for impact and elimination effects.",
	["Lobby/EmoteLoadout"] = "The Backpack emote wheel: radial, compact grid, pending and error.",
	["Lobby/Loading"] = "Lobby loading / teleport screen: roster, teleporting, static, failed, long copy.",
	["Lobby/LobbyApp"] = "The whole lobby app on inert clients (lobby place, Play mode).",
	["Lobby/ModePicker"] = "QueuePicker desktop / compact / stacked / disabled and the mode modal.",
	["Lobby/Navigation"] = "Lobby navigation rail (desktop, compact, icon-only), header and top bar.",
	["Lobby/Notifications"] = "NotificationModal: confirm, single-button notice, long message.",
	["Lobby/Onboarding"] = "Onboarding overlay for every step, per input device.",
	["Lobby/Party"] = "Party code, status, join-code modal and members modal.",
	["Lobby/Play"] = "The Play / splash page with the progression hub in each party state.",
	["Lobby/ProgressHub"] = "LobbyProgressHub tabs and the season status card states.",
	["Lobby/Quests"] = "QuestsPanel: mixed, pending, claimable, claimed, empty, wide, short.",
	["Lobby/RewardPanels"] = "Daily and season reward panels, wide and compact.",
	["Lobby/Rewards"] = "Daily reward modal (6 states) and the season pass modal.",
	["Lobby/Settings"] = "Settings page (lobby, arena) and setting rows wide / compact / disabled.",
	["Lobby/Shop"] = "ShopPage across all 11 economy states.",
	["Lobby/ShopDetails"] = "Item inspection / crate odds modal for every card kind and purchase state.",

	["Arena/Ballot"] = "Mode + map ballot (2 maps, no maps, 3 maps), mode cards and map chips.",
	["Arena/EmoteWheel"] = "In-match emote wheel per device and capacity.",
	["Arena/Loading"] = "Arena loading overlay: joining, waiting, returning, reconnecting, failed.",
	["Arena/MatchHUD"] = "Match HUD: TDM, FFA, respawning, starting, infection, spectating, scoreboard.",
	["Arena/Menu"] = "Combat menu closed and open on Shop / Backpack / Settings.",
	["Arena/PostMatch"] = "Post-match results over every debug scenario (needs Play mode).",
	["Arena/Scoreboard"] = "Standings strip and the full scoreboard.",
	["Arena/SplashdownHUD"] = "Race HUD through a round: intro, countdown, racing, finish, results.",
	["Arena/SplashdownIntro"] = "Course intro card for every course in the rotation.",
	["Arena/Toolbar"] = "Combat dock: 10 scenarios × Mouse / Gamepad / Touch.",
}

local GROUP_ORDER = { "Primitives", "Lobby", "Arena", "Storybook" }
local GROUP_NOTES = {
	Primitives = "Buttons, tabs, stickers, surfaces, type, progress, ribbons, wells, collectible cards",
	Lobby = "Every lobby page, modal and overlay",
	Arena = "Ballot, in-match HUD, race HUD, results and loading",
	Storybook = "Index and the shared fixtures",
}

local function collect(): { [string]: { { Name: string, Summary: string } } }
	local root = script.Parent
	local groups = {}
	for _, module in root:GetDescendants() do
		if module:IsA("ModuleScript") and string.match(module.Name, "%.story$") then
			local name = string.gsub(module.Name, "%.story$", "")
			local group = if module.Parent == root then "Storybook" else (module.Parent :: Instance).Name
			local key = if group == "Storybook" then name else `{group}/{name}`
			groups[group] = groups[group] or {}
			table.insert(groups[group], { Name = name, Summary = SUMMARIES[key] or "(no summary yet)" })
		end
	end
	for _, list in groups do
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
	end
	return groups
end

local function GroupCard(props: { Entries: { { Name: string, Summary: string } } })
	local children: { [string]: any } = {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
		Stroke = c("UIStroke", { Color = C.Ink, Thickness = T.Shape.StrokeCard }),
		Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 10),
		}),
		Layout = c("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, entry in props.Entries do
		children[`Row{index}`] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ROW),
		}, {
			Name = StoryRoot.Text({
				Font = T.Type.Display,
				Size = UDim2.new(1, 0, 0, 22),
				Text = string.upper(entry.Name),
				TextColor3 = C.PinkLip,
				TextSize = 19,
			}),
			Summary = StoryRoot.Text({
				Position = UDim2.fromOffset(0, 21),
				Size = UDim2.new(1, 0, 0, 19),
				Text = entry.Summary,
				TextSize = 15,
			}),
		})
	end
	return c("Frame", { BackgroundColor3 = C.SurfaceWarm, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, children)
end

local groups = collect()
local order = table.clone(GROUP_ORDER)
for group in groups do
	if not table.find(order, group) then
		table.insert(order, group)
	end
end
local states = {}
local total = 0
for _, group in order do
	local entries = groups[group]
	if entries then
		total += #entries
		table.insert(states, {
			Name = `{group} · {#entries}`,
			Note = GROUP_NOTES[group],
			Size = Vector2.new(WIDTH, 24 + #entries * ROW),
			Element = c(GroupCard, { Entries = entries }),
		})
	end
end

return StoryRoot.story({
	Title = "Ouch! UI — Index",
	Summary = `{total} stories. Every story draws real components on the candy stage with stub data from Stubs; `
		.. "states sit side by side at real size (screens at the live viewport, scaled to fit).",
	States = states,
})
