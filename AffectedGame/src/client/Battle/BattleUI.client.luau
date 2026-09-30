local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Registry = require(Shared:WaitForChild("Characters"):WaitForChild("Registry"))

local FONT = Enum.Font.FredokaOne
local HOVER_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local COLORS = {
	Text = Color3.new(1, 1, 1),
	TextStroke = Color3.fromRGB(20, 15, 15),
	KeyBack = Color3.fromRGB(70, 70, 75),
	KeyBorder = Color3.fromRGB(35, 35, 38),
	Dim = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(22, 22, 26),
	Gold = Color3.fromRGB(215, 150, 45),
	Slot = Color3.fromRGB(45, 45, 52),
	SlotHover = Color3.fromRGB(62, 62, 70),
	SecondaryText = Color3.fromRGB(185, 185, 190),
}

-- Botões principais: texto, tecla de atalho, cor de fundo, cor da borda e ação (para trocar a tecla, mude key e keyText)
local MAIN_BUTTONS = {
	{ text = "Fight", key = Enum.KeyCode.F, keyText = "F", fill = Color3.fromRGB(150, 10, 10), border = Color3.fromRGB(215, 20, 20), action = "Fight" },
	{ text = "Itens", key = Enum.KeyCode.E, keyText = "E", fill = Color3.fromRGB(205, 165, 10), border = Color3.fromRGB(235, 195, 25), action = "Item" },
	{ text = "Focus", key = Enum.KeyCode.C, keyText = "C", fill = Color3.fromRGB(10, 80, 205), border = Color3.fromRGB(25, 105, 235), action = "Focus" },
}

-- Ataques do menu Fight: texto, id da ação no servidor (FightActions) e tecla
local SKILLS = {
	{ text = "Normal Attack", id = "NormalAttack", key = Enum.KeyCode.One, keyText = "1" },
	{ text = "Strong Attack", id = "StrongAttack", key = Enum.KeyCode.Two, keyText = "2" },
}

local SKILL_COLORS = { fill = Color3.fromRGB(95, 25, 25), border = Color3.fromRGB(170, 45, 45) }

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BattleUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Helpers visuais: cantos, contorno, texto com contorno grosso e layout horizontal
local function addCorner(object: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
end

local function addStroke(object: GuiObject, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = object
end

local function createText(parent: Instance, text: string, textSize: number, zIndex: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = FONT
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = COLORS.Text
	label.ZIndex = zIndex
	label.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.TextStroke
	stroke.Thickness = 2.5
	stroke.Parent = label

	return label
end

local function createRow(name: string, bottomOffset: number, height: number): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -bottomOffset)
	row.Size = UDim2.new(0, 600, 0, height)
	row.BackgroundTransparency = 1
	row.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 18)
	layout.Parent = row

	return row
end

-- Botão estilo cartoon: fundo com brilho, borda grossa, texto com contorno, tecla no canto e véu de desativado
local function createActionButton(parent: Instance, spec, size: Vector2, textSize: number, order: number)
	local button = Instance.new("TextButton")
	button.Name = spec.text
	button.Size = UDim2.fromOffset(size.X, size.Y)
	button.BackgroundColor3 = spec.fill
	button.AutoButtonColor = false
	button.Text = ""
	button.LayoutOrder = order
	button.Parent = parent
	addCorner(button, 14)
	addStroke(button, spec.border, 4)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175))
	gradient.Rotation = 90
	gradient.Parent = button

	local scale = Instance.new("UIScale")
	scale.Parent = button

	createText(button, spec.text, textSize, 2)

	local keyCap = Instance.new("Frame")
	keyCap.AnchorPoint = Vector2.new(0.5, 0.5)
	keyCap.Position = UDim2.fromOffset(6, 6)
	keyCap.Size = UDim2.fromOffset(30, 30)
	keyCap.BackgroundColor3 = COLORS.KeyBack
	keyCap.ZIndex = 3
	keyCap.Parent = button
	addCorner(keyCap, 6)
	addStroke(keyCap, COLORS.KeyBorder, 2.5)
	createText(keyCap, spec.keyText, 18, 4)

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = COLORS.Dim
	dim.BackgroundTransparency = 0.55
	dim.ZIndex = 5
	dim.Visible = false
	dim.Parent = button
	addCorner(dim, 14)

	button.MouseEnter:Connect(function()
		TweenService:Create(scale, HOVER_TWEEN, { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, HOVER_TWEEN, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, HOVER_TWEEN, { Scale = 0.95 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, HOVER_TWEEN, { Scale = 1.05 }):Play()
	end)

	return button, dim
end

local mainRow = createRow("MainButtons", 30, 70)
local skillRow = createRow("SkillMenu", 118, 58)
skillRow.Visible = false

local dimOverlays = {}
local mainButtons = {}

-- Teclas que a câmera padrão do Roblox usa para zoom (I e O); elas são ligadas com prioridade maior lá embaixo
local CAMERA_KEYS = { [Enum.KeyCode.I] = true, [Enum.KeyCode.O] = true }

local function isMyTurn(): boolean
	return player:GetAttribute("IsBattleTurn") == true
end

-- Painel do inventário acima dos botões: título, contador de slots e grade de itens (4 por linha)
local ITEM_KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
	Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight,
}

local itemPanel = Instance.new("Frame")
itemPanel.Name = "InventoryPanel"
itemPanel.AnchorPoint = Vector2.new(0.5, 1)
itemPanel.Position = UDim2.new(0.5, 0, 1, -112)
itemPanel.Size = UDim2.fromOffset(620, 196)
itemPanel.BackgroundColor3 = COLORS.Panel
itemPanel.BackgroundTransparency = 0.1
itemPanel.Visible = false
itemPanel.Parent = screenGui
addCorner(itemPanel, 12)
addStroke(itemPanel, COLORS.Gold, 3)

local itemTitle = createText(itemPanel, "Inventário", 24, 2)
itemTitle.TextXAlignment = Enum.TextXAlignment.Left
itemTitle.Position = UDim2.fromOffset(18, 8)
itemTitle.Size = UDim2.new(0.5, 0, 0, 30)

local slotCounter = createText(itemPanel, "0/8", 18, 2)
slotCounter.TextXAlignment = Enum.TextXAlignment.Right
slotCounter.TextColor3 = COLORS.SecondaryText
slotCounter.AnchorPoint = Vector2.new(1, 0)
slotCounter.Position = UDim2.new(1, -18, 0, 10)
slotCounter.Size = UDim2.new(0.5, 0, 0, 28)

local itemGrid = Instance.new("Frame")
itemGrid.BackgroundTransparency = 1
itemGrid.Position = UDim2.fromOffset(16, 46)
itemGrid.Size = UDim2.new(1, -32, 1, -58)
itemGrid.Parent = itemPanel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(138, 62)
gridLayout.CellPadding = UDim2.fromOffset(10, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = itemGrid

local emptyLabel = createText(itemPanel, "Inventário vazio", 20, 2)
emptyLabel.TextColor3 = COLORS.SecondaryText
emptyLabel.Position = UDim2.fromOffset(0, 40)
emptyLabel.Size = UDim2.new(1, 0, 1, -40)
emptyLabel.Visible = false

-- Cartão de descrição do item que segue o mouse
local tooltip = Instance.new("Frame")
tooltip.Size = UDim2.fromOffset(300, 86)
tooltip.BackgroundColor3 = COLORS.Panel
tooltip.Visible = false
tooltip.ZIndex = 30
tooltip.Parent = screenGui
addCorner(tooltip, 10)
addStroke(tooltip, COLORS.Gold, 2)

local tooltipName = createText(tooltip, "", 20, 31)
tooltipName.TextXAlignment = Enum.TextXAlignment.Left
tooltipName.Position = UDim2.fromOffset(12, 6)
tooltipName.Size = UDim2.new(1, -24, 0, 24)

local tooltipText = createText(tooltip, "", 15, 31)
tooltipText.TextXAlignment = Enum.TextXAlignment.Left
tooltipText.TextYAlignment = Enum.TextYAlignment.Top
tooltipText.TextWrapped = true
tooltipText.Position = UDim2.fromOffset(12, 32)
tooltipText.Size = UDim2.new(1, -24, 0, 36)

local tooltipTarget = createText(tooltip, "", 13, 31)
tooltipTarget.TextXAlignment = Enum.TextXAlignment.Left
tooltipTarget.TextColor3 = COLORS.SecondaryText
tooltipTarget.Position = UDim2.fromOffset(12, 64)
tooltipTarget.Size = UDim2.new(1, -24, 0, 18)

local function moveTooltip()
	local mouse = UserInputService:GetMouseLocation()
	local size = screenGui.AbsoluteSize
	tooltip.Position = UDim2.fromOffset(
		math.clamp(mouse.X + 16, 8, size.X - tooltip.AbsoluteSize.X - 8),
		math.clamp(mouse.Y - tooltip.AbsoluteSize.Y - 12, 8, size.Y - tooltip.AbsoluteSize.Y - 8)
	)
end

local function showTooltip(item)
	tooltipName.Text = item.displayName or item.id
	tooltipText.Text = item.description or ""
	tooltipTarget.Text = item.target == "Enemy" and "Alvo: inimigo selecionado" or "Alvo: você"
	tooltip.Visible = true
	moveTooltip()
end

local function hideTooltip()
	tooltip.Visible = false
end

local function setSkillMenu(isOpen: boolean)
	skillRow.Visible = isOpen and isMyTurn()
	if skillRow.Visible then
		itemPanel.Visible = false
		hideTooltip()
	end
end

local function setItemPanel(isOpen: boolean)
	itemPanel.Visible = isOpen
	if isOpen then
		skillRow.Visible = false
	else
		hideTooltip()
	end
end

-- Envia a ação ao servidor (só no seu turno); ataques e itens levam o inimigo selecionado nos painéis
local function sendAction(actionType: string, skillId: string?, itemId: string?)
	if not isMyTurn() then
		return
	end

	setSkillMenu(false)
	setItemPanel(false)

	local payload = { actionType = actionType, skillId = skillId, itemId = itemId }
	if actionType == "Attack" or actionType == "Item" then
		payload.targetName = player:GetAttribute("SelectedTarget")
	end

	Remotes.BattleAction:FireServer(payload)
end

-- Cartão de um item na grade: ícone em losango na cor do item, nome, quantidade e tecla de atalho
local itemSlots = {}

local function createItemSlot(item, count: number, index: number)
	local slot = Instance.new("TextButton")
	slot.Name = item.id
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.BackgroundColor3 = COLORS.Slot
	slot.LayoutOrder = index
	slot.Parent = itemGrid
	addCorner(slot, 10)
	addStroke(slot, item.color or COLORS.Gold, 2)

	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromOffset(28, 31)
	diamond.Size = UDim2.fromOffset(26, 26)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = item.color or COLORS.Gold
	diamond.ZIndex = 2
	diamond.Parent = slot
	addStroke(diamond, COLORS.TextStroke, 2)

	local icon = createText(slot, item.icon or string.sub(item.displayName or item.id, 1, 1), 18, 3)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromOffset(28, 31)
	icon.Size = UDim2.fromOffset(30, 30)

	local name = createText(slot, item.displayName or item.id, 15, 3)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextWrapped = true
	name.Position = UDim2.fromOffset(50, 6)
	name.Size = UDim2.new(1, -56, 0, 34)

	local amount = createText(slot, "x" .. count, 16, 3)
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.TextColor3 = COLORS.SecondaryText
	amount.AnchorPoint = Vector2.new(1, 1)
	amount.Position = UDim2.new(1, -8, 1, -4)
	amount.Size = UDim2.fromOffset(50, 20)

	if index <= #ITEM_KEYS then
		local keyCap = Instance.new("Frame")
		keyCap.AnchorPoint = Vector2.new(0.5, 0.5)
		keyCap.Position = UDim2.fromOffset(4, 4)
		keyCap.Size = UDim2.fromOffset(22, 22)
		keyCap.BackgroundColor3 = COLORS.KeyBack
		keyCap.ZIndex = 4
		keyCap.Parent = slot
		addCorner(keyCap, 5)
		addStroke(keyCap, COLORS.KeyBorder, 2)
		createText(keyCap, tostring(index), 14, 5)
	end

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = COLORS.Dim
	dim.BackgroundTransparency = 0.55
	dim.ZIndex = 6
	dim.Visible = not isMyTurn()
	dim.Parent = slot
	addCorner(dim, 10)

	slot.MouseEnter:Connect(function()
		slot.BackgroundColor3 = COLORS.SlotHover
		showTooltip(item)
	end)
	slot.MouseMoved:Connect(moveTooltip)
	slot.MouseLeave:Connect(function()
		slot.BackgroundColor3 = COLORS.Slot
		hideTooltip()
	end)
	slot.MouseButton1Click:Connect(function()
		sendAction("Item", nil, item.id)
	end)

	table.insert(itemSlots, { Slot = slot, Dim = dim, Item = item })
end

-- Redesenha a grade a partir do Attribute "Inventory" que o servidor atualiza a cada mudança
local function refreshInventory()
	for _, entry in itemSlots do
		entry.Slot:Destroy()
	end
	table.clear(itemSlots)
	hideTooltip()

	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Inventory") or "[]")
	if not ok or type(list) ~= "table" then
		list = {}
	end

	for index, entry in list do
		local item = Registry.Get("Items", entry.id)
		if item then
			createItemSlot(item, entry.count or 1, index)
		end
	end

	emptyLabel.Visible = #itemSlots == 0
	slotCounter.Text = string.format("%d/%d", #list, player:GetAttribute("InventorySlots") or 8)
end

player:GetAttributeChangedSignal("Inventory"):Connect(refreshInventory)
player:GetAttributeChangedSignal("InventorySlots"):Connect(refreshInventory)
refreshInventory()

-- Executa o que cada botão principal faz: Fight abre os ataques, Itens abre o inventário, Focus age direto
local function pressMain(action: string)
	if action == "Fight" then
		setSkillMenu(not skillRow.Visible)
	elseif action == "Item" then
		setItemPanel(not itemPanel.Visible)
	else
		sendAction(action)
	end
end

for order, spec in MAIN_BUTTONS do
	local button, dim = createActionButton(mainRow, spec, Vector2.new(170, 62), 30, order)
	table.insert(dimOverlays, dim)
	if not CAMERA_KEYS[spec.key] then
		mainButtons[spec.key] = spec.action
	end
	button.MouseButton1Click:Connect(function()
		pressMain(spec.action)
	end)
end

local skillKeys = {}
for order, skill in SKILLS do
	local spec = { text = skill.text, keyText = skill.keyText, fill = SKILL_COLORS.fill, border = SKILL_COLORS.border }
	local button, dim = createActionButton(skillRow, spec, Vector2.new(190, 50), 20, order)
	table.insert(dimOverlays, dim)
	skillKeys[skill.key] = skill.id
	button.MouseButton1Click:Connect(function()
		sendAction("Attack", skill.id)
	end)
end

-- Escurece botões e itens fora do seu turno (o inventário continua podendo ser aberto só para olhar)
local function refreshTurn()
	local myTurn = isMyTurn()

	for _, dim in dimOverlays do
		dim.Visible = not myTurn
	end
	for _, entry in itemSlots do
		entry.Dim.Visible = not myTurn
	end

	if not myTurn then
		setSkillMenu(false)
	end
end

player:GetAttributeChangedSignal("IsBattleTurn"):Connect(refreshTurn)
refreshTurn()

-- Botões cuja tecla é I ou O: a câmera padrão "consome" essas teclas antes do InputBegan,
-- então elas são ligadas com prioridade maior que a da câmera para funcionarem como atalho
for _, spec in MAIN_BUTTONS do
	if CAMERA_KEYS[spec.key] then
		ContextActionService:BindActionAtPriority("BattleKey_" .. spec.action, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				pressMain(spec.action)
			end

			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, spec.key)
	end
end

-- Atalhos: teclas dos botões principais (I/O ficam na ligação acima), números nos ataques ou itens (o painel aberto decide) e Esc fecha tudo
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	local key = input.KeyCode
	local itemIndex = table.find(ITEM_KEYS, key)

	if mainButtons[key] then
		pressMain(mainButtons[key])
	elseif itemPanel.Visible and itemIndex then
		local entry = itemSlots[itemIndex]
		if entry then
			sendAction("Item", nil, entry.Item.id)
		end
	elseif skillRow.Visible and skillKeys[key] then
		sendAction("Attack", skillKeys[key])
	elseif key == Enum.KeyCode.Escape then
		setSkillMenu(false)
		setItemPanel(false)
	end
end)
