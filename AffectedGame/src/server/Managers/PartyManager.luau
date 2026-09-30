-- SERVIÇOS

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- SHARED / REMOTES

local Shared = ReplicatedStorage:WaitForChild("shared")

local Remotes =
	require(
		Shared:WaitForChild("Remotes") :: ModuleScript
	)

local PlaceIds =
	require(
		Shared:WaitForChild("PlaceIds") :: ModuleScript
	)

-- CONFIGURAÇÕES

local GAMEPLAY_PLACE_ID = PlaceIds.Game

local MAX_PLAYERS = 4

-- REMOTE FUNCTION
-- USADO PARA LISTAR AS PARTIES PÚBLICAS

local GetPublicParties = Remotes.GetPublicParties

-- PARTY MANAGER

local PartyManager = {}

-- PARTIES
--
-- partyId ->
--
-- {
--     id = "party_123456",
--     leaderUserId = 123,
--     memberUserIds = {}
-- }

PartyManager.parties = {}

-- JOGADOR -> PARTY
--
-- UserId -> partyId

PartyManager.playerToParty = {}

-- GERAR ID DA PARTY

local function generatePartyId()

	local id

	repeat

		id =
			"party_"
			..
			tostring(
				math.random(
					100000,
					999999
				)
			)

	until not PartyManager.parties[id]

	return id

end

-- ENVIAR ATUALIZAÇÃO PARA TODOS
-- OS MEMBROS DA PARTY

local function broadcastPartyUpdate(party)

	if not party then
		return
	end

	for _, userId in ipairs(
		party.memberUserIds
	) do

		local robloxPlayer =
			Players:GetPlayerByUserId(
				userId
			)

		if robloxPlayer then

			Remotes.PartyUpdated:FireClient(
				robloxPlayer,
				{
					partyId =
						party.id,

					leaderUserId =
						party.leaderUserId,

					memberUserIds =
						party.memberUserIds,
				}
			)

		end

	end

end

-- RETORNAR PARTIES PÚBLICAS

local function getPublicParties()

	local publicParties = {}

	for partyId, party in pairs(
		PartyManager.parties
	) do

		local leaderPlayer =
			Players:GetPlayerByUserId(
				party.leaderUserId
			)

		local leaderName =
			"Player"

		-- NOME DO LÍDER

		if leaderPlayer then

			leaderName =
				leaderPlayer.DisplayName

		end

		-- ADICIONAR À LISTA

		table.insert(
			publicParties,
			{
				partyId =
					partyId,

				leaderUserId =
					party.leaderUserId,

				leaderName =
					leaderName,

				memberCount =
					#party.memberUserIds,

				maxPlayers =
					MAX_PLAYERS,
			}
		)

	end

	return publicParties

end

-- CLIENT PEDE A LISTA DE PARTIES

GetPublicParties.OnServerInvoke =
	function()

		return getPublicParties()

	end

-- CRIAR PARTY

local function onCreateParty(
	robloxPlayer
)

	-- JOGADOR JÁ ESTÁ EM UMA PARTY

	if PartyManager.playerToParty[
		robloxPlayer.UserId
	] then

		warn(
			"[PartyManager]",
			robloxPlayer.Name,
			"tentou criar uma Party, mas já está em uma."
		)

		return

	end

	-- GERAR PARTY

	local partyId =
		generatePartyId()

	local party = {

		id =
			partyId,

		leaderUserId =
			robloxPlayer.UserId,

		memberUserIds = {
			robloxPlayer.UserId
		},

	}

	-- REGISTRAR PARTY

	PartyManager.parties[
		partyId
	] = party

	PartyManager.playerToParty[
		robloxPlayer.UserId
	] = partyId

	print(
		"[PartyManager] Party criada:",
		partyId,
		"por",
		robloxPlayer.Name
	)

	-- ATUALIZAR CLIENT

	broadcastPartyUpdate(
		party
	)

end

-- ENTRAR EM PARTY

local function onJoinParty(
	robloxPlayer,
	partyId
)

	-- PROTEÇÃO

	if type(partyId) ~= "string" then

		warn(
			"[PartyManager] partyId inválido recebido de",
			robloxPlayer.Name
		)

		return

	end

	-- ENCONTRAR PARTY

	local party =
		PartyManager.parties[
			partyId
		]

	if not party then

		warn(
			"[PartyManager] Party não encontrada:",
			partyId
		)

		return

	end

	-- PLAYER JÁ ESTÁ EM PARTY

	if PartyManager.playerToParty[
		robloxPlayer.UserId
	] then

		return

	end

	-- PARTY CHEIA

	if #party.memberUserIds
		>= MAX_PLAYERS then

		warn(
			"[PartyManager] Party cheia:",
			partyId
		)

		return

	end

	-- ADICIONAR JOGADOR

	table.insert(
		party.memberUserIds,
		robloxPlayer.UserId
	)

	PartyManager.playerToParty[
		robloxPlayer.UserId
	] = partyId

	print(
		"[PartyManager]",
		robloxPlayer.Name,
		"entrou na Party",
		partyId
	)

	-- ATUALIZA TODOS

	broadcastPartyUpdate(
		party
	)

end

-- SAIR DA PARTY

local function onLeaveParty(
	robloxPlayer
)

	local userId =
		robloxPlayer.UserId

	-- ENCONTRAR PARTY DO JOGADOR

	local partyId =
		PartyManager.playerToParty[
			userId
		]

	if not partyId then
		return
	end

	local party =
		PartyManager.parties[
			partyId
		]

	-- PARTY NÃO EXISTE MAIS

	if not party then

		PartyManager.playerToParty[
			userId
		] = nil

		Remotes.PartyUpdated:FireClient(
			robloxPlayer,
			nil
		)

		return

	end

	-- REMOVER DA LISTA

	for index, memberUserId in ipairs(
		party.memberUserIds
	) do

		if memberUserId ==
			userId then

			table.remove(
				party.memberUserIds,
				index
			)

			break

		end

	end

	-- REMOVER RELAÇÃO PLAYER -> PARTY

	PartyManager.playerToParty[
		userId
	] = nil

	-- AVISAR O CLIENT QUE ELE SAIU

	Remotes.PartyUpdated:FireClient(
		robloxPlayer,
		nil
	)

	print(
		"[PartyManager]",
		robloxPlayer.Name,
		"saiu da Party",
		partyId
	)

	-- PARTY FICOU VAZIA

	if #party.memberUserIds == 0 then

		PartyManager.parties[
			partyId
		] = nil

		print(
			"[PartyManager] Party removida:",
			partyId
		)

		return

	end

	-- LÍDER SAIU
	-- PROMOVE O PRÓXIMO

	if party.leaderUserId ==
		userId then

		party.leaderUserId =
			party.memberUserIds[1]

		print(
			"[PartyManager] Novo líder:",
			party.leaderUserId
		)

	end

	-- ATUALIZA QUEM FICOU

	broadcastPartyUpdate(
		party
	)

end

-- INICIAR PARTIDA

local function onStartGame(
	robloxPlayer
)

	-- ENCONTRAR PARTY

	local partyId =
		PartyManager.playerToParty[
			robloxPlayer.UserId
		]

	if not partyId then

		warn(
			"[PartyManager] Jogador não está em Party."
		)

		return

	end

	local party =
		PartyManager.parties[
			partyId
		]

	if not party then
		return
	end

	-- SOMENTE O LÍDER

	if party.leaderUserId
		~= robloxPlayer.UserId then

		warn(
			"[PartyManager]",
			robloxPlayer.Name,
			"tentou iniciar sem ser líder."
		)

		return

	end

	-- PEGAR PLAYERS DA PARTY

	local robloxPlayers = {}

	for _, userId in ipairs(
		party.memberUserIds
	) do

		local member =
			Players:GetPlayerByUserId(
				userId
			)

		if member then

			table.insert(
				robloxPlayers,
				member
			)

		end

	end

	-- SEGURANÇA

	if #robloxPlayers == 0 then
		return
	end

	-- SERVIDOR RESERVADO

	local options =
		Instance.new(
			"TeleportOptions"
		)

	options.ShouldReserveServer =
		true

	-- DADOS DA PARTY PARA O PLACE DO GAME
	-- O place do Game não conhece a party. O RunManager lê esse dado
	-- pra saber quem decide nas telas de evento.

	options:SetTeleportData({

		partyId =
			party.id,

		leaderUserId =
			party.leaderUserId,

		memberUserIds =
			party.memberUserIds,

	})

	-- TELEPORTAR PARTY

	print(
		"[PartyManager] Iniciando partida com",
		#robloxPlayers,
		"jogador(es). Líder:",
		party.leaderUserId
	)

	local success, result =
		pcall(function()

			return TeleportService:TeleportAsync(
				GAMEPLAY_PLACE_ID,
				robloxPlayers,
				options
			)

		end)

	-- ERRO NO TELEPORT

	if not success then

		warn(
			"[PartyManager] Falha ao teleportar Party",
			party.id,
			":",
			tostring(result)
		)

	end

end

-- PLAYER DESCONECTOU

Players.PlayerRemoving:Connect(
	onLeaveParty
)

-- REMOTES

Remotes.CreateParty.OnServerEvent:Connect(
	onCreateParty
)

Remotes.JoinParty.OnServerEvent:Connect(
	onJoinParty
)

Remotes.LeaveParty.OnServerEvent:Connect(
	onLeaveParty
)

Remotes.StartGame.OnServerEvent:Connect(
	onStartGame
)

return PartyManager
