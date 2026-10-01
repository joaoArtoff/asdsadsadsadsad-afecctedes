local HttpService = game:GetService("HttpService")

local Attributes = require(script.Parent.Attributes)

local Character = {}
Character.__index = Character

Character.MAX_ENERGY = 6
Character.DEFENSE_CONSTANT = 60

-- Fórmulas dos status derivados: recebem os atributos e o nível e devolvem o valor base de cada status
Character.Formulas = {
	MaxHealth = function(a, lvl) return 40 + a:Get("Con") * 8 + (lvl - 1) * 6 end,
	Attack = function(a, lvl) return a:Get("Str") * 1.5 + lvl end,
	MagicAttack = function(a, lvl) return a:Get("Int") * 1.5 + lvl end,
	Defense = function(a) return a:Get("Con") * 1.2 end,
	MagicDefense = function(a) return a:Get("Wis") * 1.2 end,
	Healing = function(a, lvl) return a:Get("Wis") * 1.2 + lvl end,
	Dodge = function(a) return 0.02 + a:Get("Dex") * 0.006 end,
	CriticalChance = function(a) return 0.03 + a:Get("Dex") * 0.005 end,
	CriticalDamage = function() return 1.5 end,
	Initiative = function(a, lvl) return a:Get("Dex") + lvl * 0.5 end,
	Damage = function() return 1 end,
	DamageResistance = function() return 0 end,
}

-- Status de chance/multiplicador: modificadores "Percent" somam pontos direto (ex: +0.20 de crítico) em vez de multiplicar
local ADDITIVE = { Dodge = true, CriticalChance = true, CriticalDamage = true, DamageResistance = true }

local LIMITS = {
	MaxHealth = { 1, math.huge },
	Dodge = { 0, 0.6 },
	CriticalChance = { 0, 1 },
	CriticalDamage = { 1, 5 },
	DamageResistance = { 0, 0.8 },
}

-- Campos do Character antigo aceitos no construtor e convertidos para os status novos (compatibilidade)
local LEGACY_STATS = {
	health = "MaxHealth",
	dodgeChance = "Dodge",
	criticalChance = "CriticalChance",
	criticalDamage = "CriticalDamage",
	damageResistance = "DamageResistance",
	initiative = "Initiative",
}

-- Constrói o personagem: atributos, nível, valores fixos opcionais (stats), resistências por tipo de dano e ações
function Character.new(data)
	data = data or {}
	local self = setmetatable({}, Character)

	self.id = data.id or data.name or "Character"
	self.name = data.name or self.id
	self.isPlayerTeam = data.isPlayerTeam == true
	self.level = math.max(1, data.level or 1)
	self.attributes = Attributes.new(data.attributes)

	self.baseStats = table.clone(data.stats or {})
	for legacyKey, stat in LEGACY_STATS do
		if data[legacyKey] ~= nil and self.baseStats[stat] == nil then
			self.baseStats[stat] = data[legacyKey]
		end
	end

	self.modifierSources = table.clone(data.modifiers or {})
	self.resistances = table.clone(data.resistances or {})
	self.actions = table.clone(data.actions or {})
	self.statusEffects = {}
	self.cooldowns = {}
	self.stats = {}

	self.maxEnergy = data.maxEnergy or Character.MAX_ENERGY
	self.energy = math.clamp(data.energy or 0, 0, self.maxEnergy)
	self.isAlive = true
	self.actionsRemaining = 1
	self.model = nil
	self.keepModelAlive = false

	self:RecalculateStats(true)

	return self
end

-- Recalcula todos os status: fórmula (ou valor fixo) + modificadores das fontes (raça, feats, itens) + efeitos ativos
function Character:RecalculateStats(fullHeal)
	local flat, percent = {}, {}

	local function collect(mods)
		for _, mod in mods do
			local bucket = mod.type == "Flat" and flat or percent
			bucket[mod.stat] = (bucket[mod.stat] or 0) + (mod.value or 0)
		end
	end

	for _, mods in self.modifierSources do
		collect(mods)
	end

	for _, effect in self.statusEffects do
		if effect.modifiers then
			collect(effect.modifiers)
		end
	end

	local previousMax = self.stats.MaxHealth

	for stat, formula in Character.Formulas do
		local base = (self.baseStats[stat] or formula(self.attributes, self.level)) + (flat[stat] or 0)
		local value = ADDITIVE[stat] and base + (percent[stat] or 0) or base * (1 + (percent[stat] or 0))
		local limit = LIMITS[stat]
		self.stats[stat] = limit and math.clamp(value, limit[1], limit[2]) or value
	end

	local maxHealth = math.floor(self.stats.MaxHealth + 0.5)
	self.stats.MaxHealth = maxHealth

	if not self.isAlive then
		self.health = 0
	elseif fullHeal or previousMax == nil then
		self.health = maxHealth
	else
		self.health = math.clamp(self.health + math.max(maxHealth - previousMax, 0), 1, maxHealth)
	end

	self.maxHealth = maxHealth
	self.dodgeChance = self.stats.Dodge
	self.criticalChance = self.stats.CriticalChance
	self.criticalDamage = self.stats.CriticalDamage
	self.damageResistance = self.stats.DamageResistance
	self.initiative = self.stats.Initiative

	self:Sync()
end

-- Lê um status calculado; "Power" é o maior entre ataque físico e mágico (usado pelos ataques genéricos)
function Character:GetStat(name)
	if name == "Power" then
		return math.max(self.stats.Attack or 0, self.stats.MagicAttack or 0)
	end

	return self.stats[name] or 0
end

-- Registra (ou troca) os modificadores de uma fonte, como "race", "feats" ou "items", e recalcula
function Character:SetModifiers(sourceId, mods)
	self.modifierSources[sourceId] = mods
	self:RecalculateStats(false)
end

-- Aplica dano já calculado, marca a morte e devolve quanto de vida realmente foi perdido
function Character:TakeDamage(amount)
	if not self.isAlive then
		return 0
	end

	local applied = math.min(math.max(math.floor(amount + 0.5), 0), self.health)
	self.health -= applied

	if self.health <= 0 then
		self.health = 0
		self.isAlive = false
	end

	self:Sync()
	return applied
end

-- Cura sem passar da vida máxima e devolve quanto foi curado de fato
function Character:Heal(amount)
	if not self.isAlive then
		return 0
	end

	local applied = math.min(math.max(math.floor(amount + 0.5), 0), self.stats.MaxHealth - self.health)
	self.health += applied
	self:Sync()
	return applied
end

-- Traz o personagem de volta com uma porcentagem da vida máxima (para itens/habilidades de reviver)
function Character:Revive(percent)
	if self.isAlive then
		return false
	end

	self.isAlive = true
	self.health = math.max(1, math.floor(self.stats.MaxHealth * (percent or 0.25)))
	self:Sync()
	return true
end

-- Controle de energia: ganhar respeita o máximo, gastar só acontece se houver o suficiente
function Character:GainEnergy(amount)
	local before = self.energy
	self.energy = math.clamp(self.energy + (amount or 0), 0, self.maxEnergy)
	self:Sync()
	return self.energy - before
end

function Character:SpendEnergy(amount)
	amount = amount or 0
	if self.energy < amount then
		return false
	end

	self.energy -= amount
	self:Sync()
	return true
end

-- Nomes dos status em português para as descrições automáticas dos efeitos
local STAT_NAMES = {
	MaxHealth = "vida máxima",
	Attack = "ataque",
	MagicAttack = "ataque mágico",
	Defense = "defesa",
	MagicDefense = "defesa mágica",
	Healing = "cura",
	Dodge = "esquiva",
	CriticalChance = "chance de crítico",
	CriticalDamage = "dano crítico",
	Initiative = "iniciativa",
	Damage = "dano",
	DamageResistance = "resistência a dano",
}

-- Gera a descrição do efeito a partir dos dados quando a ação não escreveu uma própria
local function describeEffect(effect)
	if type(effect.description) == "string" then
		return effect.description
	end

	local parts = {}
	if effect.damagePerTurn then
		table.insert(parts, string.format("Sofre %d de dano por turno", effect.damagePerTurn))
	end
	if effect.healPerTurn then
		table.insert(parts, string.format("Cura %d por turno", effect.healPerTurn))
	end
	if effect.skipTurn then
		table.insert(parts, "Perde o próximo turno")
	end
	for _, mod in effect.modifiers or {} do
		local value = mod.type == "Flat" and string.format("%+g", mod.value) or string.format("%+d%%", math.floor(mod.value * 100 + 0.5))
		table.insert(parts, value .. " de " .. (STAT_NAMES[mod.stat] or mod.stat))
	end

	return table.concat(parts, ". ")
end

-- Decide se o efeito é bom (Buff) ou ruim (Debuff) para colorir o ícone na interface
local function effectKind(effect)
	if effect.kind == "Buff" or effect.kind == "Debuff" then
		return effect.kind
	end
	if effect.damagePerTurn or effect.skipTurn then
		return "Debuff"
	end
	for _, mod in effect.modifiers or {} do
		if (mod.value or 0) < 0 then
			return "Debuff"
		end
	end
	return "Buff"
end

-- Aplica ou renova um efeito de status; guarda nome, descrição e tipo para a interface
function Character:AddStatus(id, effect)
	self.statusEffects[id] = {
		turnsLeft = effect.turns or 1,
		damagePerTurn = effect.damagePerTurn,
		healPerTurn = effect.healPerTurn,
		skipTurn = effect.skipTurn,
		modifiers = effect.modifiers,
		name = effect.displayName or id,
		description = describeEffect(effect),
		kind = effectKind(effect),
		icon = effect.icon,
	}

	if effect.modifiers then
		self:RecalculateStats(false)
	else
		self:Sync()
	end
end

function Character:RemoveStatus(id)
	local effect = self.statusEffects[id]
	if not effect then
		return
	end

	self.statusEffects[id] = nil

	if effect.modifiers then
		self:RecalculateStats(false)
	else
		self:Sync()
	end
end

-- Processa os efeitos no início do turno (veneno, regeneração, atordoamento) e devolve um relatório para o log
function Character:TickStatus()
	local report = { skipTurn = false, lines = {} }
	local changed = false

	for id, effect in self.statusEffects do
		if effect.damagePerTurn and self.isAlive then
			local dealt = self:TakeDamage(effect.damagePerTurn)
			table.insert(report.lines, string.format("%s sofreu %d de dano por %s.", self.name, dealt, id))
		end

		if effect.healPerTurn and self.isAlive then
			local healed = self:Heal(effect.healPerTurn)
			table.insert(report.lines, string.format("%s recuperou %d de vida por %s.", self.name, healed, id))
		end

		if effect.skipTurn then
			report.skipTurn = true
		end

		effect.turnsLeft -= 1
		if effect.turnsLeft <= 0 then
			self.statusEffects[id] = nil
			changed = changed or effect.modifiers ~= nil
		end
	end

	if changed then
		self:RecalculateStats(false)
	else
		self:Sync()
	end

	return report
end

-- Início de turno: devolve a ação disponível e reduz as recargas das habilidades
function Character:ResetTurn()
	self.actionsRemaining = 1

	for actionId, turns in self.cooldowns do
		self.cooldowns[actionId] = turns > 1 and turns - 1 or nil
	end
end

-- Limpa efeitos e recargas e define a energia inicial ao entrar em uma nova batalha
function Character:PrepareForBattle(startingEnergy)
	local hadModifiers = false

	for _, effect in self.statusEffects do
		hadModifiers = hadModifiers or effect.modifiers ~= nil
	end

	table.clear(self.statusEffects)
	table.clear(self.cooldowns)
	self.energy = math.clamp(startingEnergy or 0, 0, self.maxEnergy)
	self.actionsRemaining = 1

	if hadModifiers then
		self:RecalculateStats(false)
	else
		self:Sync()
	end
end

-- Verifica se a ação pode ser usada agora (vivo, com ação sobrando, energia e fora de recarga)
function Character:CanUse(action)
	if not self.isAlive then
		return false, self.name .. " está fora de combate."
	end

	if self.actionsRemaining <= 0 then
		return false, "Sem ações restantes neste turno."
	end

	local cost = action.energyCost or 0
	if self.energy < cost then
		return false, string.format("Energia insuficiente (%d/%d).", self.energy, cost)
	end

	local cooldown = self.cooldowns[action.id]
	if cooldown then
		return false, string.format("%s em recarga (%d turno(s)).", action.displayName or action.id, cooldown)
	end

	return true
end

-- Calcula um golpe: esquiva, escala por status, bônus de dano, crítico, defesa física/mágica, resistências e variação
function Character:ComputeDamage(action, target, rng)
	rng = rng or Random.new()

	if action.canDodge ~= false and rng:NextNumber() < target:GetStat("Dodge") then
		return { damage = 0, dodged = true, critical = false }
	end

	local raw = action.damage or 0
	for stat, coefficient in action.scaling or {} do
		raw += self:GetStat(stat) * coefficient
	end

	raw *= self:GetStat("Damage")

	local critical = rng:NextNumber() < self:GetStat("CriticalChance") + (action.bonusCrit or 0)
	if critical then
		raw *= self:GetStat("CriticalDamage")
	end

	local damageType = action.damageType or "Physical"
	if not action.ignoreDefense then
		local defense = target:GetStat(damageType == "Physical" and "Defense" or "MagicDefense")
		raw *= Character.DEFENSE_CONSTANT / (Character.DEFENSE_CONSTANT + math.max(defense, 0))
	end

	raw *= 1 - target:GetStat("DamageResistance")
	raw *= 1 - math.clamp(target.resistances[damageType] or 0, -1, 1)
	raw *= 0.9 + rng:NextNumber() * 0.2

	return { damage = math.max(1, math.floor(raw + 0.5)), dodged = false, critical = critical }
end

-- Calcula uma cura: valor base da ação somado à escala (normalmente pelo status Healing)
function Character:ComputeHeal(action)
	local amount = action.heal or 0

	for stat, coefficient in action.scaling or {} do
		amount += self:GetStat(stat) * coefficient
	end

	return math.floor(amount + 0.5)
end

-- Aplica o efeito de uma ação em um alvo (dano ou cura, status e remoção de efeitos); custo e recarga ficam fora
local function applyToTarget(self, action, target, rng)
	local result = {
		action = action,
		source = self,
		target = target,
		damage = 0,
		healed = 0,
		energyGained = 0,
		dodged = false,
		critical = false,
		cured = {},
	}

	local effectType = action.effectType or "Damage"

	if effectType == "Damage" then
		local hit = self:ComputeDamage(action, target, rng)
		result.dodged, result.critical = hit.dodged, hit.critical
		result.damage = hit.dodged and 0 or target:TakeDamage(hit.damage)
	elseif effectType == "Heal" then
		result.healed = target:Heal(self:ComputeHeal(action))
	end

	local status = action.statusEffect
	if status and target.isAlive and not result.dodged and (status.chance == nil or (rng or Random.new()):NextNumber() < status.chance) then
		target:AddStatus(status.id, status)
		result.statusApplied = status.displayName or status.id
	end

	for _, statusId in action.cure or {} do
		local effect = target.statusEffects[statusId]
		if effect then
			table.insert(result.cured, effect.name or statusId)
			target:RemoveStatus(statusId)
		end
	end

	result.killed = not target.isAlive
	return result
end

-- Paga o custo da ação uma única vez: energia, a ação do turno e a recarga
local function payCost(self, action)
	self:SpendEnergy(action.energyCost or 0)
	self.actionsRemaining -= 1

	if (action.cooldown or 0) > 0 then
		self.cooldowns[action.id] = action.cooldown
	end
end

-- Executa uma ação em um alvo (custo, recarga, efeito principal, energia e status) e devolve o resultado
function Character:UseAction(action, target, rng)
	local ok, reason = self:CanUse(action)
	if not ok then
		return nil, reason
	end

	payCost(self, action)
	local result = applyToTarget(self, action, target or self, rng)

	if action.energyGain then
		result.energyGained = self:GainEnergy(action.energyGain)
	end

	return result
end

-- Executa uma ação em área (todos os aliados ou todos os inimigos): paga uma vez e aplica em cada alvo
function Character:UseActionOnGroup(action, targets, rng)
	local ok, reason = self:CanUse(action)
	if not ok then
		return nil, reason
	end

	if #targets == 0 then
		return nil, "Nenhum alvo disponível."
	end

	payCost(self, action)

	local results = {}
	for _, target in targets do
		table.insert(results, applyToTarget(self, action, target, rng))
	end

	if action.energyGain then
		results[1].energyGained = self:GainEnergy(action.energyGain)
	end

	return results
end

-- Converte a definição de um item numa ação temporária, para reaproveitar todo o cálculo do UseAction
local function itemToAction(item)
	local effect = item.effect or {}
	local effectType = effect.damage and "Damage" or (effect.heal and "Heal") or "None"

	return {
		id = "item:" .. item.id,
		displayName = item.displayName or item.id,
		effectType = effectType,
		damage = effect.damage,
		heal = effect.heal,
		damageType = effect.damageType,
		scaling = effect.scaling,
		ignoreDefense = effect.ignoreDefense,
		canDodge = false,
		energyGain = effect.energy,
		statusEffect = effect.statusEffect,
		cure = effect.cure,
	}
end

-- Usa um item (gasta a ação do turno como qualquer ataque); a remoção de efeitos ("cure") vem junto da ação
function Character:UseItem(item, target, rng)
	local result, reason = self:UseAction(itemToAction(item), target or self, rng)
	if not result then
		return nil, reason
	end

	result.item = item
	return result
end

-- Liga o personagem a um Model; keepAlive impede o Humanoid do jogador de morrer (e respawnar) quando cai a 0
function Character:BindModel(model, keepAlive)
	self.model = model
	self.keepModelAlive = keepAlive == true
	self:Sync()
end

-- Espelha vida no Humanoid e energia, nível, classe e efeitos (em JSON) em Attributes do Model para a interface
function Character:Sync()
	local model = self.model
	if not model or not self.stats.MaxHealth then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = self.stats.MaxHealth
		humanoid.Health = (self.keepModelAlive and self.health <= 0) and 0.01 or self.health
	end

	model:SetAttribute("CharacterName", self.name)
	model:SetAttribute("Level", self.level)
	model:SetAttribute("Energy", self.energy)
	model:SetAttribute("MaxEnergy", self.maxEnergy)
	model:SetAttribute("IsAlive", self.isAlive)
	model:SetAttribute("ClassLabel", self.classLabel or self.name)

	local effects = {}
	for id, effect in self.statusEffects do
		table.insert(effects, {
			id = id,
			name = effect.name or id,
			description = effect.description or "",
			kind = effect.kind or "Buff",
			icon = effect.icon,
			turns = effect.turnsLeft,
		})
	end
	table.sort(effects, function(a, b) return a.id < b.id end)
	model:SetAttribute("StatusEffects", HttpService:JSONEncode(effects))
end

-- Cópia simples do estado para mandar ao client ou salvar
function Character:ToSnapshot()
	local effects = {}
	for id, effect in self.statusEffects do
		effects[id] = effect.turnsLeft
	end

	return {
		id = self.id,
		name = self.name,
		level = self.level,
		isPlayerTeam = self.isPlayerTeam,
		isAlive = self.isAlive,
		health = self.health,
		maxHealth = self.stats.MaxHealth,
		energy = self.energy,
		maxEnergy = self.maxEnergy,
		attributes = self.attributes:ToTable(),
		stats = table.clone(self.stats),
		statusEffects = effects,
	}
end

-- Aliases com os nomes antigos para não quebrar código que já usava a versão anterior
Character.takeDamage = Character.TakeDamage
Character.heal = Character.Heal
Character.resetTurn = Character.ResetTurn

return Character
