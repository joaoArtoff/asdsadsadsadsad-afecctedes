local Workspace = game:GetService("Workspace")

local Registry = require(script.Parent.Parent:WaitForChild("Characters"):WaitForChild("Registry"))

-- Classe base usada pelo Scenes.luau e pelo EventManager.
local Event = {}
Event.__index = Event

function Event.new(eventType)
	local self = setmetatable({}, Event)

	self.type = eventType or "Unknown"
	self.finished = false

	return self
end

function Event:Finish()
	self.finished = true
end

local PROP_DURATION = 4

-- Objeto de cenário do evento, criado em cima do BattleCenter.
local function createProp(name, size, color)
	local battleCenter = Workspace:FindFirstChild("BattleCenter")

	local position = Vector3.new(0, 3, 0)

	if battleCenter and battleCenter:IsA("BasePart") then
		position = battleCenter.Position + Vector3.new(0, 2, 0)
	end

	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Wood
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(position)
	part.Parent = Workspace

	return part
end

-- Personagens vivos da run (o Character de cada jogador), vindos do RunManager em context.run
local function partyCharacters(context)
	local run = context and context.run

	if run and type(run.GetParty) == "function" then
		return run.GetParty()
	end

	return {}
end

-- Cura pelo Character, assim o valor continua valendo na próxima batalha e a barra atualiza sozinha
local function healParty(context, amount)
	for _, character in partyCharacters(context) do
		local healed = character:Heal(amount)
		print("[Evento]", character.name, "curado em", healed, "- vida", character.health)
	end
end

-- Dano pelo Character; nunca deixa ninguém morrer num evento: a vida para em 1
local function damageParty(context, amount)
	for _, character in partyCharacters(context) do
		local lost = character:TakeDamage(math.min(amount, math.max(character.health - 1, 0)))
		print("[Evento]", character.name, "perdeu", lost, "- vida", character.health)
	end
end

-- Quem compra na loja: o líder da party (se houver) ou o primeiro jogador vivo
local function buyerCharacter(context)
	local run = context and context.run
	local leader = context and context.manager and context.manager.Leader

	if run and leader and run.ByUserId and run.ByUserId[leader.UserId] then
		return run.ByUserId[leader.UserId]
	end

	return partyCharacters(context)[1]
end

-- Nome de exibição do item (para os textos dos eventos)
local function itemName(itemId)
	local item = Registry.Get("Items", itemId)
	return item and item.displayName or itemId
end

-- Dá um item para cada jogador vivo; devolve quantos jogadores receberam (inventário cheio não recebe)
local function giveItemToParty(context, itemId, amount)
	local received = 0

	for _, character in partyCharacters(context) do
		if character.GiveItem and character:GiveItem(itemId, amount or 1) > 0 then
			received += 1
		end
	end

	return received
end

-- Sorteia um item entre os ids passados
local function randomItem(pool)
	return pool[math.random(1, #pool)]
end

-- As moedas ficam no RunManager, que chega aqui como context.run.
local function getGold(context)
	local run = context.run
	return (run and run.Gold) or 0
end

local function addGold(context, amount)
	local run = context.run

	if not run then
		return
	end

	run.Gold = math.max((run.Gold or 0) + amount, 0)
	print("[Evento] Moedas:", run.Gold)
end

-- Tela de aviso com um botão só, pro jogador ver o resultado da escolha.
local function tell(context, text)
	context.manager:Prompt(text, { "Continuar" })
end

-- Lista de eventos do jogo. O EventManager sorteia até 4 deles e
-- mostra os nomes na tela de escolha antes de rodar o escolhido.
-- Pra criar um evento novo, é só adicionar outra table aqui, com
-- 'id', 'name' e 'run'. O run SEMPRE tem que chamar context.finish().
Event.List = {

	{
		id = "fogueira",
		name = "Fogueira",

		run = function(context)
			local prop = createProp("Fogueira", Vector3.new(4, 1, 4), Color3.fromRGB(90, 60, 40))

			local fire = Instance.new("Fire")
			fire.Size = 8
			fire.Heat = 10
			fire.Parent = prop

			local light = Instance.new("PointLight")
			light.Brightness = 3
			light.Range = 25
			light.Color = Color3.fromRGB(255, 160, 70)
			light.Parent = prop

			task.wait(1.5)

			healParty(context, 30)

			tell(context, "A party descansa na fogueira.\n+30 de vida.")

			task.wait(PROP_DURATION)

			prop:Destroy()

			context.finish()
		end,
	},

	{
		id = "mercado",
		name = "Mercado",

		run = function(context)
			local prop = createProp("Barraca", Vector3.new(7, 1, 3), Color3.fromRGB(120, 90, 60))

			-- Itens à venda; o preço vem do campo "price" de cada item
			local stock = { "HealthPotion", "GreaterPotion", "FireBomb" }
			local labels = {}

			for _, itemId in stock do
				local item = Registry.Get("Items", itemId)
				table.insert(labels, string.format("%s (%d moedas)", itemName(itemId), item and item.price or 0))
			end
			table.insert(labels, "Ir embora")

			local choice = context.manager:Prompt(
				"Um mercador abre a barraca no meio da estrada.\nMoedas: " .. getGold(context),
				labels
			)

			local itemId = stock[choice]

			if itemId then
				local price = Registry.Get("Items", itemId).price or 0
				local buyer = buyerCharacter(context)

				if getGold(context) < price then
					tell(context, "Moedas insuficientes.\nO mercador dá de ombros.")
				elseif not buyer or buyer:GiveItem(itemId, 1) == 0 then
					tell(context, "O inventário está cheio.\nO mercador guarda o item de volta.")
				else
					addGold(context, -price)
					tell(context, string.format("Negócio fechado.\n%s recebeu %s.", buyer.name, itemName(itemId)))
				end
			else
				tell(context, "A party segue em frente.")
			end

			prop:Destroy()

			context.finish()
		end,
	},

	{
		id = "bau",
		name = "Baú",

		run = function(context)
			local prop = createProp("Bau", Vector3.new(3, 2, 2), Color3.fromRGB(110, 80, 45))

			local choice = context.manager:Prompt(
				"Um baú trancado bloqueia a passagem.",
				{ "Arrombar", "Ignorar" }
			)

			if choice == 1 then
				-- 60% de chance de tesouro (moedas + um item para cada um), 40% de armadilha.
				if math.random() < 0.6 then
					local itemId = randomItem({ "HealthPotion", "EnergyTonic", "Antidote", "FireBomb" })
					addGold(context, 15)
					giveItemToParty(context, itemId, 1)
					tell(context, "Dentro do baú, moedas e suprimentos.\n+15 moedas e " .. itemName(itemId) .. " para cada um.")
				else
					damageParty(context, 10)
					tell(context, "Era uma armadilha.\n-10 de vida.")
				end
			else
				tell(context, "A party contorna o baú.")
			end

			prop:Destroy()

			context.finish()
		end,
	},

	{
		id = "santuario",
		name = "Santuário",

		run = function(context)
			local prop = createProp("Altar", Vector3.new(5, 3, 5), Color3.fromRGB(150, 150, 165))
			prop.Material = Enum.Material.Marble

			local choice = context.manager:Prompt(
				"Um altar antigo ainda brilha fraco.",
				{ "Rezar", "Profanar", "Seguir em frente" }
			)

			if choice == 1 then
				healParty(context, 20)
				tell(context, "Uma luz morna cobre a party.\n+20 de vida.")

			elseif choice == 2 then
				addGold(context, 25)
				damageParty(context, 15)
				tell(context, "As oferendas são levadas, mas algo cobra o preço.\n+25 moedas, -15 de vida.")

			else
				tell(context, "A party deixa o altar intacto.")
			end

			prop:Destroy()

			context.finish()
		end,
	},

}

return Event
