return {
	id = "HealingLight",
	displayName = "Healing Light",
	description = "Cura toda a party e remove veneno e queimadura.",
	classId = "priest",
	energyCost = 2,
	cooldown = 1,

	targetGroup = "Allies",
	effectType = "Heal",
	heal = 12,
	scaling = { Healing = 1 },

	-- Ids dos efeitos que a habilidade remove de cada alvo
	cure = { "Poisoned", "Burning" },
}
