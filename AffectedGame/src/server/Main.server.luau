local ReplicatedStorage = game:GetService("ReplicatedStorage")
local serverRoot = script.Parent
local managersFolder = serverRoot:WaitForChild("Managers", 10)


if not managersFolder then
	error("[SERVER] Pasta Managers não encontrada.")
end

local Shared = ReplicatedStorage:WaitForChild("shared")
local PlaceIds = require(Shared:WaitForChild("PlaceIds"))

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
	--------------------------------------------------------------------
	-- PLACE: GAME
	--------------------------------------------------------------------

	-- RunManager é o manager principal do Game: ele mesmo carrega os
	-- outros managers (BattleManager, EventManager, SceneManager) e
	-- começa a rodar a sequência de cenas da run assim que é requerido.
	local RunManager = loadManager("RunManager")

	if not RunManager then
		error("[SERVER] RunManager não conseguiu iniciar.")
	end

	print("[SERVER] Place Game inicializado.")
else
	--------------------------------------------------------------------
	-- PLACE: LOBBY
	--------------------------------------------------------------------

	local PartyManager = loadManager("PartyManager")

	if not PartyManager then
		error("[SERVER] PartyManager não conseguiu iniciar.")
	end

	-- RunManager NÃO é carregado aqui: ele espera um BattleCenter que só
	-- existe no place do Game (via BattleManager.Init), e agora também
	-- roda a sequência inteira de cenas sozinho ao ser requerido -- não
	-- faz sentido nenhum disso rodar enquanto os jogadores ainda estão
	-- só montando a Party no Lobby.

	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)

	if not remotesFolder then
		warn("[SERVER] A pasta ReplicatedStorage.Remotes não foi criada.")
	else
		local requiredPartyRemotes = {
			"CreateParty",
			"JoinParty",
			"LeaveParty",
			"StartGame",
			"PartyUpdated",
			"GetPublicParties",
		}

		for _, remoteName in ipairs(requiredPartyRemotes) do
			if not remotesFolder:FindFirstChild(remoteName) then
				warn("[SERVER] Remote FALTANDO:", remoteName)
			end
		end
	end

	print("[SERVER] Place Lobby inicializado.")

end
