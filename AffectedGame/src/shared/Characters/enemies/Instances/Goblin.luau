return {
	id = "Goblin",
	name = "Goblin",
	level = 1,

	-- Rápido e esquivo, com pouca vida
	attributes = { Str = 4, Dex = 8, Con = 3, Int = 2, Wis = 2 },
	stats = { MaxHealth = 55, Dodge = 0.12, CriticalChance = 0.08, CriticalDamage = 1.3 },

	actions = {
		{ id = "Punch", weight = 1 },
	},

	energyRegen = 1,
	xpReward = 20,
	focusWeakestChance = 0.6,

	appearance = {
		scale = 0.85,
		colors = {
			Head = Color3.fromRGB(90, 130, 60),
			Torso = Color3.fromRGB(80, 110, 50),
			Arms = Color3.fromRGB(80, 110, 50),
			Legs = Color3.fromRGB(70, 95, 45),
		},
	},
}
