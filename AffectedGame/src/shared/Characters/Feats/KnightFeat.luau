return {
	id = "postura_defensiva",
	displayName = "Postura Defensiva",
	description = "+30% de defesa, -15% de ataque",

	-- Classe que pode escolher este feat (sem classId = qualquer classe pode usar)
	classId = "knight",

	modifiers = {
		{ stat = "Defense", type = "Percent", value = 0.30 },
		{ stat = "Attack", type = "Percent", value = -0.15 },
	},
}
