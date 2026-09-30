local Characters = script.Parent

local Registry = {}

-- Caminho (a partir de Characters) de cada tipo de definição carregada pelo Registry
local FOLDERS = {
	Classes = { "classes" },
	Races = { "races" },
	Feats = { "Feats" },
	Actions = { "FightActions" },
	Enemies = { "enemies", "instances" },
	Items = { "Items" },
}

local caches = {}

-- Procura um filho pelo nome sem diferenciar maiúsculas (instances/Instances, Feats/feats)
local function findChild(parent, name)
	local exact = parent:FindFirstChild(name)
	if exact then
		return exact
	end

	local lower = string.lower(name)
	for _, child in parent:GetChildren() do
		if string.lower(child.Name) == lower then
			return child
		end
	end

	return nil
end

-- Carrega uma única vez todos os ModuleScripts da pasta do tipo e indexa por nome do módulo e por id, sem diferenciar maiúsculas
local function load(kind)
	local cache = caches[kind]
	if cache then
		return cache
	end

	cache = {}
	caches[kind] = cache

	local path = FOLDERS[kind]
	if not path then
		warn("[Registry] Tipo desconhecido:", kind)
		return cache
	end

	local folder = Characters
	for _, name in path do
		folder = folder and findChild(folder, name)
	end

	if not folder then
		warn("[Registry] Pasta não encontrada para", kind, "->", table.concat(path, "/"))
		return cache
	end

	for _, module in folder:GetDescendants() do
		if module:IsA("ModuleScript") then
			local ok, definition = pcall(require, module)

			if ok and type(definition) == "table" then
				cache[string.lower(module.Name)] = definition

				if type(definition.id) == "string" then
					cache[string.lower(definition.id)] = definition
				end
			else
				warn("[Registry] Falha ao carregar", module:GetFullName(), ok and "(não retornou table)" or definition)
			end
		end
	end

	return cache
end

-- Busca uma definição pelo id ou nome do módulo (ex: Registry.Get("Classes", "Fighter"))
function Registry.Get(kind, id)
	if type(id) ~= "string" then
		return nil
	end

	return load(kind)[string.lower(id)]
end

-- Lista todas as definições únicas de um tipo (útil para a tela de customização)
function Registry.All(kind)
	local seen, list = {}, {}

	for _, definition in load(kind) do
		if not seen[definition] then
			seen[definition] = true
			table.insert(list, definition)
		end
	end

	return list
end

return Registry
