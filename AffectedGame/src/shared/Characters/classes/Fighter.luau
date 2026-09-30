
return {
	id = "fighter",
	displayName = "Lutador",

	baseStats = {
		maxHealth = 140,
		maxMana = 40,
		attack = 24,
		defense = 12,
	},

	-- tem que fazer os moves e puxar pra ca pelo ID
	moveIds = { "slash", "powerStrike", "warcry", "execute" },
}
