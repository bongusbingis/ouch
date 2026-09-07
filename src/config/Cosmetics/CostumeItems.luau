--!strict

-- Complete looks compose immutable component identities; only components are owned.

local Items: { [string]: any } = {}

local function outfit(id: string, name: string, rarity: string, description: string, order: number, pieces: { string })
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
		SortOrder = order,
	}
end

outfit(
	"FoamLeague",
	"Foam League",
	"Common",
	"A padded sports helmet, cobalt suit and soft trainers. Ready for your next big play.",
	10,
	{ "Helmet", "Suit", "Trainers" }
)
outfit(
	"RainHopper",
	"Rain Hopper",
	"Rare",
	"A bright frog hood, sunny rainwear and puddle-ready boots.",
	20,
	{ "Hood", "Raincoat", "Boots" }
)
outfit(
	"SnackStack",
	"Snack Stack",
	"Rare",
	"A fresh-baked headpiece, diner apron and matching shoes. Served with style.",
	30,
	{ "Bun Hat", "Apron", "Shoes" }
)
outfit(
	"OrbitRookie",
	"Orbit Rookie",
	"Legendary",
	"An open space helmet, padded flight suit and soft landing boots.",
	40,
	{ "Helmet", "Flight Suit", "Boots" }
)
outfit(
	"SundaeSprinter",
	"Sundae Sprinter",
	"Exclusive",
	"A vanilla swirl, strawberry suit and candy shoes. The sweetest finish.",
	50,
	{ "Swirl", "Suit", "Trainers" }
)
outfit(
	"PartyRoyal",
	"Party Royal",
	"Exclusive",
	"A soft golden crown, plum suit and ceremonial shoes. A look fit for the podium.",
	60,
	{ "Crown", "Suit", "Shoes" }
)

return Items
