return {
	id = "cancao_de_guerra",
	displayName = "Canção de Guerra",
	description = "+15% de ataque, -5% de defesa",

	-- Classe que pode escolher este feat (sem classId = qualquer classe pode usar)
	classId = "bard",

	modifiers = {
		{ stat = "Attack", type = "Percent", value = 0.15 },
		{ stat = "Defense", type = "Percent", value = -0.05 },
	},
}
