-- Classes/Priest.luau
return {
	id = "priest",
	displayName = "Sacerdote",

	baseStats = {
		maxHealth = 100,
		maxMana = 130,
		attack = 8,
		defense = 12,
	},

	-- tem que fazer os moves e puxar pra ca pelo ID
	moveIds = { "heal", "smite", "blessing", "purify" },
}
