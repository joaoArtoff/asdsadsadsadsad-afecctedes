return {
	id = "Focus",
	displayName = "Foco",
	energyCost = 0,
	cooldown = 0,
	effectType = "None",
	energyGain = 2,

	-- Fica mais esquivo até o começo do próximo turno
	statusEffect = {
		id = "Focused",
		displayName = "Focado",
		icon = "F",
		turns = 1,
		modifiers = { { stat = "Dodge", type = "Percent", value = 0.10 } },
	},
}
