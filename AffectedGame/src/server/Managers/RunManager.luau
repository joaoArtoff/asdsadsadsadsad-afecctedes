local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Characters = ReplicatedStorage:WaitForChild("shared"):WaitForChild("Characters")
local PlayersFolder = Characters:WaitForChild("players")
local PlayerLite = require(PlayersFolder:WaitForChild("PlayerLite"))
local PlayerCharacter = require(PlayersFolder:WaitForChild("Player"))
local Enemy = require(Characters:WaitForChild("enemies"):WaitForChild("Enemy"))

local managersFolder = script.Parent
local BattleManager = require(managersFolder:WaitForChild("BattleManager"))
local SceneManager = require(managersFolder:WaitForChild("SceneManager"))
local EventManager = require(managersFolder:WaitForChild("EventManager"))

local RunManager = {
	Players = {},
	ByUserId = {},
	CurrentScene = 0,
	BattlesCleared = 0,
	State = "Idle",
}

-- Nome da área (banner), espera da party (sem Lobby / com Lobby), pausa entre cenas e cura entre batalhas
local CONFIG = {
	AreaName = "Floresta",
	PartyGraceTime = 4,
	PartyWaitTimeout = 20,
	SceneDelay = 3,
	RestHealPercent = 0.25,

	-- Itens com que cada jogador começa a run (se não vier inventário do Lobby)
	-- Personagem usado ao testar o place do Game direto no Studio (sem vir do Lobby);
	-- troque a classe/feat aqui para testar outras combinações
	StudioCharacter = {
		class = "bard",
		race = "Human",
		feats = { "cancao_de_guerra" },
	},

	StartingItems = {
		HealthPotion = 2,
		Antidote = 1,
		FireBomb = 1,
	},
}

-- Inimigos de cada batalha da run (índice = número da batalha); a última lista se repete se acabarem
local ENCOUNTERS = {
	{ "Zombie" },
	{ "Goblin", "Zombie" },
	{ "Goblin", "Zombie", "Goblin" },
}

-- TeleportData bruto que o Lobby mandou (partyId, leaderUserId, memberUserIds e, no futuro, dados de cada personagem)
local function getTeleportData(robloxPlayer: Player)
	local ok, joinData = pcall(robloxPlayer.GetJoinData, robloxPlayer)
	local data = ok and type(joinData) == "table" and joinData.TeleportData
	return type(data) == "table" and data or nil
end

-- Dados de personagem de um jogador: aceita characters[UserId] ou um bloco único
local function readJoinData(robloxPlayer: Player)
	local data = getTeleportData(robloxPlayer)

	if data and type(data.characters) == "table" then
		return data.characters[tostring(robloxPlayer.UserId)]
	end

	return data
end

-- Espera a party inteira chegar do teleporte (cada membro chega num momento diferente), com tempo limite
local function waitForParty(partyData)
	local expected = partyData and partyData.memberUserIds
	if type(expected) ~= "table" or #expected == 0 then
		task.wait(CONFIG.PartyGraceTime)
		return
	end

	local deadline = os.clock() + CONFIG.PartyWaitTimeout
	while os.clock() < deadline do
		local missing = 0
		for _, userId in expected do
			if not Players:GetPlayerByUserId(tonumber(userId) or 0) then
				missing += 1
			end
		end

		if missing == 0 then
			return
		end

		task.wait(0.5)
	end

	warn("[RunManager] Nem todos os membros da party chegaram; começando mesmo assim.")
end

-- Passa o líder da party do Lobby para o EventManager (só ele escolhe nas telas de evento)
local function applyPartyLeader(partyData)
	local leaderId = partyData and tonumber(partyData.leaderUserId)
	local leader = leaderId and Players:GetPlayerByUserId(leaderId)

	EventManager.Leader = leader
	if leader then
		print("[RunManager] Líder da party:", leader.Name)
	end
end

-- Registra o Character de um jogador na run (PlayerLite + classe/raça/feats vindos do Lobby ou do teste no Studio)
function RunManager.AddPlayer(robloxPlayer: Player)
	local existing = RunManager.ByUserId[robloxPlayer.UserId]
	if existing then
		return existing
	end

	local joinData = readJoinData(robloxPlayer)
	if not joinData and RunService:IsStudio() then
		joinData = CONFIG.StudioCharacter
	end

	local lite = PlayerLite.new(robloxPlayer.DisplayName, robloxPlayer):ApplyData(joinData)
	local ok, character = pcall(PlayerCharacter.new, lite)

	if not ok then
		warn("[RunManager] Falha ao criar Character de", robloxPlayer.Name, ":", character)
		return nil
	end

	if next(character.inventory.items) == nil then
		for itemId, amount in CONFIG.StartingItems do
			character:GiveItem(itemId, amount)
		end
	end

	table.insert(RunManager.Players, character)
	RunManager.ByUserId[robloxPlayer.UserId] = character

	print(string.format(
		"[RunManager] %s entrou como %s (%s) feats: [%s] - HP %d, ATK %.1f, DEF %.1f, INI %.1f",
		character.name, tostring(character.classId), tostring(character.raceId), table.concat(lite.feats, ", "),
		character.stats.MaxHealth, character:GetStat("Attack"), character:GetStat("Defense"), character:GetStat("Initiative")
	))

	return character
end

-- Mantido do código antigo: monta os Characters a partir de uma lista de PlayerLite
function RunManager.BuildPlayableCharacters(playerLites)
	table.clear(RunManager.Players)
	table.clear(RunManager.ByUserId)

	for _, lite in playerLites do
		local character = PlayerCharacter.new(lite)
		table.insert(RunManager.Players, character)

		if lite.robloxPlayer then
			RunManager.ByUserId[lite.robloxPlayer.UserId] = character
		end
	end

	return RunManager.Players
end

-- Jogadores ainda vivos e conectados, que vão para a próxima batalha
function RunManager.GetParty()
	local party = {}

	for _, character in RunManager.Players do
		local player = character.robloxPlayer
		if character.isAlive and player and player.Parent then
			table.insert(party, character)
		end
	end

	return party
end

-- Cura uma porcentagem da vida máxima de quem sobreviveu
function RunManager.RestParty(percent: number)
	for _, character in RunManager.GetParty() do
		character:Heal(character.stats.MaxHealth * percent)
	end
end

-- Encerra a run e avisa os clients pelos atributos
function RunManager.EndRun(reason: string)
	if RunManager.State == "Ended" then
		return
	end

	RunManager.State = "Ended"
	print("[RunManager] Run encerrada:", reason)

	for _, player in Players:GetPlayers() do
		player:SetAttribute("RunResult", reason)
		player:SetAttribute("BattleTurnText", reason == "Completed" and "Run Complete!" or "Run Over")
	end
end

-- Avança para a próxima cena do SceneManager e despacha para o manager certo (Battle ou Event)
function RunManager.NextScene()
	if RunManager.State ~= "Running" then
		return
	end

	local scene = SceneManager:GetNextScene()
	if not scene then
		RunManager.EndRun("Completed")
		return
	end

	RunManager.CurrentScene = SceneManager:GetCurrentIndex()
	Workspace:SetAttribute("AreaName", CONFIG.AreaName)
	Workspace:SetAttribute("AreaProgress", string.format("%d/%d", RunManager.CurrentScene, SceneManager:GetTotalScenes()))
	print("[RunManager] Cena", RunManager.CurrentScene, "->", scene.sceneType)

	local function advance()
		scene:Finish()
		task.delay(CONFIG.SceneDelay, RunManager.NextScene)
	end

	if scene.sceneType == "Battle" then
		local battleIndex = RunManager.BattlesCleared + 1
		local encounter = {}

		for _, enemyId in ENCOUNTERS[math.min(battleIndex, #ENCOUNTERS)] do
			local enemy = Enemy.Create(enemyId, { level = battleIndex })
			if enemy then
				table.insert(encounter, enemy)
			end
		end

		local started = BattleManager.StartBattle(RunManager.GetParty(), encounter, function(outcome)
			if outcome ~= "Victory" then
				RunManager.EndRun("Defeat")
				return
			end

			RunManager.BattlesCleared += 1
			RunManager.RestParty(CONFIG.RestHealPercent)
			advance()
		end)

		if not started then
			RunManager.EndRun("Error")
		end
	elseif scene.sceneType == "Event" then
		EventManager:RunEvent(RunManager, scene, advance)
	else
		warn("[RunManager] Tipo de cena desconhecido:", scene.sceneType)
		advance()
	end
end

-- Inicia a run: prepara a arena, espera a party chegar, cria os Characters e roda a primeira cena
function RunManager.Start()
	if RunManager.State ~= "Idle" then
		return
	end

	RunManager.State = "Gathering"

	task.spawn(function()
		if not BattleManager.Init() then
			warn("[RunManager] BattleManager não inicializou; run cancelada.")
			RunManager.State = "Idle"
			return
		end

		while #Players:GetPlayers() == 0 do
			Players.PlayerAdded:Wait()
		end

		local partyData = getTeleportData(Players:GetPlayers()[1])
		waitForParty(partyData)

		for _, player in Players:GetPlayers() do
			RunManager.AddPlayer(player)
		end

		applyPartyLeader(partyData)

		RunManager.State = "Running"
		SceneManager:StartRun()
		RunManager.NextScene()
	end)
end

-- Quem chega com a run já rodando entra na próxima batalha; se todos saírem a run acaba
Players.PlayerAdded:Connect(function(player)
	if RunManager.State == "Running" then
		RunManager.AddPlayer(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local character = RunManager.ByUserId[player.UserId]
	if character then
		character.left = true
	end

	task.defer(function()
		if RunManager.State == "Running" and #Players:GetPlayers() == 0 then
			RunManager.EndRun("Abandoned")
		end
	end)
end)

RunManager.Start()

return RunManager
