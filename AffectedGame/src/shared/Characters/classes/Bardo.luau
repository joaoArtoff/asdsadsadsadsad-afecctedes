return {
	id = "bard",
	displayName = "Bardo",

	baseStats = {
		maxHealth = 100,
		maxMana = 110,
		attack = 12,
		defense = 10,
		magicAttack = 14,
		healing = 12,
	},

	-- Ações na barra de ataques: Ataque Normal, a habilidade própria da classe e Foco
	actions = { "NormalAttack", "CancaoDaCoragem", "Focus" },

	-- tem que fazer os moves e puxar pra ca pelo ID
	moveIds = { "inspire", "healingSong", "dissonance", "lullaby" },
}
