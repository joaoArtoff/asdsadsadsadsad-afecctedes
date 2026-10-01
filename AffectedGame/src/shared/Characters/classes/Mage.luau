return {
	id = "mage",
	displayName = "Mago",

	baseStats = {
		maxHealth = 80,
		maxMana = 150,
		attack = 8,
		defense = 6,
		magicAttack = 24,
		magicDefense = 14,
	},

	-- Ações na barra de ataques: Ataque Normal, a habilidade própria da classe e Foco
	actions = { "NormalAttack", "BolaDeFogo", "Focus" },

	-- tem que fazer os moves e puxar pra ca pelo ID
	moveIds = { "fireball", "iceShard", "lightningBolt", "arcaneShield" },
}
