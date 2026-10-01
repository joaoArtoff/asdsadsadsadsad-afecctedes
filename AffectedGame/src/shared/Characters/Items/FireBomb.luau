return {
	id = "FireBomb",
	displayName = "Bomba de Fogo",
	description = "Causa 25 de dano de fogo no alvo e o queima por 2 turnos.",
	icon = "B",
	color = Color3.fromRGB(240, 130, 20),
	target = "Enemy",
	maxStack = 3,
	price = 15,

	-- Itens ofensivos não erram; ignoreDefense faz o dano não ser reduzido pela defesa
	effect = {
		damage = 25,
		damageType = "Fire",
		ignoreDefense = true,
		statusEffect = {
			id = "Burning",
			displayName = "Burning",
			icon = "Q",
			turns = 2,
			damagePerTurn = 5,
		},
	},
}
