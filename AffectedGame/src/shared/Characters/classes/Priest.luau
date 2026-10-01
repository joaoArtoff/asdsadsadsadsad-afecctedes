return {
	id = "priest",
	displayName = "Sacerdote",

	baseStats = {
		maxHealth = 100,
		maxMana = 130,
		attack = 8,
		defense = 12,
		magicAttack = 12,
		magicDefense = 16,
		healing = 20,
	},

	-- Ações na barra de ataques: Ataque Normal, a habilidade própria da classe e Foco
	actions = { "NormalAttack", "LuzCurativa", "Focus" },

	-- tem que fazer os moves e puxar pra ca pelo ID
	moveIds = { "heal", "smite", "blessing", "purify" },
}
