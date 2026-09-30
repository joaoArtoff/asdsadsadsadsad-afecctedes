return {
	id = "Antidote",
	displayName = "Antídoto",
	description = "Cura o veneno e recupera 5 de vida.",
	icon = "A",
	color = Color3.fromRGB(70, 185, 60),
	target = "Self",
	maxStack = 5,
	price = 8,

	-- "cure" lista os ids dos efeitos de status que o item remove
	effect = {
		heal = 5,
		cure = { "Poisoned" },
	},
}
