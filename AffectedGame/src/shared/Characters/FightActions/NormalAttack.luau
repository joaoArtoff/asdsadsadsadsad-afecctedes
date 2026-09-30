return {
	id = "NormalAttack",
	displayName = "Ataque Normal",
	energyCost = 0,
	cooldown = 0,
	effectType = "Damage",
	damage = 8,
	damageType = "Physical",

	-- Escala pelo maior entre Attack e MagicAttack, assim toda classe tem um ataque básico útil
	scaling = { Power = 1 },
}
