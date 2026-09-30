local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- WaitForChild com timeout curto nos dois lados: o Rojo já declara essa pasta
-- no project.json, então ela normalmente já existe. O timeout só cobre o caso
-- de o script rodar antes do Rojo terminar de sincronizar a árvore -- sem ele,
-- o servidor podia criar sua PRÓPRIA pasta "Remotes" duplicada bem nesse
-- instante de corrida, e o cliente acabava esperando (e pegando) a do Rojo.
local remotesFolder =
	ReplicatedStorage:WaitForChild("Remotes", 5)

if not remotesFolder then

	if RunService:IsServer() then

		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage

	else

		remotesFolder =
			ReplicatedStorage:WaitForChild("Remotes")

	end

end

local REMOTE_CLASSES = {

	-- Personagem
	SubmitCharacter = "RemoteEvent",
	CharacterCreated = "RemoteEvent",

	-- Party
	CreateParty = "RemoteEvent",
	JoinParty = "RemoteEvent",
	LeaveParty = "RemoteEvent",
	StartGame = "RemoteEvent",
	PartyUpdated = "RemoteEvent",

	GetPublicParties = "RemoteFunction",

	-- Battle
	BattleAction = "RemoteEvent",
	BattleLog = "RemoteEvent",

	-- Event
	EventPrompt = "RemoteEvent",
	EventChoice = "RemoteEvent",

}

local function getRemote(name: string)

	local className = REMOTE_CLASSES[name]

	if not className then

		error(
			"[Remotes] \""
				.. name
				.. "\" não está registrado em REMOTE_CLASSES"
		)

	end

	-- Mesma lógica do timeout curto acima: espera o Rojo entregar o remote
	-- já declarado no project.json antes de considerar criar um novo, pra
	-- servidor e cliente nunca acabarem presos em instâncias diferentes.
	local remote =
		remotesFolder:WaitForChild(name, 5)

	if not remote then

		if RunService:IsServer() then

			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = remotesFolder

		else

			remote =
				remotesFolder:WaitForChild(name)

		end

	end

	if not remote:IsA(className) then

		error(
			"[Remotes] \""
				.. name
				.. "\" existe, mas não é "
				.. className
		)

	end

	return remote

end

-- Cada remote só é buscado/criado na primeira vez que alguém usa
-- Remotes.NomeDoRemote. Assim, um remote que só existe no lugar Game
-- (ex: BattleAction) nunca trava um script rodando no lugar Lobby,
-- e vice-versa: só quem realmente usa aquele remote fica esperando.
local Remotes = setmetatable({}, {

	__index = function(self, name)

		local remote = getRemote(name)

		-- Guarda o resultado como campo normal da tabela,
		-- então os próximos acessos nem passam mais pelo __index.
		rawset(self, name, remote)

		return remote

	end,

})

return Remotes
