return {
	id = "Fireball",
	displayName = "Fireball",
	description = "Dano de fogo mágico que deixa o alvo Queimando por 2 turnos.",
	classId = "mage",
	energyCost = 3,
	cooldown = 1,

	effectType = "Damage",
	damage = 14,
	damageType = "Fire",
	scaling = { MagicAttack = 1.4 },

	statusEffect = {
		id = "Burning",
		displayName = "Burning",
		icon = "Q",
		turns = 2,
		damagePerTurn = 5,
	},
}
