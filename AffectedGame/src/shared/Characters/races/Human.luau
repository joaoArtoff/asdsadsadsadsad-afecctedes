return {
	id = "Human",
	name = "Humano",
	description = "", -- preencher depois

	-- Bônus somados direto nos atributos base da classe (Str, Dex, Con, Int, Wis)
	attributes = {},

	-- Modificadores nos status derivados, mesmo formato dos Feats (8% de dano a mais)
	modifiers = {
		{ stat = "Damage", type = "Percent", value = 0.08 },
	},
}
