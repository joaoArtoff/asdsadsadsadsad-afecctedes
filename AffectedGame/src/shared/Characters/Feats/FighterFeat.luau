return {
	id = "investida_brutal",
	displayName = "Investida Brutal",
	description = "+20% de ataque, -10% de defesa",

	-- Classe que pode escolher este feat (sem classId = qualquer classe pode usar)
	classId = "fighter",

	modifiers = {
		{ stat = "Attack", type = "Percent", value = 0.20 },
		{ stat = "Defense", type = "Percent", value = -0.10 },
	},
}
