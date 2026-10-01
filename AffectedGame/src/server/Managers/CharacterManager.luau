local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Characters = Shared:WaitForChild("Characters")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Registry = require(Characters:WaitForChild("Registry"))
local PlayerLite = require(Characters:WaitForChild("players"):WaitForChild("PlayerLite"))

local CharacterManager = {}

-- Escolha padrão de quem ainda não abriu a tela e quantos feats cada personagem pode levar
local CONFIG = {
	DefaultClass = PlayerLite.DEFAULT_CLASS,
	DefaultRace = PlayerLite.DEFAULT_RACE,
	MaxFeats = 1,
}

CharacterManager.MAX_FEATS = CONFIG.MaxFeats

-- UserId -> dados no formato do PlayerLite:ToData() (class, race, feats, level...)
CharacterManager.selections = {}

-- Disparado com o Player do Roblox sempre que a escolha dele muda (o PartyManager usa para atualizar as vagas)
local changedEvent = Instance.new("BindableEvent")
CharacterManager.Changed = changedEvent.Event

-- Feats sem classId servem para qualquer classe; os outros só para a classe indicada
function CharacterManager.IsFeatAllowed(feat, classDef): boolean
	return feat.classId == nil or string.lower(feat.classId) == string.lower(classDef.id)
end

-- Valida o pedido do client pelo Registry e devolve a escolha limpa, ou nil e o motivo da recusa
local function validate(request)
	if type(request) ~= "table" then
		return nil, "Pedido inválido."
	end

	local classDef = Registry.Get("Classes", request.class)
	if not classDef then
		return nil, "Classe inválida."
	end

	local raceDef = Registry.Get("Races", request.race or CONFIG.DefaultRace)
	if not raceDef then
		return nil, "Raça inválida."
	end

	local feats = {}
	for _, featId in (type(request.feats) == "table" and request.feats or {}) do
		local feat = type(featId) == "string" and Registry.Get("Feats", featId)

		if not feat then
			return nil, "Feat inválido."
		end

		if not CharacterManager.IsFeatAllowed(feat, classDef) then
			return nil, string.format("%s não é um feat de %s.", feat.displayName or feat.id, classDef.displayName or classDef.id)
		end

		if not table.find(feats, feat.id) then
			table.insert(feats, feat.id)
		end
	end

	if #feats > CONFIG.MaxFeats then
		return nil, string.format("Escolha no máximo %d feat(s).", CONFIG.MaxFeats)
	end

	return { class = classDef.id, race = raceDef.id, feats = feats }, nil, classDef
end

-- Monta o PlayerLite com a escolha, guarda os dados e publica nos Attributes do jogador (lidos pela interface)
local function applySelection(robloxPlayer: Player, selection, classDef)
	local lite = PlayerLite.new(robloxPlayer.DisplayName, robloxPlayer):ApplyData(selection)
	local data = lite:ToData()

	CharacterManager.selections[robloxPlayer.UserId] = data

	local featNames = {}
	for _, featId in data.feats do
		local feat = Registry.Get("Feats", featId)
		table.insert(featNames, feat and feat.displayName or featId)
	end

	robloxPlayer:SetAttribute("CharacterClass", data.class)
	robloxPlayer:SetAttribute("CharacterClassLabel", classDef.displayName or classDef.id)
	robloxPlayer:SetAttribute("CharacterRace", data.race)
	robloxPlayer:SetAttribute("CharacterFeats", table.concat(data.feats, ","))
	robloxPlayer:SetAttribute("CharacterFeatLabel", table.concat(featNames, ", "))

	changedEvent:Fire(robloxPlayer)
	return data
end

-- Dados que vão no TeleportData de cada jogador (cópia, para ninguém alterar a escolha guardada)
function CharacterManager.GetData(userId: number)
	local data = CharacterManager.selections[userId]
	return data and table.clone(data) or { class = CONFIG.DefaultClass, race = CONFIG.DefaultRace, feats = {} }
end

-- Pedido do client para salvar o personagem: responde com os dados salvos ou com o motivo da recusa
local function onSubmitCharacter(robloxPlayer: Player, request)
	local selection, reason, classDef = validate(request)

	if not selection then
		Remotes.CharacterCreated:FireClient(robloxPlayer, nil, reason)
		return
	end

	local data = applySelection(robloxPlayer, selection, classDef)
	print(string.format("[CharacterManager] %s escolheu %s (%s) feats: %s", robloxPlayer.Name, data.class, data.race, table.concat(data.feats, ", ")))

	Remotes.CharacterCreated:FireClient(robloxPlayer, data, "Personagem salvo!")
end

-- Todo jogador começa com a classe/raça padrão, assim sempre existe uma escolha válida para o teleporte
local function onPlayerAdded(robloxPlayer: Player)
	local selection, reason, classDef = validate({ class = CONFIG.DefaultClass, race = CONFIG.DefaultRace, feats = {} })

	if selection then
		applySelection(robloxPlayer, selection, classDef)
	else
		warn("[CharacterManager] Escolha padrão inválida:", reason)
	end
end

for _, robloxPlayer in Players:GetPlayers() do
	task.spawn(onPlayerAdded, robloxPlayer)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(robloxPlayer)
	CharacterManager.selections[robloxPlayer.UserId] = nil
end)

Remotes.SubmitCharacter.OnServerEvent:Connect(onSubmitCharacter)

return CharacterManager
