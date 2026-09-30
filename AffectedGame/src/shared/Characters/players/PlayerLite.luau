local PlayerLite = {}
PlayerLite.__index = PlayerLite

PlayerLite.DEFAULT_RACE = "Human"
PlayerLite.DEFAULT_CLASS = "Fighter"

-- Dados leves do jogador (escolhas de customização e progresso), sem nenhum cálculo de combate
function PlayerLite.new(name, robloxPlayer)
	local self = setmetatable({}, PlayerLite)

	self.name = name
	self.robloxPlayer = robloxPlayer
	self.level = 1
	self.xp = 0
	self.isHostile = false

	self.race = PlayerLite.DEFAULT_RACE
	self.class = PlayerLite.DEFAULT_CLASS

	self.feats = {}
	self.inventory = {} -- { [itemId] = quantidade }
	self.customization = {}

	return self
end

function PlayerLite:SetRace(race)
	self.race = race
end

function PlayerLite:SetClass(class)
	self.class = class
end

function PlayerLite:SetCustomization(data)
	for key, value in data do
		self.customization[key] = value
	end
end

-- Feats não se repetem; remover procura pelo id
function PlayerLite:AddFeat(featId)
	if not table.find(self.feats, featId) then
		table.insert(self.feats, featId)
	end
end

function PlayerLite:RemoveFeat(featId)
	local index = table.find(self.feats, featId)
	if index then
		table.remove(self.feats, index)
	end
end

-- Soma itens no formato { [id] = quantidade }; o limite de pilha/slots é aplicado pelo Inventory na run
function PlayerLite:AddItem(itemId, amount)
	if type(itemId) ~= "string" then
		return
	end

	self.inventory[itemId] = (self.inventory[itemId] or 0) + (amount or 1)
end

-- Aplica dados vindos de fora (TeleportData do Lobby ou DataManager) validando o tipo de cada campo
function PlayerLite:ApplyData(data)
	if type(data) ~= "table" then
		return self
	end

	if type(data.race) == "string" then self.race = data.race end
	if type(data.class) == "string" then self.class = data.class end
	if type(data.level) == "number" then self.level = math.max(1, math.floor(data.level)) end
	if type(data.xp) == "number" then self.xp = math.max(0, data.xp) end

	if type(data.feats) == "table" then
		for _, featId in data.feats do
			if type(featId) == "string" then
				self:AddFeat(featId)
			end
		end
	end

	if type(data.customization) == "table" then
		self:SetCustomization(data.customization)
	end

	if type(data.inventory) == "table" then
		for itemId, amount in data.inventory do
			if type(itemId) == "string" and type(amount) == "number" then
				self:AddItem(itemId, math.floor(amount))
			end
		end
	end

	return self
end

-- Versão serializável (sem a referência ao Player do Roblox) para salvar ou mandar no teleport
function PlayerLite:ToData()
	return {
		name = self.name,
		level = self.level,
		xp = self.xp,
		race = self.race,
		class = self.class,
		feats = table.clone(self.feats),
		customization = table.clone(self.customization),
		inventory = table.clone(self.inventory),
	}
end

return PlayerLite
