local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Characters = Shared:WaitForChild("Characters")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Registry = require(Characters:WaitForChild("Registry"))
local Enemy = require(Characters:WaitForChild("enemies"):WaitForChild("Enemy"))

local BattleManager = {}

-- Layout da arena e ritmo dos turnos
local CONFIG = {
	MaxPlayers = 4,
	MaxEnemies = 4,
	PlayerSpacing = 10,
	EnemySpacing = 10,
	PlayerDistance = 30,
	EnemyDistance = 30,
	PlayerHeight = 0,
	EnemyHeight = 0,
	TurnTimeout = 30,
	EnemyThinkTime = 1.2,
	AfterActionDelay = 0.7,
	StartingEnergy = 2,
	ClearEnemiesDelay = 2.5,
}

-- Rig de blocos usado quando não existe um modelo pronto em ServerStorage.EnemyModels: {nome, tamanho, offset, chave de cor}
local BLOCK_RIG = {
	{ "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 1.5, 0), nil },
	{ "Torso", Vector3.new(3, 3, 1.5), Vector3.new(0, 2, 0), "Torso" },
	{ "Head", Vector3.new(2, 2, 2), Vector3.new(0, 4.5, 0), "Head" },
	{ "LeftArm", Vector3.new(1, 3, 1), Vector3.new(-2, 2, 0), "Arms" },
	{ "RightArm", Vector3.new(1, 3, 1), Vector3.new(2, 2, 0), "Arms" },
	{ "LeftLeg", Vector3.new(1.2, 3, 1.2), Vector3.new(-0.8, -1, 0), "Legs" },
	{ "RightLeg", Vector3.new(1.2, 3, 1.2), Vector3.new(0.8, -1, 0), "Legs" },
}

local DEFAULT_COLORS = {
	Head = Color3.fromRGB(200, 200, 200),
	Torso = Color3.fromRGB(120, 120, 120),
	Arms = Color3.fromRGB(160, 160, 160),
	Legs = Color3.fromRGB(80, 80, 80),
}

local rng = Random.new()
local battleCenter: BasePart? = nil
local initialized = false

-- Estado da batalha atual; "id" invalida loops antigos caso uma nova batalha comece
local battle = {
	id = 0,
	active = false,
	phase = "Waiting",
	round = 0,
	players = {},
	enemies = {},
	byUserId = {},
	waiting = nil,
	onFinished = nil,
}

-- Posição de um slot centralizado numa fileira com espaçamento fixo
local function centeredOffset(index: number, total: number, spacing: number): number
	return (index - (total + 1) / 2) * spacing
end

-- Filtra combatentes que ainda contam para a batalha (vivos e que não saíram do jogo)
local function aliveOf(list)
	local result = {}
	for _, combatant in list do
		if combatant.isAlive and not combatant.left then
			table.insert(result, combatant)
		end
	end
	return result
end

-- Atributos replicados de turno em todos os jogadores (o client pode ler IsBattleTurn/BattleTurnText)
local function updateTurnUI(activePlayer: Player?, text: string)
	for _, player in Players:GetPlayers() do
		local isActive = activePlayer == player
		player:SetAttribute("IsBattleTurn", isActive)
		player:SetAttribute("BattleTurnText", isActive and "Your Turn" or text)
	end
end

-- Log da batalha: vai para a faixa de log de todos (remote BattleLog) ou só para um jogador (erros de ação)
local function broadcastLog(text: string, privateTo: Player?)
	print("[Battle]", text)

	if privateTo then
		privateTo:SetAttribute("BattleMessage", text)
		Remotes.BattleLog:FireClient(privateTo, text, true)
		return
	end

	for _, player in Players:GetPlayers() do
		player:SetAttribute("BattleLog", text)
	end
	Remotes.BattleLog:FireAllClients(text, false)
end

-- Desliga o script "Health" padrão do Roblox para a vida só mudar pelo sistema de batalha
local function disableRegeneration(model: Model)
	local function check(child: Instance)
		if child.Name == "Health" and child:IsA("BaseScript") then
			child.Enabled = false
		end
	end

	for _, child in model:GetChildren() do
		check(child)
	end
	model.ChildAdded:Connect(check)
end

-- Trava o personagem do jogador no slot (sem andar, pular ou girar)
local function lockCharacter(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
end

-- Pasta Workspace.Enemies (a BattleHealthUI observa essa pasta)
local function getEnemiesFolder(): Folder
	local folder = Workspace:FindFirstChild("Enemies")
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = Workspace
	return folder
end

-- Cria o Model do inimigo: clona ServerStorage.EnemyModels[id] se existir, senão monta o rig de blocos com as cores da definição
local function buildEnemyModel(enemy): Model
	local templates = ServerStorage:FindFirstChild("EnemyModels")
	local template = templates and templates:FindFirstChild(enemy.definitionId or enemy.id)
	local model

	if template and template:IsA("Model") then
		model = template:Clone()
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
	else
		local appearance = enemy.appearance or {}
		local scale = appearance.scale or 1
		local colors = appearance.colors or {}
		model = Instance.new("Model")

		for _, spec in BLOCK_RIG do
			local part = Instance.new("Part")
			part.Name = spec[1]
			part.Size = spec[2] * scale
			part.CFrame = CFrame.new(spec[3] * scale)
			part.Color = spec[4] and (colors[spec[4]] or DEFAULT_COLORS[spec[4]]) or Color3.new()
			part.Transparency = spec[4] and 0 or 1
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, true
			part.Parent = model
		end

		model.PrimaryPart = model:FindFirstChild("HumanoidRootPart") :: BasePart
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	model.Name = enemy.name
	return model
end

-- Esmaece o modelo de um inimigo derrotado
local function fadeModel(model: Model?)
	if not model then
		return
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			TweenService:Create(part, TweenInfo.new(0.6), { Transparency = 0.75 }):Play()
		end
	end
end

-- Posiciona e trava os jogadores na fileira aliada (usa a ordem da batalha se houver uma ativa)
function BattleManager.PositionPlayers()
	if not battleCenter then
		return
	end

	local list = {}
	if #battle.players > 0 then
		for _, character in battle.players do
			if not character.left and character.robloxPlayer then
				table.insert(list, character.robloxPlayer)
			end
		end
	else
		list = Players:GetPlayers()
		table.sort(list, function(a, b) return a.UserId < b.UserId end)
	end

	local total = math.min(#list, CONFIG.MaxPlayers)
	for index = 1, total do
		local model = list[index].Character
		if model and model:FindFirstChild("HumanoidRootPart") then
			model:PivotTo(battleCenter.CFrame * CFrame.new(
				centeredOffset(index, total, CONFIG.PlayerSpacing),
				CONFIG.PlayerHeight,
				CONFIG.PlayerDistance
			))
			lockCharacter(model)
		end
	end
end

-- Posiciona os modelos de inimigos na fileira oposta, virados para os jogadores
function BattleManager.PositionEnemies(models: { Instance })
	if not battleCenter then
		return
	end

	local valid = {}
	for _, model in models do
		if model:IsA("Model") then
			table.insert(valid, model)
		end
	end

	local total = math.min(#valid, CONFIG.MaxEnemies)
	for index = 1, total do
		valid[index]:PivotTo(battleCenter.CFrame
			* CFrame.new(centeredOffset(index, total, CONFIG.EnemySpacing), CONFIG.EnemyHeight, -CONFIG.EnemyDistance)
			* CFrame.Angles(0, math.pi, 0))
	end
end

function BattleManager.RefreshFormation()
	BattleManager.PositionPlayers()
	BattleManager.PositionEnemies(getEnemiesFolder():GetChildren())
end

-- Ordem da rodada: maior iniciativa primeiro; empate favorece jogadores e depois ordem alfabética
local function buildTurnOrder()
	local order = aliveOf(battle.players)
	for _, enemy in aliveOf(battle.enemies) do
		table.insert(order, enemy)
	end

	table.sort(order, function(a, b)
		local ia, ib = a:GetStat("Initiative"), b:GetStat("Initiative")
		if ia ~= ib then
			return ia > ib
		end
		if a.isPlayerTeam ~= b.isPlayerTeam then
			return a.isPlayerTeam
		end
		return a.name < b.name
	end)

	return order
end

local function checkOutcome(): string?
	if #aliveOf(battle.enemies) == 0 then
		return "Victory"
	end
	if #aliveOf(battle.players) == 0 then
		return "Defeat"
	end
	return nil
end

-- Encerra a batalha: distribui XP, atualiza a UI, chama o callback do RunManager e limpa inimigos e banner de turno
local function finishBattle(outcome: string)
	if not battle.active then
		return
	end

	battle.active = false
	battle.phase = "Ended"

	if outcome == "Victory" then
		local xp = 0
		for _, enemy in battle.enemies do
			xp += enemy.xpReward or 0
		end

		for _, character in aliveOf(battle.players) do
			local levels = character.AddXP and character:AddXP(xp) or 0
			if levels > 0 then
				broadcastLog(string.format("%s subiu para o nível %d!", character.name, character.level))
			end
		end
	end

	updateTurnUI(nil, outcome == "Victory" and "Victory!" or "Defeat...")
	broadcastLog(outcome == "Victory" and "Vitória!" or "Derrota...")

	local callback = battle.onFinished
	battle.onFinished = nil
	if callback then
		task.spawn(callback, outcome)
	end

	Workspace:SetAttribute("BattleRound", nil)

	local finishedId = battle.id
	task.delay(CONFIG.ClearEnemiesDelay, function()
		if not battle.active and battle.id == finishedId then
			getEnemiesFolder():ClearAllChildren()
		end
	end)
end

-- Pausa o loop da batalha até o jogador mandar uma ação ou o tempo acabar (retorna nil no timeout)
local function waitForInput(character, timeout: number)
	local thread = coroutine.running()
	local token = {}
	battle.waiting = { character = character, thread = thread, token = token }

	task.delay(timeout, function()
		local waiting = battle.waiting
		if waiting and waiting.token == token then
			battle.waiting = nil
			task.spawn(thread, nil)
		end
	end)

	return coroutine.yield()
end

-- Monta a frase do log a partir do resultado de Character:UseAction
local function describe(result)
	local actionName = result.action.displayName or result.action.id
	local source, target = result.source.name, result.target.name
	local text

	if result.dodged then
		text = string.format("%s usou %s, mas %s esquivou!", source, actionName, target)
	elseif result.damage > 0 then
		text = string.format("%s usou %s em %s%s", source, actionName, target, result.critical and " (CRÍTICO!)" or ".")
	elseif result.healed > 0 then
		text = string.format("%s usou %s e curou %d em %s.", source, actionName, result.healed, target)
	else
		text = string.format("%s usou %s.", source, actionName)
	end

	if result.energyGained > 0 then
		text ..= string.format(" (+%d energia)", result.energyGained)
	end
	if result.statusApplied then
		text ..= string.format(" %s ficou %s!", target, result.statusApplied)
	end
	for _, curedName in result.cured or {} do
		text ..= string.format(" %s não está mais %s!", target, curedName)
	end
	if result.killed then
		text ..= string.format(" %s caiu!", target)
	end

	broadcastLog(text)
end

-- Acha o alvo no time adversário (por objeto, nome ou índice); cai no primeiro vivo se o pedido for inválido
local function findFoe(character, targetSpec)
	local foes = aliveOf(character.isPlayerTeam and battle.enemies or battle.players)

	if type(targetSpec) == "table" and table.find(foes, targetSpec) then
		return targetSpec
	elseif type(targetSpec) == "string" then
		for _, foe in foes do
			if foe.name == targetSpec then
				return foe
			end
		end
	elseif type(targetSpec) == "number" then
		return foes[targetSpec] or foes[1]
	end

	return foes[1]
end

-- Resolve o fim de uma ação ou item: log na faixa e esmaecer o inimigo que caiu
local function concludeResult(result)
	describe(result)

	if result.killed and not result.target.isPlayerTeam then
		fadeModel(result.target.model)
	end

	return result
end

-- Resolve uma ação em área numa linha só do log: quem foi atingido/curado, críticos, esquivas, status e quem caiu
local function concludeGroup(results)
	local first = results[1]
	local action = first.action
	local hit, crits, dodged, killed, cured = {}, {}, {}, {}, {}
	local statusTargets, statusName = 0, nil

	for _, result in results do
		local name = result.target.name

		if result.dodged then
			table.insert(dodged, name)
		else
			table.insert(hit, name)
		end
		if result.critical then
			table.insert(crits, name)
		end
		if result.statusApplied then
			statusTargets += 1
			statusName = result.statusApplied
		end
		if #result.cured > 0 then
			table.insert(cured, name)
		end
		if result.killed then
			table.insert(killed, name)
			if not result.target.isPlayerTeam then
				fadeModel(result.target.model)
			end
		end
	end

	local text = string.format("%s usou %s", first.source.name, action.displayName or action.id)
	if #hit > 0 then
		text ..= ((action.effectType or "Damage") == "Damage" and " e atingiu " or " em ") .. table.concat(hit, ", ")
	end
	text ..= "."

	if #crits > 0 then
		text ..= " Crítico em " .. table.concat(crits, ", ") .. "!"
	end
	if #dodged > 0 then
		text ..= " " .. table.concat(dodged, ", ") .. " esquivou!"
	end
	if statusTargets > 0 then
		text ..= string.format(" %s %s!", statusTargets == #results and "Todos ficaram" or (statusTargets .. " ficaram"), statusName)
	end
	if #cured > 0 then
		text ..= " Efeitos removidos de " .. table.concat(cured, ", ") .. "."
	end
	if first.energyGained > 0 then
		text ..= string.format(" (+%d energia)", first.energyGained)
	end
	if #killed > 0 then
		text ..= " " .. table.concat(killed, ", ") .. " caiu!"
	end

	broadcastLog(text)
	return results
end

-- Valida e executa a ação: em área (targetGroup) atinge um time inteiro; ofensivas miram um inimigo; suporte mira o usuário
local function performAction(character, actionId: string, targetSpec, force: boolean?)
	local action = Registry.Get("Actions", actionId)
	if not action then
		return nil, "Ação desconhecida: " .. tostring(actionId)
	end

	if not force and not table.find(character.actions, action.id) then
		return nil, "Você não conhece " .. (action.displayName or action.id) .. "."
	end

	if action.targetGroup == "Allies" or action.targetGroup == "Enemies" then
		local sameTeam = action.targetGroup == "Allies"
		local onPlayerSide = character.isPlayerTeam == sameTeam
		local results, reason = character:UseActionOnGroup(action, aliveOf(onPlayerSide and battle.players or battle.enemies), rng)
		if not results then
			return nil, reason
		end

		return concludeGroup(results)
	end

	local target = character
	if (action.effectType or "Damage") == "Damage" then
		target = findFoe(character, targetSpec)
		if not target then
			return nil, "Nenhum alvo disponível."
		end
	end

	local result, reason = character:UseAction(action, target, rng)
	if not result then
		return nil, reason
	end

	return concludeResult(result)
end

-- Usa um item do inventário: confere se o jogador tem, escolhe o alvo pelo tipo do item e só gasta se der certo
local function performItem(character, itemId, targetSpec)
	local inventory = character.inventory
	local item = type(itemId) == "string" and Registry.Get("Items", itemId)

	if not inventory or not item then
		return nil, "Item inválido."
	end

	if not inventory:Has(item.id) then
		return nil, "Você não tem " .. (item.displayName or item.id) .. "."
	end

	if not item.effect or item.usableInBattle == false then
		return nil, (item.displayName or item.id) .. " não pode ser usado em batalha."
	end

	local target = character
	if item.target == "Enemy" then
		target = findFoe(character, targetSpec)
		if not target then
			return nil, "Nenhum alvo disponível."
		end
	end

	local result, reason = character:UseItem(item, target, rng)
	if not result then
		return nil, reason
	end

	inventory:Remove(item.id, 1)
	return concludeResult(result)
end

-- Converte o que a BattleUI manda ({actionType, skillId/itemId, targetName}) em ação, alvo e item
local function parseRequest(request)
	local actionType = request.actionType
	local target = nil

	if type(request.targetName) == "string" and #request.targetName <= 64 then
		target = request.targetName
	elseif type(request.targetIndex) == "number" then
		target = math.floor(request.targetIndex)
	end

	if actionType == "Attack" and type(request.skillId) == "string" then
		return request.skillId, target
	elseif actionType == "Item" then
		return "Item", target, type(request.itemId) == "string" and request.itemId or nil
	elseif actionType == "Focus" then
		return "Focus", nil
	elseif type(request.actionId) == "string" then
		return request.actionId, target
	end

	return nil, nil
end

-- Turno de jogador: libera a UI dele, espera a ação com tempo limite; ação inválida não gasta o turno, timeout vira Foco
local function playerTurn(character)
	local player = character.robloxPlayer
	battle.phase = "Player"
	updateTurnUI(player, character.name .. "'s Turn")

	local deadline = os.clock() + CONFIG.TurnTimeout

	while battle.active do
		local request = waitForInput(character, math.max(deadline - os.clock(), 0))

		if character.left or not character.isAlive then
			return
		end

		if not request then
			broadcastLog(character.name .. " demorou demais e se concentrou.")
			performAction(character, "Focus", nil, true)
			return
		end

		local actionId, target, itemId = parseRequest(request)

		local result, reason
		if actionId == "Item" then
			result, reason = performItem(character, itemId, target)
		else
			result, reason = performAction(character, actionId, target, false)
		end

		if result then
			return
		end

		broadcastLog(reason or "Ação inválida.", player)
	end
end

-- Turno de inimigo: pequena pausa dramática, IA escolhe ação e alvo, e executa
local function enemyTurn(enemy)
	battle.phase = "Enemy"
	updateTurnUI(nil, enemy.name .. "'s Turn")
	task.wait(CONFIG.EnemyThinkTime)

	if not battle.active then
		return
	end

	local action, target = enemy:ChooseAction(aliveOf(battle.players), rng)
	if not action then
		broadcastLog(enemy.name .. " hesitou.")
		return
	end

	performAction(enemy, action.id, target, true)
end

-- Início de turno comum: reseta ações, processa efeitos (veneno etc.) e decide se o combatente consegue agir
local function takeTurn(combatant)
	combatant:ResetTurn()
	local report = combatant:TickStatus()

	for _, line in report.lines do
		broadcastLog(line)
	end

	if not combatant.isAlive then
		broadcastLog(combatant.name .. " sucumbiu aos efeitos!")
		if not combatant.isPlayerTeam then
			fadeModel(combatant.model)
		end
		return
	end

	if report.skipTurn then
		broadcastLog(combatant.name .. " perdeu o turno!")
		task.wait(0.5)
		return
	end

	if combatant.isPlayerTeam then
		playerTurn(combatant)
	else
		enemyTurn(combatant)
	end

	task.wait(CONFIG.AfterActionDelay)
end

-- Loop principal: a cada rodada monta a ordem por iniciativa e executa o turno de cada combatente vivo
local function runBattle(battleId: number)
	task.wait(1)

	while battle.active and battle.id == battleId do
		battle.round += 1
		Workspace:SetAttribute("BattleRound", battle.round)
		print("[Battle] Rodada", battle.round)

		for _, combatant in buildTurnOrder() do
			if not battle.active or battle.id ~= battleId then
				return
			end

			if combatant.isAlive and not combatant.left then
				takeTurn(combatant)

				local outcome = checkOutcome()
				if outcome then
					finishBattle(outcome)
					return
				end
			end
		end
	end
end

-- Inicia uma batalha com os Characters dos jogadores e uma lista de inimigos (ids registrados ou objetos Enemy)
function BattleManager.StartBattle(playerCharacters, encounter, onFinished)
	if not battleCenter then
		warn("[BattleManager] StartBattle chamado sem BattleCenter (Init falhou?).")
		return false
	end

	if battle.active then
		warn("[BattleManager] Já existe uma batalha em andamento.")
		return false
	end

	battle.id += 1
	battle.round = 0
	battle.phase = "Starting"
	battle.onFinished = onFinished
	battle.players = {}
	battle.enemies = {}
	battle.waiting = nil
	table.clear(battle.byUserId)

	for _, character in playerCharacters do
		local player = character.robloxPlayer
		if character.isAlive and player and player.Parent then
			character.left = nil
			character:PrepareForBattle(CONFIG.StartingEnergy)
			table.insert(battle.players, character)
			battle.byUserId[player.UserId] = character

			if player.Character then
				character:BindModel(player.Character, true)
			end
		end
	end

	local folder = getEnemiesFolder()
	folder:ClearAllChildren()

	local models, nameCount = {}, {}
	for _, entry in encounter do
		if #battle.enemies >= CONFIG.MaxEnemies then
			break
		end

		local enemy = type(entry) == "string" and Enemy.Create(entry) or entry
		if enemy then
			nameCount[enemy.name] = (nameCount[enemy.name] or 0) + 1
			if nameCount[enemy.name] > 1 then
				enemy.name ..= " " .. nameCount[enemy.name]
			end

			local model = buildEnemyModel(enemy)
			enemy:BindModel(model, false)
			model.Parent = folder

			table.insert(battle.enemies, enemy)
			table.insert(models, model)
		end
	end

	if #battle.players == 0 or #battle.enemies == 0 then
		warn("[BattleManager] Batalha sem jogadores ou sem inimigos válidos.")
		battle.onFinished = nil
		return false
	end

	battle.active = true
	BattleManager.PositionEnemies(models)
	BattleManager.PositionPlayers()
	updateTurnUI(nil, "Battle Start!")

	task.spawn(runBattle, battle.id)
	return true
end

function BattleManager.IsActive(): boolean
	return battle.active
end

function BattleManager.GetCombatants()
	return battle.players, battle.enemies
end

-- Preparação de cada personagem de jogador que aparece: sem regeneração, posicionado e ligado ao seu Character
local function prepareCharacter(player: Player, model: Model)
	model:WaitForChild("HumanoidRootPart")
	model:WaitForChild("Humanoid")
	disableRegeneration(model)

	task.wait(0.15)
	BattleManager.PositionPlayers()

	local character = battle.byUserId[player.UserId]
	if character then
		character:BindModel(model, true)
	end
end

local function setupPlayer(player: Player)
	player:SetAttribute("BattleTurnText", "Waiting...")
	player:SetAttribute("IsBattleTurn", false)

	player.CharacterAdded:Connect(function(model)
		prepareCharacter(player, model)
	end)

	if player.Character then
		task.defer(prepareCharacter, player, player.Character)
	end
end

-- Jogador saiu: tira da batalha e destrava o loop se era a vez dele
local function onPlayerRemoving(player: Player)
	local character = battle.byUserId[player.UserId]

	if character then
		character.left = true
		local waiting = battle.waiting
		if waiting and waiting.character == character then
			battle.waiting = nil
			task.spawn(waiting.thread, nil)
		end
	end

	task.defer(BattleManager.PositionPlayers)
end

-- Ação vinda da BattleUI: só é aceita se o servidor estiver esperando justamente esse jogador
local function onBattleAction(player: Player, actionData)
	local waiting = battle.waiting

	if typeof(actionData) ~= "table" then
		return
	end

	if not waiting or waiting.character.robloxPlayer ~= player then
		warn("[BattleManager]", player.Name, "tentou agir fora do próprio turno.")
		return
	end

	battle.waiting = nil
	task.spawn(waiting.thread, actionData)
end

-- Inicialização única: encontra o BattleCenter e conecta jogadores e remote
function BattleManager.Init(): boolean
	if initialized then
		return true
	end

	local center = Workspace:WaitForChild("BattleCenter", 10)
	if not center or not center:IsA("BasePart") then
		warn("[BattleManager] BattleCenter NÃO encontrado ou não é um BasePart.")
		return false
	end

	battleCenter = center
	initialized = true

	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Remotes.BattleAction.OnServerEvent:Connect(onBattleAction)

	print("[BattleManager] Inicializado em", center:GetFullName())
	return true
end

return BattleManager
