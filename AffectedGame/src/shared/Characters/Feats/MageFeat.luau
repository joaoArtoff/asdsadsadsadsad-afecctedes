return {
	id = "sobrecarga_arcana",
	displayName = "Sobrecarga Arcana",
	description = "+35% de dano mágico, -20% de defesa",

	-- Classe que pode escolher este feat (sem classId = qualquer classe pode usar)
	classId = "mage",

	modifiers = {
		{ stat = "MagicAttack", type = "Percent", value = 0.35 },
		{ stat = "Defense", type = "Percent", value = -0.20 },
	},
}
