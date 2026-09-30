return {
	id = "ZombieBite",
	displayName = "Mordida Podre",
	energyCost = 2,
	cooldown = 2,
	effectType = "Damage",
	damage = 4,
	damageType = "Physical",
	scaling = { Attack = 0.6 },

	-- Envenena o alvo por 3 turnos se acertar
	statusEffect = {
		id = "Poisoned",
		displayName = "Envenenado",
		icon = "V",
		turns = 3,
		damagePerTurn = 4,
		chance = 0.8,
	},
}
