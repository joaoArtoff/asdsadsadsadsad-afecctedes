return {
	id = "HealthPotion",
	displayName = "Poção de Vida",
	description = "Recupera 30 de vida.",
	icon = "+",
	color = Color3.fromRGB(205, 40, 40),
	target = "Self",
	maxStack = 5,
	price = 10,

	-- O que o item faz ao ser usado (mesmos campos de uma ação: heal, damage, energy, cure, statusEffect)
	effect = {
		heal = 30,
	},
}
