local Attributes = {}
Attributes.__index = Attributes

Attributes.List = { "Str", "Dex", "Con", "Int", "Wis" }

-- Cria um conjunto de atributos a partir de uma table simples ou de outro Attributes (vira uma cópia)
function Attributes.new(data)
	data = data or {}
	local self = setmetatable({}, Attributes)

	for _, key in Attributes.List do
		self[key] = data[key]
	end

	return self
end

-- Leitura segura para as fórmulas: atributo não definido conta como 0
function Attributes:Get(name)
	return self[name] or 0
end

-- Define um atributo conhecido, avisando se o nome não existir na lista
function Attributes:Set(name, value)
	if not table.find(Attributes.List, name) then
		warn("[Attributes] Tentando definir um atributo desconhecido: " .. tostring(name))
		return
	end

	self[name] = value
end

-- Soma outro conjunto (bônus de raça, itens, level up) e devolve um novo Attributes sem alterar o original
function Attributes:Add(other)
	local result = Attributes.new(self)

	if type(other) == "table" then
		for _, key in Attributes.List do
			if type(other[key]) == "number" then
				result[key] = (result[key] or 0) + other[key]
			end
		end
	end

	return result
end

-- Avisa se uma classe esqueceu de definir algum atributo antes do balanceamento final
function Attributes:IsComplete()
	for _, key in Attributes.List do
		if self[key] == nil then
			return false
		end
	end

	return true
end

-- Versão sem metatable, útil para mandar ao client ou salvar no DataManager
function Attributes:ToTable()
	local result = {}

	for _, key in Attributes.List do
		result[key] = self[key]
	end

	return result
end

return Attributes
