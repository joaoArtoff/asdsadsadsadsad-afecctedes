local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local PlaceIds = require(Shared:WaitForChild("PlaceIds"))
local CharacterManager = require(script.Parent:WaitForChild("CharacterManager"))

local PartyManager = {}

-- Place de destino, tamanho máximo da party e tempo mínimo entre tentativas de iniciar
local CONFIG = {
	GamePlaceId = PlaceIds.Game,
	MaxPlayers = 4,
	StartCooldown = 3,
}

PartyManager.MAX_PLAYERS = CONFIG.MaxPlayers

-- partyId -> { id, leaderUserId, memberUserIds, starting, lastStartAttempt }
PartyManager.parties = {}

-- UserId -> partyId
PartyManager.playerToParty = {}

-- Gera um id de party que ainda não está em uso
local function generatePartyId(): string
	local id
	repeat
		id = "party_" .. math.random(100000, 999999)
	until not PartyManager.parties[id]
	return id
end

local function getPartyOf(robloxPlayer: Player)
	local partyId = PartyManager.playerToParty[robloxPlayer.UserId]
	return partyId and PartyManager.parties[partyId]
end

-- Dados que o client recebe: ids, líder, membros (nome, classe e feat), limite e se a partida já está iniciando
local function serialize(party)
	local members = {}

	for _, userId in party.memberUserIds do
		local member = Players:GetPlayerByUserId(userId)
		table.insert(members, {
			userId = userId,
			name = member and member.DisplayName or "Player",
			classLabel = member and member:GetAttribute("CharacterClassLabel") or nil,
			featLabel = member and member:GetAttribute("CharacterFeatLabel") or nil,
		})
	end

	return {
		partyId = party.id,
		leaderUserId = party.leaderUserId,
		memberUserIds = table.clone(party.memberUserIds),
		members = members,
		maxPlayers = CONFIG.MaxPlayers,
		starting = party.starting == true,
	}
end

-- Manda para um jogador o estado atual da party dele (nil = sem party), com uma mensagem opcional para a tela
local function sendState(robloxPlayer: Player, message: string?)
	local party = getPartyOf(robloxPlayer)
	Remotes.PartyUpdated:FireClient(robloxPlayer, party and serialize(party) or nil, message)
end

local function broadcast(party, message: string?)
	for _, userId in party.memberUserIds do
		local member = Players:GetPlayerByUserId(userId)
		if member then
			sendState(member, message)
		end
	end
end

-- Lista pública do navegador de parties (parties que já estão iniciando não aparecem)
local function getPublicParties()
	local list = {}

	for partyId, party in PartyManager.parties do
		if not party.starting then
			local leader = Players:GetPlayerByUserId(party.leaderUserId)
			table.insert(list, {
				partyId = partyId,
				leaderUserId = party.leaderUserId,
				leaderName = leader and leader.DisplayName or "Player",
				memberCount = #party.memberUserIds,
				maxPlayers = CONFIG.MaxPlayers,
			})
		end
	end

	table.sort(list, function(a, b)
		return a.memberCount > b.memberCount
	end)

	return list
end

-- Cria uma party nova com o jogador como líder
local function onCreateParty(robloxPlayer: Player)
	if getPartyOf(robloxPlayer) then
		sendState(robloxPlayer, "Você já está em uma party.")
		return
	end

	local party = {
		id = generatePartyId(),
		leaderUserId = robloxPlayer.UserId,
		memberUserIds = { robloxPlayer.UserId },
		starting = false,
		lastStartAttempt = 0,
	}

	PartyManager.parties[party.id] = party
	PartyManager.playerToParty[robloxPlayer.UserId] = party.id

	print("[PartyManager] Party criada:", party.id, "por", robloxPlayer.Name)
	broadcast(party, "Party criada! Chame seus amigos.")
end

-- Entra numa party existente, validando id, vaga e se a partida ainda não começou
local function onJoinParty(robloxPlayer: Player, partyId)
	if type(partyId) ~= "string" then
		return
	end

	if getPartyOf(robloxPlayer) then
		sendState(robloxPlayer, "Saia da sua party antes de entrar em outra.")
		return
	end

	local party = PartyManager.parties[partyId]
	if not party then
		sendState(robloxPlayer, "Essa party não existe mais.")
		return
	end

	if party.starting then
		sendState(robloxPlayer, "Essa party já está entrando na partida.")
		return
	end

	if #party.memberUserIds >= CONFIG.MaxPlayers then
		sendState(robloxPlayer, "Essa party está cheia.")
		return
	end

	table.insert(party.memberUserIds, robloxPlayer.UserId)
	PartyManager.playerToParty[robloxPlayer.UserId] = party.id

	print("[PartyManager]", robloxPlayer.Name, "entrou na party", party.id)
	broadcast(party, robloxPlayer.DisplayName .. " entrou na party.")
end

-- Tira o jogador da party: apaga a party se esvaziar e passa a liderança se o líder sair
local function removeFromParty(robloxPlayer: Player, notifyLeaver: boolean)
	local userId = robloxPlayer.UserId
	local partyId = PartyManager.playerToParty[userId]
	if not partyId then
		return
	end

	PartyManager.playerToParty[userId] = nil
	local party = PartyManager.parties[partyId]

	if party then
		local index = table.find(party.memberUserIds, userId)
		if index then
			table.remove(party.memberUserIds, index)
		end
	end

	if notifyLeaver then
		sendState(robloxPlayer, "Você saiu da party.")
	end

	if not party then
		return
	end

	print("[PartyManager]", robloxPlayer.Name, "saiu da party", partyId)

	if #party.memberUserIds == 0 then
		PartyManager.parties[partyId] = nil
		print("[PartyManager] Party removida:", partyId)
		return
	end

	local message = robloxPlayer.DisplayName .. " saiu da party."
	if party.leaderUserId == userId then
		party.leaderUserId = party.memberUserIds[1]
		local newLeader = Players:GetPlayerByUserId(party.leaderUserId)
		message ..= " " .. (newLeader and newLeader.DisplayName or "Outro jogador") .. " agora é o líder."
	end

	broadcast(party, message)
end

local function onLeaveParty(robloxPlayer: Player)
	local party = getPartyOf(robloxPlayer)

	if party and party.starting then
		sendState(robloxPlayer, "A partida já está começando.")
		return
	end

	removeFromParty(robloxPlayer, true)
end

-- Libera a party para tentar de novo quando o teleporte falhar
local function failStart(party, reason: string)
	party.starting = false
	warn("[PartyManager] Falha ao iniciar a party", party.id, ":", reason)
	broadcast(party, "Não foi possível iniciar a partida. Tente de novo.")
end

-- Só o líder inicia: teleporta todos juntos para um servidor reservado do Game, levando os dados da party
local function onStartGame(robloxPlayer: Player)
	local party = getPartyOf(robloxPlayer)

	if not party then
		sendState(robloxPlayer, "Você não está em uma party.")
		return
	end

	if party.leaderUserId ~= robloxPlayer.UserId then
		sendState(robloxPlayer, "Apenas o líder pode iniciar a partida.")
		return
	end

	if party.starting or os.clock() - party.lastStartAttempt < CONFIG.StartCooldown then
		return
	end

	if RunService:IsStudio() then
		sendState(robloxPlayer, "O teleporte entre places não funciona no Studio. Publique e teste pelo Roblox.")
		return
	end

	local members = {}
	for _, userId in party.memberUserIds do
		local member = Players:GetPlayerByUserId(userId)
		if member then
			table.insert(members, member)
		end
	end

	if #members == 0 then
		return
	end

	party.starting = true
	party.lastStartAttempt = os.clock()
	broadcast(party, "Iniciando a partida...")

	-- Personagem escolhido por cada membro, lido no Game pelo RunManager (characters[UserId])
	local characters = {}
	for _, userId in party.memberUserIds do
		characters[tostring(userId)] = CharacterManager.GetData(userId)
	end

	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData({
		partyId = party.id,
		leaderUserId = party.leaderUserId,
		memberUserIds = table.clone(party.memberUserIds),
		characters = characters,
	})

	print("[PartyManager] Teleportando", #members, "jogador(es) da party", party.id)

	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, CONFIG.GamePlaceId, members, options)
	if not ok then
		failStart(party, tostring(err))
	end
end

-- Falha de teleporte depois de iniciado (servidor cheio, place errado etc.) destrava a party
TeleportService.TeleportInitFailed:Connect(function(robloxPlayer, result, errorMessage)
	local party = getPartyOf(robloxPlayer)
	if party and party.starting then
		failStart(party, tostring(result) .. " " .. tostring(errorMessage))
	end
end)

Players.PlayerRemoving:Connect(function(robloxPlayer)
	removeFromParty(robloxPlayer, false)
end)

-- Quando alguém troca de personagem, as vagas da party dele mostram a classe nova
CharacterManager.Changed:Connect(function(robloxPlayer)
	local party = getPartyOf(robloxPlayer)
	if party then
		broadcast(party)
	end
end)

Remotes.GetPublicParties.OnServerInvoke = function()
	return getPublicParties()
end

Remotes.CreateParty.OnServerEvent:Connect(onCreateParty)
Remotes.JoinParty.OnServerEvent:Connect(onJoinParty)
Remotes.LeaveParty.OnServerEvent:Connect(onLeaveParty)
Remotes.StartGame.OnServerEvent:Connect(onStartGame)

return PartyManager
