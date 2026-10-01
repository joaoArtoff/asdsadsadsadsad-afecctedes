local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Registry = require(Shared:WaitForChild("Characters"):WaitForChild("Registry"))

local FONT = Enum.Font.FredokaOne
local OPEN_KEY = Enum.KeyCode.C
local MAX_FEATS = 1
local MESSAGE_TIME = 4

local FADE = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local COLORS = {
	Text = Color3.new(1, 1, 1),
	TextStroke = Color3.fromRGB(20, 15, 15),
	SecondaryText = Color3.fromRGB(185, 185, 190),
	Dim = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(22, 22, 26),
	Slot = Color3.fromRGB(38, 38, 44),
	SlotSelected = Color3.fromRGB(58, 52, 40),
	SlotBorder = Color3.fromRGB(70, 70, 78),
	Gold = Color3.fromRGB(215, 150, 45),
	Selected = Color3.fromRGB(255, 210, 70),
	Banner = Color3.fromRGB(70, 70, 70),
	KeyBack = Color3.fromRGB(70, 70, 75),
	KeyBorder = Color3.fromRGB(35, 35, 38),
	Message = Color3.fromRGB(255, 225, 120),
	Error = Color3.fromRGB(255, 120, 120),
}

-- Paleta dos botões cartoon e cores dos losangos de cada classe (na ordem da lista)
local BUTTON_STYLES = {
	Red = { fill = Color3.fromRGB(150, 10, 10), border = Color3.fromRGB(215, 20, 20) },
	Green = { fill = Color3.fromRGB(30, 130, 20), border = Color3.fromRGB(80, 190, 45) },
	Gray = { fill = Color3.fromRGB(70, 70, 78), border = Color3.fromRGB(110, 110, 118) },
}

local CLASS_COLORS = {
	Color3.fromRGB(215, 40, 40),
	Color3.fromRGB(30, 120, 235),
	Color3.fromRGB(70, 185, 60),
	Color3.fromRGB(235, 190, 30),
	Color3.fromRGB(160, 80, 220),
	Color3.fromRGB(30, 190, 190),
	Color3.fromRGB(240, 130, 20),
}

-- Definições lidas do Registry (as mesmas que o servidor usa para validar)
local function sortedByName(list)
	table.sort(list, function(a, b)
		return (a.displayName or a.name or a.id) < (b.displayName or b.name or b.id)
	end)
	return list
end

local classes = sortedByName(Registry.All("Classes"))
local races = sortedByName(Registry.All("Races"))
local allFeats = sortedByName(Registry.All("Feats"))

local function displayName(definition): string
	return definition.displayName or definition.name or definition.id
end

local function sameId(a: string?, b: string?): boolean
	return a ~= nil and b ~= nil and string.lower(a) == string.lower(b)
end

-- Escolha em edição na tela e a última confirmada pelo servidor
local selected = { class = nil, race = nil, feats = {} }
local saved = nil
local isOpen = false

-- Helpers visuais (mesmo padrão das outras telas)
local function addCorner(object: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
end

local function addStroke(object: GuiObject, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = object
	return stroke
end

local function createText(parent: Instance, props): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = props.Text or ""
	label.TextColor3 = props.Color or COLORS.Text
	label.TextSize = props.TextSize or 20
	label.TextXAlignment = props.AlignX or Enum.TextXAlignment.Left
	label.TextYAlignment = props.AlignY or Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.Position = props.Position or UDim2.new()
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.ZIndex = props.ZIndex or 1
	label.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.TextStroke
	stroke.Thickness = props.StrokeThickness or 2
	stroke.Parent = label

	return label
end

local function createDiamond(parent: Instance, position: UDim2, size: number, color: Color3): Frame
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = position
	diamond.Size = UDim2.fromOffset(size, size)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = color
	diamond.ZIndex = 2
	diamond.Parent = parent
	addStroke(diamond, COLORS.TextStroke, 2)
	return diamond
end

-- Botão cartoon com tecla opcional; devolve controles para texto e trava
local function createButton(parent: Instance, text: string, styleName: string, size: Vector2, textSize: number, keyText: string?)
	local style = BUTTON_STYLES[styleName]

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(size.X, size.Y)
	button.BackgroundColor3 = style.fill
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent
	addCorner(button, 12)
	addStroke(button, style.border, 3)

	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175))
	shine.Rotation = 90
	shine.Parent = button

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local label = createText(button, {
		Text = text,
		TextSize = textSize,
		AlignX = Enum.TextXAlignment.Center,
		ZIndex = 2,
		StrokeThickness = 2.5,
	})

	if keyText then
		local keyCap = Instance.new("Frame")
		keyCap.AnchorPoint = Vector2.new(0.5, 0.5)
		keyCap.Position = UDim2.fromOffset(6, 6)
		keyCap.Size = UDim2.fromOffset(28, 28)
		keyCap.BackgroundColor3 = COLORS.KeyBack
		keyCap.ZIndex = 3
		keyCap.Parent = button
		addCorner(keyCap, 6)
		addStroke(keyCap, COLORS.KeyBorder, 2.5)
		createText(keyCap, { Text = keyText, TextSize = 17, AlignX = Enum.TextXAlignment.Center, ZIndex = 4 })
	end

	local api = { Button = button, Label = label, Enabled = true }

	button.MouseEnter:Connect(function()
		if api.Enabled then
			TweenService:Create(scale, HOVER, { Scale = 1.05 }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
	end)

	function api.SetText(value: string)
		label.Text = value
	end

	function api.SetEnabled(value: boolean)
		api.Enabled = value
		button.Active = value
		button.BackgroundTransparency = value and 0 or 0.35
		label.TextTransparency = value and 0 or 0.35
	end

	function api.OnClick(callback)
		button.MouseButton1Click:Connect(function()
			if api.Enabled then
				callback()
			end
		end)
	end

	return api
end

-- Cartão selecionável (classe, raça ou feat): borda dourada e fundo mais claro quando escolhido
local function createSelectable(parent: Instance, size: UDim2, order: number)
	local card = Instance.new("TextButton")
	card.Text = ""
	card.AutoButtonColor = false
	card.Size = size
	card.BackgroundColor3 = COLORS.Slot
	card.LayoutOrder = order
	card.Parent = parent
	addCorner(card, 10)
	local stroke = addStroke(card, COLORS.SlotBorder, 2)

	local function setSelected(isSelected: boolean)
		card.BackgroundColor3 = isSelected and COLORS.SlotSelected or COLORS.Slot
		stroke.Color = isSelected and COLORS.Selected or COLORS.SlotBorder
		stroke.Thickness = isSelected and 3 or 2
	end

	return card, setSelected
end

local function createList(parent: Instance, position: UDim2, size: UDim2, fillDirection: Enum.FillDirection?): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Position = position
	list.Size = size
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = COLORS.Gold
	list.AutomaticCanvasSize = fillDirection == Enum.FillDirection.Horizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = fillDirection or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	return list
end

-- ScreenGui (remove uma cópia antiga se o script reiniciar)
local oldGui = playerGui:FindFirstChild("CharacterSelectUI")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CharacterSelectUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 110
screenGui.Parent = playerGui

-- Botão da HUD do lobby, logo acima do botão Party (tecla C), e legenda com a escolha atual
local openButton = createButton(screenGui, "Personagem", "Red", Vector2.new(190, 60), 26, "C")
openButton.Button.AnchorPoint = Vector2.new(1, 0.5)
openButton.Button.Position = UDim2.new(1, -30, 0.5, -76)

local currentLabel = createText(screenGui, {
	TextSize = 16,
	Color = COLORS.SecondaryText,
	AlignX = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -30, 0.5, -110),
	Size = UDim2.fromOffset(320, 22),
})

-- Janela: fade, fundo escurecido, painel com borda dourada e faixa de título
local root = Instance.new("CanvasGroup")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.GroupTransparency = 1
root.Visible = false
root.ZIndex = 20
root.Parent = screenGui

local dim = Instance.new("TextButton")
dim.Text = ""
dim.AutoButtonColor = false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = COLORS.Dim
dim.BackgroundTransparency = 0.45
dim.Parent = root

local window = Instance.new("Frame")
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.new(0.5, 0, 0.5, 20)
window.Size = UDim2.fromOffset(820, 560)
window.BackgroundColor3 = COLORS.Panel
window.BackgroundTransparency = 0.05
window.Active = true
window.Parent = root
addCorner(window, 12)
addStroke(window, COLORS.Gold, 3)

local windowScale = Instance.new("UIScale")
windowScale.Parent = window

local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 1)
banner.Position = UDim2.new(0.5, 0, 0, -10)
banner.Size = UDim2.fromOffset(480, 54)
banner.BackgroundColor3 = COLORS.Banner
banner.Parent = window

local bannerFade = Instance.new("UIGradient")
bannerFade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.15),
	NumberSequenceKeypoint.new(0.8, 0.15),
	NumberSequenceKeypoint.new(1, 1),
})
bannerFade.Parent = banner

createText(banner, { Text = "Personagem", TextSize = 36, AlignX = Enum.TextXAlignment.Center, StrokeThickness = 2.5 })

local CONTENT_BOTTOM = 128

-- Coluna da esquerda: lista de classes
createText(window, { Text = "Classe", TextSize = 24, Position = UDim2.fromOffset(22, 14), Size = UDim2.fromOffset(280, 34) })
local classList = createList(window, UDim2.fromOffset(22, 54), UDim2.new(0, 280, 1, -(54 + CONTENT_BOTTOM)))

-- Coluna da direita: nome da classe, status, raça e feats
local RIGHT_X, RIGHT_W = 322, 476

local classTitle = createText(window, { TextSize = 32, Position = UDim2.fromOffset(RIGHT_X, 10), Size = UDim2.fromOffset(RIGHT_W, 40) })

local statsRow = Instance.new("Frame")
statsRow.BackgroundTransparency = 1
statsRow.Position = UDim2.fromOffset(RIGHT_X, 54)
statsRow.Size = UDim2.fromOffset(RIGHT_W, 58)
statsRow.Parent = window

local statsLayout = Instance.new("UIListLayout")
statsLayout.FillDirection = Enum.FillDirection.Horizontal
statsLayout.Padding = UDim.new(0, 10)
statsLayout.Parent = statsRow

local statValues = {}
for order, stat in { { key = "maxHealth", label = "Vida" }, { key = "attack", label = "Ataque" }, { key = "defense", label = "Defesa" } } do
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(152, 58)
	box.BackgroundColor3 = COLORS.Slot
	box.LayoutOrder = order
	box.Parent = statsRow
	addCorner(box, 10)
	addStroke(box, COLORS.SlotBorder, 2)

	createText(box, { Text = stat.label, TextSize = 15, Color = COLORS.SecondaryText, Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 20) })
	statValues[stat.key] = createText(box, { TextSize = 26, Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 30) })
end

createText(window, { Text = "Raça", TextSize = 22, Position = UDim2.fromOffset(RIGHT_X, 120), Size = UDim2.fromOffset(RIGHT_W, 30) })
local raceList = createList(window, UDim2.fromOffset(RIGHT_X, 152), UDim2.fromOffset(RIGHT_W, 44), Enum.FillDirection.Horizontal)

local featHeader = createText(window, { TextSize = 22, Position = UDim2.fromOffset(RIGHT_X, 204), Size = UDim2.fromOffset(RIGHT_W, 30) })
local featList = createList(window, UDim2.fromOffset(RIGHT_X, 238), UDim2.new(0, RIGHT_W, 1, -(238 + CONTENT_BOTTOM)))

-- Mensagens do servidor e botões inferiores
local statusLabel = createText(window, {
	TextSize = 18,
	Color = COLORS.Message,
	AlignX = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -84),
	Size = UDim2.new(1, -44, 0, 26),
})
statusLabel.TextTransparency = 1

local bottomRow = Instance.new("Frame")
bottomRow.AnchorPoint = Vector2.new(0.5, 1)
bottomRow.Position = UDim2.new(0.5, 0, 1, -16)
bottomRow.Size = UDim2.new(1, -44, 0, 58)
bottomRow.BackgroundTransparency = 1
bottomRow.Parent = window

local bottomLayout = Instance.new("UIListLayout")
bottomLayout.FillDirection = Enum.FillDirection.Horizontal
bottomLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
bottomLayout.VerticalAlignment = Enum.VerticalAlignment.Center
bottomLayout.SortOrder = Enum.SortOrder.LayoutOrder
bottomLayout.Padding = UDim.new(0, 14)
bottomLayout.Parent = bottomRow

local confirmButton = createButton(bottomRow, "Confirmar", "Green", Vector2.new(200, 54), 26)
local closeButton = createButton(bottomRow, "Fechar", "Gray", Vector2.new(140, 54), 24)
confirmButton.Button.LayoutOrder = 1
closeButton.Button.LayoutOrder = 2

local messageToken = 0

local function showMessage(text: string?, isError: boolean?)
	if type(text) ~= "string" or text == "" then
		return
	end

	messageToken += 1
	local token = messageToken

	statusLabel.Text = text
	statusLabel.TextColor3 = isError and COLORS.Error or COLORS.Message
	TweenService:Create(statusLabel, FADE, { TextTransparency = 0 }):Play()

	task.delay(MESSAGE_TIME, function()
		if token == messageToken then
			TweenService:Create(statusLabel, FADE, { TextTransparency = 1 }):Play()
		end
	end)
end

-- Feats que a classe pode usar (sem classId = qualquer classe), igual à regra do servidor
local function featsForClass(classId: string?)
	local list = {}
	for _, feat in allFeats do
		if feat.classId == nil or sameId(feat.classId, classId) then
			table.insert(list, feat)
		end
	end
	return list
end

local function isDirty(): boolean
	if not saved then
		return true
	end
	return not sameId(saved.class, selected.class)
		or not sameId(saved.race, selected.race)
		or table.concat(saved.feats or {}, ",") ~= table.concat(selected.feats, ",")
end

local function refreshConfirm()
	local dirty = isDirty()
	confirmButton.SetText(dirty and "Confirmar" or "Salvo")
	confirmButton.SetEnabled(dirty and selected.class ~= nil)
end

-- Legenda da HUD com a escolha confirmada (classe • feat)
local function refreshCurrentLabel()
	local classLabel = player:GetAttribute("CharacterClassLabel")
	local featLabel = player:GetAttribute("CharacterFeatLabel")
	currentLabel.Text = classLabel and (classLabel .. ((featLabel and featLabel ~= "") and (" • " .. featLabel) or "")) or ""
end

-- Lista de classes: criada uma vez; só o destaque muda
local classCards = {}

-- Atualiza a coluna da direita para a classe selecionada (status, raças e feats permitidos)
local renderDetails

local function selectClass(classDef)
	if not sameId(selected.class, classDef.id) then
		selected.class = classDef.id
		-- Feats que a nova classe não pode usar são removidos da escolha
		local allowed = {}
		for _, featId in selected.feats do
			local feat = Registry.Get("Feats", featId)
			if feat and (feat.classId == nil or sameId(feat.classId, classDef.id)) then
				table.insert(allowed, feat.id)
			end
		end
		selected.feats = allowed
	end

	renderDetails()
end

for index, classDef in classes do
	local card, setSelected = createSelectable(classList, UDim2.new(1, -10, 0, 52), index)
	createDiamond(card, UDim2.fromOffset(30, 26), 24, CLASS_COLORS[(index - 1) % #CLASS_COLORS + 1])
	createText(card, { Text = displayName(classDef), TextSize = 22, Position = UDim2.fromOffset(58, 0), Size = UDim2.new(1, -66, 1, 0) })

	card.MouseButton1Click:Connect(function()
		selectClass(classDef)
	end)

	classCards[classDef.id] = setSelected
end

-- Desenha raças e feats da classe atual e marca o que está escolhido
local raceCards, featCards = {}, {}

renderDetails = function()
	local classDef = Registry.Get("Classes", selected.class)

	for id, setSelected in classCards do
		setSelected(sameId(id, selected.class))
	end

	classTitle.Text = classDef and displayName(classDef) or "Escolha uma classe"
	local baseStats = classDef and classDef.baseStats or {}
	for key, label in statValues do
		label.Text = baseStats[key] and tostring(baseStats[key]) or "-"
	end

	for _, card in raceCards do
		card:Destroy()
	end
	table.clear(raceCards)

	for index, race in races do
		local card, setSelected = createSelectable(raceList, UDim2.fromOffset(140, 40), index)
		createText(card, { Text = displayName(race), TextSize = 18, AlignX = Enum.TextXAlignment.Center })
		setSelected(sameId(race.id, selected.race))

		card.MouseButton1Click:Connect(function()
			selected.race = race.id
			renderDetails()
		end)

		table.insert(raceCards, card)
	end

	for _, card in featCards do
		card:Destroy()
	end
	table.clear(featCards)

	local feats = featsForClass(selected.class)
	featHeader.Text = string.format("Feat (%d/%d)", #selected.feats, MAX_FEATS)

	local noneCard, setNone = createSelectable(featList, UDim2.new(1, -10, 0, 52), 0)
	createText(noneCard, { Text = "Sem feat", TextSize = 20, Color = COLORS.SecondaryText, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0) })
	setNone(#selected.feats == 0)
	noneCard.MouseButton1Click:Connect(function()
		table.clear(selected.feats)
		renderDetails()
	end)
	table.insert(featCards, noneCard)

	for index, feat in feats do
		local card, setSelected = createSelectable(featList, UDim2.new(1, -10, 0, 64), index)
		createText(card, { Text = displayName(feat), TextSize = 20, Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -32, 0, 26) })
		createText(card, {
			Text = feat.description or "",
			TextSize = 15,
			Color = COLORS.SecondaryText,
			Position = UDim2.fromOffset(16, 34),
			Size = UDim2.new(1, -32, 0, 22),
			StrokeThickness = 1.5,
		})

		local isChosen = table.find(selected.feats, feat.id) ~= nil
		setSelected(isChosen)

		card.MouseButton1Click:Connect(function()
			local position = table.find(selected.feats, feat.id)
			if position then
				table.remove(selected.feats, position)
			elseif MAX_FEATS == 1 then
				selected.feats = { feat.id }
			elseif #selected.feats < MAX_FEATS then
				table.insert(selected.feats, feat.id)
			else
				showMessage(string.format("Você só pode escolher %d feats.", MAX_FEATS), true)
			end
			renderDetails()
		end)

		table.insert(featCards, card)
	end

	refreshConfirm()
end

-- Carrega a escolha atual do servidor (Attributes do jogador) para a tela, sem apagar edições não salvas
local function loadFromAttributes()
	local class = player:GetAttribute("CharacterClass")
	if not class then
		return
	end

	local featText = player:GetAttribute("CharacterFeats") or ""
	local feats = featText ~= "" and string.split(featText, ",") or {}

	saved = { class = class, race = player:GetAttribute("CharacterRace"), feats = feats }

	if not isOpen or not selected.class then
		selected = { class = saved.class, race = saved.race, feats = table.clone(feats) }
	end

	refreshCurrentLabel()
	renderDetails()
end

for _, attribute in { "CharacterClass", "CharacterRace", "CharacterFeats", "CharacterClassLabel", "CharacterFeatLabel" } do
	player:GetAttributeChangedSignal(attribute):Connect(loadFromAttributes)
end

-- Abre/fecha com fade e "pop"
local function setOpen(open: boolean)
	isOpen = open

	if open then
		loadFromAttributes()
		root.Visible = true
		windowScale.Scale = 0.95
		TweenService:Create(root, FADE, { GroupTransparency = 0 }):Play()
		TweenService:Create(windowScale, POP, { Scale = 1 }):Play()
	else
		TweenService:Create(root, FADE, { GroupTransparency = 1 }):Play()
		task.delay(FADE.Time, function()
			if not isOpen then
				root.Visible = false
			end
		end)
	end
end

-- Resposta do servidor ao salvar: dados confirmados ou motivo da recusa
Remotes.CharacterCreated.OnClientEvent:Connect(function(data, message)
	if type(data) == "table" then
		saved = { class = data.class, race = data.race, feats = table.clone(data.feats or {}) }
		selected = { class = data.class, race = data.race, feats = table.clone(data.feats or {}) }
		renderDetails()
		showMessage(message)
	else
		showMessage(message or "Não foi possível salvar o personagem.", true)
		refreshConfirm()
	end
end)

confirmButton.OnClick(function()
	if not selected.class then
		return
	end

	confirmButton.SetEnabled(false)
	confirmButton.SetText("Salvando...")
	Remotes.SubmitCharacter:FireServer({
		class = selected.class,
		race = selected.race,
		feats = table.clone(selected.feats),
	})
end)

openButton.OnClick(function()
	setOpen(not isOpen)
end)

closeButton.OnClick(function()
	setOpen(false)
end)

dim.MouseButton1Click:Connect(function()
	setOpen(false)
end)

-- Atalhos: C abre/fecha e Esc fecha (ignorados enquanto o jogador digita)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == OPEN_KEY then
		setOpen(not isOpen)
	elseif input.KeyCode == Enum.KeyCode.Escape and isOpen then
		setOpen(false)
	end
end)

if not selected.class and classes[1] then
	selected.class = classes[1].id
end
selected.race = selected.race or (races[1] and races[1].id)

loadFromAttributes()
renderDetails()
refreshCurrentLabel()
print("[CharacterSelectUI] Interface inicializada.")
