return {
	id = "rogue",
	displayName = "Ladino",

	baseStats = {
		maxHealth = 100,
		maxMana = 60,
		attack = 22,
		defense = 8,
	},

	-- Ações na barra de ataques: Ataque Normal, a habilidade própria da classe e Foco
	actions = { "NormalAttack", "Punhalada", "Focus" },

	-- tem que fazer os moves e puxar pra ca pelo ID
	moveIds = { "backstab", "poisonBlade", "smokeBomb", "evade" },
}
