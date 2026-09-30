
return {
	id = "ranger",
	displayName = "Patrulheiro",

	baseStats = {
		maxHealth = 110,
		maxMana = 60,
		attack = 20,
		defense = 10,
	},

	-- tem que fazer os moves e puxar pra ca pelo ID
	moveIds = { "aimedShot", "multiShot", "trap", "volley" },
}
