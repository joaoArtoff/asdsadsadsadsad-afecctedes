local Characters = script.Parent.Parent
local Character = require(Characters.Character)
local Attributes = require(Characters.Attributes)
local Registry = require(Characters.Registry)
local Inventory = require(Characters.Inventory)

local HttpService = game:GetService("HttpService")

local Player = setmetatable({}, { __index = Character })
Player.__index = Player

Player.DEFAULT_CLASS = "Fighter"
Player.DEFAULT_ACTIONS = { "NormalAttack", "StrongAttack", "Focus" }
Player.STARTING_ENERGY = 2
Player.INVENTORY_SLOTS = 8

-- XP necessária para sair do nível atual
function Player.XPToNext(level)
	return 100 * level
end

-- Junta os modificadores de uma lista de ids de feats numa lista única
local function gatherModifiers(entries, kind, ownerName)
	local result = {}

	for _, entry in entries or {} do
		local definition = type(entry) == "string" and Registry.Get(kind, entry) or entry

		if type(definition) == "table" and type(definition.modifiers) == "table" then
			for _, mod in definition.modifiers do
				table.insert(result, mod)
			end
		elseif type(entry) == "string" then
			warn(string.format("[Player] %s não encontrado para %s: %s", kind, ownerName, entry))
		end
	end

	return result
end

-- Converte o baseStats das classes (maxHealth, attack, defense) para status fixos do Character
local CLASS_STAT_KEYS = {
	maxHealth = "MaxHealth",
	attack = "Attack",
	defense = "Defense",
	magicAttack = "MagicAttack",
	magicDefense = "MagicDefense",
}

local function classStats(classDef)
	local stats = {}

	for key, value in classDef.baseStats or {} do
		local stat = CLASS_STAT_KEYS[key]
		if stat then
			stats[stat] = value
		end
	end

	return stats
end

-- Monta o Character jogável do PlayerLite: atributos da classe + bônus da raça, modificadores da raça, feats e itens
function Player.new(playerLite)
	assert(type(playerLite) == "table", "[Player] PlayerLite inválido")

	local classDef = Registry.Get("Classes", playerLite.class)
	if not classDef then
		warn(string.format("[Player] Classe '%s' não existe, usando %s.", tostring(playerLite.class), Player.DEFAULT_CLASS))
		classDef = Registry.Get("Classes", Player.DEFAULT_CLASS)
	end
	assert(classDef, "[Player] Nenhuma classe encontrada em Characters/classes")

	local raceDef = Registry.Get("Races", playerLite.race)
	if not raceDef and playerLite.race then
		warn(string.format("[Player] Raça '%s' não existe, seguindo sem bônus.", tostring(playerLite.race)))
	end

	local robloxPlayer = playerLite.robloxPlayer
	local self = Character.new({
		id = robloxPlayer and ("Player_" .. robloxPlayer.UserId) or playerLite.name,
		name = playerLite.name,
		isPlayerTeam = true,
		level = playerLite.level or 1,
		attributes = Attributes.new(classDef.Attributes):Add(raceDef and raceDef.attributes),
		stats = classStats(classDef),
		actions = classDef.actions or Player.DEFAULT_ACTIONS,
		energy = Player.STARTING_ENERGY,
		modifiers = {
			race = raceDef and raceDef.modifiers or {},
			feats = gatherModifiers(playerLite.feats, "Feats", playerLite.name),
		},
	})
	setmetatable(self, Player)

	self.lite = playerLite
	self.robloxPlayer = robloxPlayer
	self.classId = classDef.id
	self.classLabel = classDef.displayName or classDef.name or classDef.id
	self.raceId = raceDef and raceDef.id
	self.xp = playerLite.xp or 0

	-- Inventário próprio: toda mudança atualiza o PlayerLite, os bônus passivos e a interface do jogador
	self.inventory = Inventory.new(Player.INVENTORY_SLOTS, playerLite.inventory)
	self.inventory.onChanged = function()
		self:OnInventoryChanged()
	end
	self:OnInventoryChanged()

	return self
end

-- Reação a qualquer mudança no inventário: salva no PlayerLite, reaplica relíquias e replica para o client
function Player:OnInventoryChanged()
	self.lite.inventory = self.inventory:ToData()
	self.modifierSources.items = self.inventory:GetModifiers()
	self:RecalculateStats(false)
	self:SyncInventory()
end

-- Manda a lista do inventário (JSON em um Attribute do Player do Roblox); o client lê os detalhes pelo Registry
function Player:SyncInventory()
	local robloxPlayer = self.robloxPlayer
	if not robloxPlayer or not robloxPlayer.Parent then
		return
	end

	robloxPlayer:SetAttribute("Inventory", HttpService:JSONEncode(self.inventory:List()))
	robloxPlayer:SetAttribute("InventorySlots", self.inventory.slots)
end

-- Atalho para dar itens (eventos, baús, loja); devolve quanto coube
function Player:GiveItem(itemId, amount)
	return self.inventory:Add(itemId, amount or 1)
end

-- Soma XP, sobe quantos níveis couberem (recalculando status e ganhando a vida extra) e devolve os níveis ganhos
function Player:AddXP(amount)
	self.xp += math.max(amount or 0, 0)
	local gained = 0

	while self.xp >= Player.XPToNext(self.level) do
		self.xp -= Player.XPToNext(self.level)
		self.level += 1
		gained += 1
	end

	if gained > 0 then
		self:RecalculateStats(false)
	end

	self.lite.level = self.level
	self.lite.xp = self.xp
	return gained
end

-- Reaplica feats e itens depois que o PlayerLite mudar (ex: ganhou um feat no meio da run)
function Player:RefreshModifiers()
	self.modifierSources.feats = gatherModifiers(self.lite.feats, "Feats", self.name)
	self.modifierSources.items = self.inventory:GetModifiers()
	self:RecalculateStats(false)
end

return Player
