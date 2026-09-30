local Characters = script.Parent.Parent
local Character = require(Characters.Character)
local Registry = require(Characters.Registry)

local Enemy = setmetatable({}, { __index = Character })
Enemy.__index = Enemy

Enemy.HEALTH_GROWTH_PER_LEVEL = 0.15
Enemy.FOCUS_WEAKEST_CHANCE = 0.35

-- Cria um inimigo a partir de uma definição de enemies/instances; overrides permitem escalar (ex: nível por andar)
function Enemy.new(definition, overrides)
	local data = table.clone(definition)
	for key, value in overrides or {} do
		data[key] = value
	end

	data.isPlayerTeam = false
	data.stats = table.clone(data.stats or {})

	local level = math.max(1, data.level or 1)
	if data.stats.MaxHealth and level > 1 then
		data.stats.MaxHealth = math.floor(data.stats.MaxHealth * (1 + Enemy.HEALTH_GROWTH_PER_LEVEL * (level - 1)))
	end

	local self = Character.new(data)
	setmetatable(self, Enemy)

	self.definitionId = definition.id
	self.appearance = data.appearance
	self.energyRegen = data.energyRegen or 1
	self.xpReward = data.xpReward or 10 * level
	self.focusWeakestChance = data.focusWeakestChance or Enemy.FOCUS_WEAKEST_CHANCE

	return self
end

-- Atalho: cria pelo id registrado em enemies/instances (ex: Enemy.Create("Zombie", { level = 2 }))
function Enemy.Create(id, overrides)
	local definition = Registry.Get("Enemies", id)
	if not definition then
		warn("[Enemy] Definição não encontrada:", id)
		return nil
	end

	return Enemy.new(definition, overrides)
end

-- Inimigos recuperam energia sozinhos a cada turno para conseguir usar as habilidades mais caras
function Enemy:ResetTurn()
	Character.ResetTurn(self)
	self:GainEnergy(self.energyRegen)
end

-- IA: sorteia entre as ações usáveis pelo peso de cada uma e escolhe um alvo, às vezes mirando o mais ferido
function Enemy:ChooseAction(targets, rng)
	rng = rng or Random.new()

	local usable, totalWeight = {}, 0
	for _, entry in self.actions do
		local id = type(entry) == "table" and entry.id or entry
		local weight = type(entry) == "table" and entry.weight or 1
		local action = Registry.Get("Actions", id)

		if action and self:CanUse(action) then
			table.insert(usable, { action = action, weight = weight })
			totalWeight += weight
		end
	end

	if #usable == 0 then
		return nil
	end

	local roll = rng:NextNumber() * totalWeight
	local chosen = usable[#usable].action
	for _, option in usable do
		roll -= option.weight
		if roll <= 0 then
			chosen = option.action
			break
		end
	end

	if chosen.effectType == "Heal" or chosen.effectType == "None" then
		return chosen, self
	end

	local alive = {}
	for _, target in targets do
		if target.isAlive and not target.left then
			table.insert(alive, target)
		end
	end

	if #alive == 0 then
		return chosen, nil
	end

	if rng:NextNumber() < self.focusWeakestChance then
		table.sort(alive, function(a, b)
			return a.health / a.stats.MaxHealth < b.health / b.stats.MaxHealth
		end)
		return chosen, alive[1]
	end

	return chosen, alive[rng:NextInteger(1, #alive)]
end

return Enemy
