
return {
	id = "knight",
	displayName = "Cavaleiro",

	baseStats = {
		maxHealth = 170,
		maxMana = 40,
		attack = 16,
		defense = 22,
	},

	-- tem que fazer os moves e puxar pra ca pelo ID
	moveIds = { "shieldBlock", "shieldBash", "taunt", "guard" },
}
