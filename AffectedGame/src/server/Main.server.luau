local ReplicatedStorage = game:GetService("ReplicatedStorage")
local serverRoot = script.Parent
local managersFolder = serverRoot:WaitForChild("Managers", 10)

if not managersFolder then
	error("[SERVER] Pasta Managers não encontrada.")
end

local Shared = ReplicatedStorage:WaitForChild("shared")
local PlaceIds = require(Shared:WaitForChild("PlaceIds"))

-- Carrega um manager com pcall para um erro num manager não derrubar o servidor inteiro
local function loadManager(managerName: string)
	local managerModule = managersFolder:WaitForChild(managerName, 10)

	if not managerModule then
		warn("[SERVER] Manager não encontrado:", managerName)
		return nil
	end

	local success, result = pcall(require, managerModule)

	if not success then
		warn("[SERVER] ERRO ao carregar", managerName, ":", result)
		return nil
	end

	return result
end

-- Só existem dois places hoje (Lobby e Game), então tudo que não é o Game cai
-- no branch do Lobby -- assim não precisamos saber o PlaceId do Lobby também.
local isGamePlace = game.PlaceId == PlaceIds.Game

if isGamePlace then
	-- Place Game: o RunManager carrega BattleManager, EventManager e SceneManager
	-- e começa a sequência de cenas da run assim que é requerido.
	local RunManager = loadManager("RunManager")

	if not RunManager then
		error("[SERVER] RunManager não conseguiu iniciar.")
	end

	print("[SERVER] Place Game inicializado.")
else
	-- Place Lobby: escolha de personagem e party. O CharacterManager vem antes
	-- porque o PartyManager lê a escolha de cada membro na hora do teleporte.
	local CharacterManager = loadManager("CharacterManager")

	if not CharacterManager then
		error("[SERVER] CharacterManager não conseguiu iniciar.")
	end

	local PartyManager = loadManager("PartyManager")

	if not PartyManager then
		error("[SERVER] PartyManager não conseguiu iniciar.")
	end

	-- Confere se os remotes do lobby existem (declarados no lobby.project.json)
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)

	if not remotesFolder then
		warn("[SERVER] A pasta ReplicatedStorage.Remotes não foi criada.")
	else
		local requiredLobbyRemotes = {
			"CreateParty",
			"JoinParty",
			"LeaveParty",
			"StartGame",
			"PartyUpdated",
			"GetPublicParties",
			"SubmitCharacter",
			"CharacterCreated",
		}

		for _, remoteName in ipairs(requiredLobbyRemotes) do
			if not remotesFolder:FindFirstChild(remoteName) then
				warn("[SERVER] Remote FALTANDO:", remoteName)
			end
		end
	end

	print("[SERVER] Place Lobby inicializado.")
end
