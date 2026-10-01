return {
	id = "knight",
	displayName = "Cavaleiro",

	baseStats = {
		maxHealth = 170,
		maxMana = 40,
		attack = 16,
		defense = 22,
	},

	-- Ações na barra de ataques: Ataque Normal, a habilidade própria da classe e Foco
	actions = { "NormalAttack", "GolpeDeEscudo", "Focus" },

	-- tem que fazer os moves e puxar pra ca pelo ID
	moveIds = { "shieldBlock", "shieldBash", "taunt", "guard" },
}
