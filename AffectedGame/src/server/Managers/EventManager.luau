local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Event = require(Shared:WaitForChild("Events"):WaitForChild("Event"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local EventManager = {}

EventManager.Events = {}         -- eventos registrados
EventManager.Current = nil       -- evento rodando agora (ou nil)
EventManager.Leader = nil        -- único que pode responder as telas (Player)
EventManager.CurrentTitle = nil  -- título mostrado na faixa da tela de evento

local PROMPT_TIMEOUT = 60

function EventManager:Register(definition)
	if type(definition) ~= "table" or type(definition.run) ~= "function" then
		warn("[EventManager] Evento inválido -- precisa ser uma table com 'run'.")
		return
	end

	table.insert(self.Events, definition)

	print("[EventManager] Evento registrado:", definition.id or "sem id")
end

local MAX_OPTIONS = 4

-- Sorteia até 4 eventos diferentes pra montar a tela de escolha.
function EventManager:PickOptions()
	local pool = table.clone(self.Events)
	local chosen = {}

	while #chosen < MAX_OPTIONS and #pool > 0 do
		table.insert(chosen, table.remove(pool, math.random(1, #pool)))
	end

	return chosen
end

-- Mostra a tela de evento pra todo mundo, mas só o líder pode responder.
-- Retorna o índice da opção escolhida. Trava a thread do evento até lá.
function EventManager:Prompt(text, options)
	options = options or { "Continuar" }

	-- Se o líder saiu do jogo, libera a escolha pra qualquer um.
	local leader = self.Leader

	if leader and not leader.Parent then
		leader = nil
	end

	local answered = false
	local choice = nil

	local connection
	connection = Remotes.EventChoice.OnServerEvent:Connect(function(player, index)
		if answered then
			return
		end

		if leader and player ~= leader then
			warn("[EventManager]", player.Name, "tentou escolher sem ser o líder.")
			return
		end

		if type(index) ~= "number" or not options[index] then
			return
		end

		answered = true
		choice = index

		print("[EventManager]", player.Name, "escolheu:", options[index])
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		Remotes.EventPrompt:FireClient(player, {
			title = self.CurrentTitle,
			text = text,
			options = options,
			canChoose = (leader == nil) or (player == leader),
			leaderName = leader and leader.DisplayName or nil,
		})
	end

	-- Se ninguém responder, segue com a primeira opção pra run não travar.
	local elapsed = 0

	while not answered and elapsed < PROMPT_TIMEOUT do
		elapsed += task.wait(0.1)
	end

	connection:Disconnect()

	-- Enviar nil fecha a tela no cliente.
	for _, player in ipairs(Players:GetPlayers()) do
		Remotes.EventPrompt:FireClient(player, nil)
	end

	if not answered then
		warn("[EventManager] Ninguém respondeu -- seguindo com a opção 1.")
	end

	return choice or 1
end

-- Chamado pelo RunManager quando o SceneManager devolve uma cena "Event".
function EventManager:RunEvent(run, scene, onComplete)
	local options = self:PickOptions()

	-- Sem nenhum evento registrado, pula a cena pra run não travar.
	if #options == 0 then
		print("[EventManager] Nenhum evento registrado -- pulando a cena.")

		if onComplete then
			onComplete()
		end

		return
	end

	local definition = options[1]

	-- Com mais de um evento disponível, o jogador escolhe qual será.
	if #options > 1 then
		local labels = {}

		for _, option in ipairs(options) do
			table.insert(labels, option.name or option.id)
		end

		self.CurrentTitle = "Próximo destino"

		local text = "Escolha o próximo destino."

		if run and run.Gold then
			text ..= "\n\nMoedas: " .. run.Gold
		end

		definition = options[self:Prompt(text, labels)]
	end

	-- A partir daqui a faixa da tela mostra o nome do evento escolhido
	self.CurrentTitle = definition.name or definition.id

	local eventObject = Event.new("Event")
	self.Current = eventObject

	local finished = false

	-- O evento chama isso pra encerrar e devolver o controle da run.
	local function finish()
		if finished then
			return
		end

		finished = true

		eventObject:Finish()
		self.Current = nil
		self.CurrentTitle = nil

		print("[EventManager] Evento finalizado:", definition.id)

		if onComplete then
			onComplete()
		end
	end

	local context = {
		run = run,
		scene = scene,
		event = eventObject,
		manager = self,
		finish = finish,
	}

	print("[EventManager] Iniciando evento:", definition.id)

	local success, err = pcall(definition.run, context)

	-- Se o evento deu erro, encerra na força pra não travar a run.
	if not success then
		warn("[EventManager] Erro no evento", definition.id, ":", err)
		finish()
	end
end

-- Registra tudo que estiver em Event.List.
for _, definition in ipairs(Event.List or {}) do
	EventManager:Register(definition)
end

return EventManager
