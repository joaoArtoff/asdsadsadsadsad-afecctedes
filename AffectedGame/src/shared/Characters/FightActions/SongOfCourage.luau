return {
	id = "SongOfCourage",
	displayName = "Song of Courage",
	description = "Cura toda a party e deixa todos Inspirados (+20% de ataque) por 2 turnos.",
	classId = "bard",
	energyCost = 2,
	cooldown = 2,

	-- "Allies" aplica em todos os aliados vivos; "Enemies" em todos os inimigos
	targetGroup = "Allies",
	effectType = "Heal",
	heal = 6,
	scaling = { Healing = 0.5 },

	statusEffect = {
		id = "Inspired",
		displayName = "Inspired",
		icon = "♪",
		turns = 2,
		modifiers = { { stat = "Attack", type = "Percent", value = 0.20 } },
	},
}
