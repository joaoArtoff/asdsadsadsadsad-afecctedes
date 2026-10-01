return {
	id = "ataque_furtivo",
	displayName = "Ataque Furtivo",
	description = "+25% de dano crítico, -10% de defesa",

	-- Classe que pode escolher este feat (sem classId = qualquer classe pode usar)
	classId = "rogue",

	modifiers = {
		{ stat = "CriticalDamage", type = "Percent", value = 0.25 },
		{ stat = "Defense", type = "Percent", value = -0.10 },
	},
}
