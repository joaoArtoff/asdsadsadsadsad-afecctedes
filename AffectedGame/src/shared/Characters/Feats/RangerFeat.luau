return {
	id = "mira_precisa",
	displayName = "Mira Precisa",
	description = "+20% de chance de crítico, -10% de defesa",

	-- Classe que pode escolher este feat (sem classId = qualquer classe pode usar)
	classId = "ranger",

	modifiers = {
		{ stat = "CriticalChance", type = "Percent", value = 0.20 },
		{ stat = "Defense", type = "Percent", value = -0.10 },
	},
}
