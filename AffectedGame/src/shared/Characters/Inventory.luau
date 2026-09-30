local Registry = require(script.Parent.Registry)

local Inventory = {}
Inventory.__index = Inventory

Inventory.DEFAULT_SLOTS = 8
Inventory.DEFAULT_STACK = 5

-- Cria o inventário: "slots" é quantos itens diferentes cabem; data opcional no formato { [id] = quantidade }
function Inventory.new(slots, data)
	local self = setmetatable({}, Inventory)

	self.slots = slots or Inventory.DEFAULT_SLOTS
	self.items = {}
	self.order = {}
	self.onChanged = nil

	if type(data) == "table" then
		for id, amount in data do
			if type(id) == "string" and type(amount) == "number" then
				self:Add(id, amount)
			end
		end
	end

	return self
end

-- Resolve o id pelo Registry (aceita qualquer maiúscula/minúscula) e devolve a definição e o id oficial
function Inventory.Resolve(id)
	local definition = Registry.Get("Items", id)
	return definition, definition and definition.id
end

local function notify(self)
	if self.onChanged then
		self.onChanged(self)
	end
end

-- Adiciona até o limite da pilha do item e dos slots; devolve quanto entrou de fato (0 se não coube)
function Inventory:Add(id, amount)
	amount = math.floor(amount or 1)
	local definition, itemId = Inventory.Resolve(id)

	if not definition then
		warn("[Inventory] Item não existe:", id)
		return 0
	end

	if amount <= 0 then
		return 0
	end

	local current = self.items[itemId]
	if not current and #self.order >= self.slots then
		return 0
	end

	local added = math.min(amount, (definition.maxStack or Inventory.DEFAULT_STACK) - (current or 0))
	if added <= 0 then
		return 0
	end

	if not current then
		table.insert(self.order, itemId)
	end

	self.items[itemId] = (current or 0) + added
	notify(self)
	return added
end

-- Remove uma quantidade; falha (false) se não houver o suficiente, e libera o slot quando zera
function Inventory:Remove(id, amount)
	amount = math.floor(amount or 1)
	local _, itemId = Inventory.Resolve(id)
	local current = itemId and self.items[itemId] or 0

	if amount <= 0 or current < amount then
		return false
	end

	if current == amount then
		self.items[itemId] = nil
		table.remove(self.order, table.find(self.order, itemId))
	else
		self.items[itemId] = current - amount
	end

	notify(self)
	return true
end

function Inventory:Count(id)
	local _, itemId = Inventory.Resolve(id)
	return itemId and self.items[itemId] or 0
end

function Inventory:Has(id, amount)
	return self:Count(id) >= (amount or 1)
end

function Inventory:IsFull()
	return #self.order >= self.slots
end

-- Lista na ordem em que os itens entraram, no formato { { id, count }, ... } (é o que vai para o client)
function Inventory:List()
	local list = {}

	for _, itemId in self.order do
		table.insert(list, { id = itemId, count = self.items[itemId] })
	end

	return list
end

-- Cópia simples { [id] = quantidade } para salvar no PlayerLite/DataManager
function Inventory:ToData()
	return table.clone(self.items)
end

-- Junta os modificadores dos itens que dão bônus passivo só por estarem no inventário (relíquias)
function Inventory:GetModifiers()
	local modifiers = {}

	for _, itemId in self.order do
		local definition = Registry.Get("Items", itemId)
		for _, mod in (definition and definition.modifiers) or {} do
			table.insert(modifiers, mod)
		end
	end

	return modifiers
end

return Inventory
