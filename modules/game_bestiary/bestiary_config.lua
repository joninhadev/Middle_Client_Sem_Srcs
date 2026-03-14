Bestiary = {}
BESTIARY_OPCODE = 61

Bestiary.categories = {}
Bestiary.categoryCreaturesCache = {}
Bestiary.creatureInfoCache = {}
Bestiary.killsCache = {}
Bestiary.trackedCreatures = {}
Bestiary.trackedCreatureList = {}
Bestiary.trackerSortBy = 'name'
Bestiary.trackerSortOrder = 'asc'

--- Config
BESTIARY_MAX_TRACKED_CREATURES = 10
BESTIARY_DISPLAY_STATS_AT_PERCENT = 100
BESTIARY_DISPLAY_DEFENSES_AT_PERCENT = 100

BESTIARY_NO_BONUS_TEXT = "No Bonus"

Bestiary.categoriesDisplay = {
--	{id = 0, name = "All", display = {card = "images/cards/Extra_Dimensional"}},
	{id = 1, name = "Anfíbios", display = {card = "images/cards/Amphibic"}},
	{id = 2, name = "Aquáticos", display = {card = "images/cards/Aquatic"}},
	{id = 3, name = "Aves", display = {card = "images/cards/Bird"}},
	{id = 4, name = "Construct", display = {card = "images/cards/Construct"}},
	{id = 5, name = "Demonios", display = {card = "images/cards/Demon"}},
	{id = 6, name = "Dragões", display = {card = "images/cards/Dragon"}},
	{id = 7, name = "Elementais", display = {card = "images/cards/Elemental"}},
	{id = 8, name = "Extra Dimensionais", display = {card = "images/cards/Extra_Dimensional"}},
	{id = 9, name = "Gigantes", display = {card = "images/cards/Giant"}},
	{id = 10, name = "Humanos", display = {card = "images/cards/Human"}},
	{id = 11, name = "Humanóides", display = {card = "images/cards/Humanoid"}},
	{id = 12, name = "Licantropos", display = {card = "images/cards/Lycanthrope"}},
	{id = 13, name = "Criaturas Mágicas", display = {card = "images/cards/Magical"}},
	{id = 14, name = "Mamíferos", display = {card = "images/cards/Mammal"}},
	{id = 15, name = "Plantas", display = {card = "images/cards/Plant"}},
	{id = 16, name = "Répteis", display = {card = "images/cards/Reptile"}},
	{id = 17, name = "Slimes", display = {card = "images/cards/Slime"}},
	{id = 18, name = "Mortos-Vivos", display = {card = "images/cards/Undead"}},
	{id = 19, name = "Vermes", display = {card = "images/cards/Vermin"}},
	-- {id = 6, name = "Example", display = {display = {outfit = {type = 11}, offset = {x = 16, y = -5}}}},
}

Bestiary.lootDisplayConfig = {
	{ progressPercent = 100, minItemChance = 0 },
	{ progressPercent = 75, minItemChance = 10 },
	{ progressPercent = 50, minItemChance = 25 },
	{ progressPercent = 25, minItemChance = 50 },
	{ progressPercent = 0, minItemChance = nil },
}

Bestiary.charmsInfo = {
	["1"] = {
		["name"] = "Adrenaline Burst",
		["image"] = "Adrenaline_Burst",
		["pointsPrice"] = 120,
		["description"] = "Bursts of adrenaline enhance your reflexes with a 5% chance after getting hit and lets you move faster for 10 seconds."
	},
	["2"] = {
		["name"] = "Zap",
		["image"] = "Zap",
		["pointsPrice"] = 160,
		["description"] = "Each attack on a creature has a 5% chance to trigger and deal 5% of its maximum Hit Points as Energy Damage once."
	},
	["3"] = {
		["name"] = "Wound",
		["image"] = "Wound",
		["pointsPrice"] = 140,
		["description"] = "Each attack on a creature has a 5% chance to trigger and deal 5% of its maximum Hit Points as Physical Damage once."
	},
	["4"] = {
		["name"] = "Void Inversion",
		["image"] = "Void_Inversion",
		["pointsPrice"] = 140,
		["description"] = "20% chance to gain mana instead of losing it when taking Mana Drain damage."
	},
	["5"] = {
		["name"] = "Poison",
		["image"] = "Poison",
		["pointsPrice"] = 160,
		["description"] = "Each attack on a creature has a 5% chance to trigger and deal 5% of its maximum Hit Points as Earth Damage once."
	},
	["6"] = {
		["name"] = "Parry",
		["image"] = "Parry",
		["pointsPrice"] = 180,
		["description"] = "Any damage taken has a 5% chance to be reflected to the aggressor as Physical Damage."
	},
	["7"] = {
		["name"] = "Overpower",
		["image"] = "Overpower",
		["pointsPrice"] = 300,
		["description"] = "Each attack has a 5% chance to deal Physical Damage equal to 5% of your maximum health."
	},
	["8"] = {
		["name"] = "Overflux",
		["image"] = "Overflux",
		["pointsPrice"] = 300,
		["description"] = "Each attack has a 5% chance to deal Physical Damage equal to 2.5% of your maximum mana."
	},
	["9"] = {
		["name"] = "Numb",
		["image"] = "Numb",
		["pointsPrice"] = 120,
		["description"] = "Numbs the creature with a 3% chance after its attack and paralyses the creature for 6 seconds."
	},
	["10"] = {
		["name"] = "Freeze",
		["image"] = "Freeze",
		["pointsPrice"] = 160,
		["description"] = "Each attack on a creature has a 5% chance to trigger and deal 5% of its maximum Hit Points as Ice Damage once."
	},
	["11"] = {
		["name"] = "Enflame",
		["image"] = "Enflame",
		["pointsPrice"] = 160,
		["description"] = "Each attack on a creature has a 5% chance to trigger and deal 5% of its maximum Hit Points as Fire Damage once."
	},
	["12"] = {
		["name"] = "Dodge",
		["image"] = "Dodge",
		["pointsPrice"] = 140,
		["description"] = "Dodges an attack with a 5% chance, taking no damage at all."
	},
	["13"] = {
		["name"] = "Cripple",
		["image"] = "Cripple",
		["pointsPrice"] = 140,
		["description"] = "Cripples the creature with a 3% chance and paralyses it for 6 seconds."
	},
	["14"] = {
		["name"] = "Carnage",
		["image"] = "Carnage",
		["pointsPrice"] = 200,
		["description"] = "Killing a monster has 10% chance to deal Physical Damage equal to 15% of its maximum health to all monsters in a small radius."
	},
	["15"] = {
		["name"] = "Low Blow",
		["image"] = "Low_Blow",
		["pointsPrice"] = 180,
		["description"] = "Adds 8% critical hit chance to attacks with critical hit weapons against the creature this charm is assigned to."
	},
}