-- SceneManager.luau
--
-- Decide a ORDEM das cenas de uma run. Não roda nada: só responde
-- "qual é a próxima cena?". Quem roda é o RunManager (Battle / Event).
--
-- A sequência é GERADA no início de cada run, a partir de RUN_CONFIG.
-- Com a config padrão abaixo, o resultado é sempre:
--   Batalha -> Evento -> Batalha -> Evento -> Batalha
--
-- O SceneManager só decide o TIPO da cena. QUAL batalha ou QUAL evento
-- é sorteado por quem roda a cena (BattleManager / EventManager).
--
-- Quando GetNextScene() devolve nil, a run acabou e o RunManager
-- manda os jogadores de volta pro lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Scene = require(Shared.Events.Scenes.Scenes)

local SceneManager = {}

--------------------------------------------------
-- CONFIGURAÇÃO DA RUN
--
-- minBattles / maxBattles: quantidade de batalhas (sorteada entre os dois)
-- eventChance: chance (0 a 1) de ter um evento entre duas batalhas
--
-- Exemplos:
--   3 / 3 / 1    -> B E B E B            (fixo, igual ao atual)
--   3 / 5 / 1    -> entre 3 e 5 batalhas, sempre com evento no meio
--   4 / 4 / 0.5  -> 4 batalhas, cada intervalo tem 50% de ter evento
--------------------------------------------------

local RUN_CONFIG = {
	minBattles = 3,
	maxBattles = 3,
	eventChance = 1,
}

--------------------------------------------------
-- ESTADO
--------------------------------------------------

local sequence = {}    -- lista gerada para a run atual
local currentIndex = 0 -- 0 = run não começou

--------------------------------------------------
-- GERAR SEQUÊNCIA
-- Sempre começa e termina com batalha.
--------------------------------------------------

local function generateSequence()
	local result = {}

	local battles = math.random(RUN_CONFIG.minBattles, RUN_CONFIG.maxBattles)

	for i = 1, battles do
		table.insert(result, "Battle")

		-- Entre uma batalha e outra (nunca depois da última)
		if i < battles and math.random() < RUN_CONFIG.eventChance then
			table.insert(result, "Event")
		end
	end

	return result
end

--------------------------------------------------
-- INICIAR RUN
--------------------------------------------------

function SceneManager:StartRun()
	sequence = generateSequence()
	currentIndex = 0

	print("[SceneManager] Run gerada:", table.concat(sequence, " -> "))
end

--------------------------------------------------
-- PRÓXIMA CENA
-- Retorna a Scene, ou nil quando a run acabou.
--------------------------------------------------

function SceneManager:GetNextScene()
	currentIndex += 1

	local sceneType = sequence[currentIndex]

	if not sceneType then
		print("[SceneManager] Run acabou.")
		return nil
	end

	local scene = Scene.new(sceneType)
	scene.index = currentIndex

	print("[SceneManager] Cena", currentIndex, "de", #sequence, ":", sceneType)

	return scene
end

--------------------------------------------------
-- UTILIDADES
--------------------------------------------------

function SceneManager:GetCurrentIndex()
	return currentIndex
end

function SceneManager:GetTotalScenes()
	return #sequence
end

function SceneManager:IsLastScene()
	return currentIndex == #sequence
end

return SceneManager
