return {
	id = "bencao_divina",
	displayName = "Bênção Divina",
	description = "+25% de cura, -10% de ataque",

	-- Classe que pode escolher este feat (sem classId = qualquer classe pode usar)
	classId = "priest",

	modifiers = {
		{ stat = "Healing", type = "Percent", value = 0.25 },
		{ stat = "Attack", type = "Percent", value = -0.10 },
	},
}
