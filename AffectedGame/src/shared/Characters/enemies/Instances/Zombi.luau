return {
	id = "Zombie",
	name = "Zombie",
	level = 1,

	-- Atributos alimentam as fórmulas; stats fixa valores específicos por cima delas
	attributes = { Str = 6, Dex = 2, Con = 6, Int = 1, Wis = 1 },
	stats = { MaxHealth = 100, Dodge = 0.02 },
	resistances = { Dark = 0.5 },

	-- Ações com peso de sorteio da IA
	actions = {
		{ id = "ZombieClaw", weight = 3 },
		{ id = "ZombieBite", weight = 2 },
	},

	energyRegen = 1,
	xpReward = 30,

	-- Cores do rig de blocos (usado se não existir ServerStorage.EnemyModels.Zombie)
	appearance = {
		scale = 1,
		colors = {
			Head = Color3.fromRGB(85, 145, 75),
			Torso = Color3.fromRGB(55, 65, 55),
			Arms = Color3.fromRGB(75, 130, 70),
			Legs = Color3.fromRGB(40, 45, 50),
		},
	},
}
