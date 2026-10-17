--!strict

-- Complete looks compose immutable component identities; only components are owned.

local Items: { [string]: any } = {}

-- Coverage is required so a new outfit cannot silently skip declaring whether it
-- replaces the body meshes or layers over them; CostumeVisualFactory enforces
-- the declaration against the authored geometry.
local function outfit(
	id: string,
	name: string,
	rarity: string,
	description: string,
	order: number,
	coverage: string,
	pieces: { string }
)
	assert(coverage == "Replace" or coverage == "Layer", `[Cosmetics] {id} needs Replace or Layer coverage`)
	local contents = {}
	for index, role in { "Head", "Body", "Feet" } do
		local pieceId = id .. role
		table.insert(contents, pieceId)
		Items[pieceId] = {
			Category = "CostumeAssets",
			Rarity = rarity,
			DisplayName = `{name} {pieces[index]}`,
			Thumbnail = "",
			CostumePiece = role,
			InventoryVisible = false,
			ShopEligible = false,
			Equippable = false,
		}
	end
	Items[id] = {
		Category = "CostumeAssets",
		Rarity = rarity,
		DisplayName = name,
		Description = description,
		Thumbnail = "",
		Contents = contents,
		Coverage = coverage,
		SortOrder = order,
	}
end

outfit(
	"FoamLeague",
	"Foam League",
	"Common",
	"A padded sports helmet, cobalt suit and soft trainers. Ready for your next big play.",
	10,
	"Replace",
	{ "Helmet", "Suit", "Trainers" }
)
outfit(
	"RainHopper",
	"Rain Hopper",
	"Rare",
	"A bright frog hood, sunny rainwear and puddle-ready boots.",
	20,
	"Replace",
	{ "Hood", "Raincoat", "Boots" }
)
outfit(
	"SnackStack",
	"Snack Stack",
	"Rare",
	"A fresh-baked headpiece, diner apron and matching shoes. Served with style.",
	30,
	"Replace",
	{ "Bun Hat", "Apron", "Shoes" }
)
outfit(
	"OrbitRookie",
	"Orbit Rookie",
	"Legendary",
	"An open space helmet, padded flight suit and soft landing boots.",
	40,
	"Replace",
	{ "Helmet", "Flight Suit", "Boots" }
)
outfit(
	"SundaeSprinter",
	"Sundae Sprinter",
	"Exclusive",
	"A vanilla swirl, strawberry suit and candy shoes. The sweetest finish.",
	50,
	"Replace",
	{ "Swirl", "Suit", "Trainers" }
)
outfit(
	"PartyRoyal",
	"Party Royal",
	"Exclusive",
	"A soft golden crown, plum suit and ceremonial shoes. A look fit for the podium.",
	60,
	"Replace",
	{ "Crown", "Suit", "Shoes" }
)
outfit(
	"PrismCloud",
	"Prism Cloud",
	"Legendary",
	"A pearly cloud hood, mint-trimmed parka and star-buckled boots. Soft as a daydream.",
	70,
	"Layer",
	{ "Hood", "Parka", "Boots" }
)
outfit(
	"CosmicArcade",
	"Cosmic Arcade",
	"Legendary",
	"An open starfield helmet, neon arcade jacket and high-score boots. Insert coin to begin.",
	80,
	"Layer",
	{ "Helmet", "Jacket", "Boots" }
)

return Items
