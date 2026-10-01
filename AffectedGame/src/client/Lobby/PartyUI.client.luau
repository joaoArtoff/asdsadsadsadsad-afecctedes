local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("Remotes"))

local FONT = Enum.Font.FredokaOne
local MAX_PARTY_MEMBERS = 4
local OPEN_KEY = Enum.KeyCode.P
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
	Slot = Color3.fromRGB(42, 42, 48),
	SlotEmpty = Color3.fromRGB(30, 30, 35),
	SlotBorder = Color3.fromRGB(70, 70, 78),
	Gold = Color3.fromRGB(215, 150, 45),
	Banner = Color3.fromRGB(70, 70, 70),
	KeyBack = Color3.fromRGB(70, 70, 75),
	KeyBorder = Color3.fromRGB(35, 35, 38),
	Leader = Color3.fromRGB(255, 210, 70),
	You = Color3.fromRGB(120, 190, 255),
	Message = Color3.fromRGB(255, 225, 120),
}

-- Paleta dos botões cartoon (a mesma dos botões Fight/Itens/Focus da batalha)
local BUTTON_STYLES = {
	Red = { fill = Color3.fromRGB(150, 10, 10), border = Color3.fromRGB(215, 20, 20) },
	Yellow = { fill = Color3.fromRGB(205, 165, 10), border = Color3.fromRGB(235, 195, 25) },
	Blue = { fill = Color3.fromRGB(10, 80, 205), border = Color3.fromRGB(25, 105, 235) },
	Green = { fill = Color3.fromRGB(30, 130, 20), border = Color3.fromRGB(80, 190, 45) },
	Gray = { fill = Color3.fromRGB(70, 70, 78), border = Color3.fromRGB(110, 110, 118) },
}

-- Estado local: party atual recebida do servidor e se a janela está aberta
local currentParty = nil
local isOpen = false
local searching = false

-- Helpers visuais: cantos, contornos, fade, texto com contorno grosso e losango (mesmo padrão da HUD de batalha)
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
	label.TextXAlignment = props.AlignX or Enum.TextXAlignment.Center
	label.TextWrapped = true
	label.TextScaled = props.MaxTextSize ~= nil
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.Position = props.Position or UDim2.new()
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.ZIndex = props.ZIndex or 1
	label.Parent = parent

	if props.MaxTextSize then
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = props.MaxTextSize
		limit.Parent = label
	end

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

-- Botão cartoon (preenchido, brilho, borda grossa, tecla opcional); devolve controles para trocar texto, cor e travar
local function createButton(parent: Instance, text: string, styleName: string, size: Vector2, textSize: number, keyText: string?)
	local style = BUTTON_STYLES[styleName]

	local button = Instance.new("TextButton")
	button.Name = text
	button.Size = UDim2.fromOffset(size.X, size.Y)
	button.BackgroundColor3 = style.fill
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent
	addCorner(button, 12)
	local stroke = addStroke(button, style.border, 3)

	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175))
	shine.Rotation = 90
	shine.Parent = button

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local label = createText(button, {
		Text = text,
		MaxTextSize = textSize,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -20, 1, -10),
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
		createText(keyCap, { Text = keyText, TextSize = 17, ZIndex = 4 })
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
	button.MouseButton1Down:Connect(function()
		if api.Enabled then
			TweenService:Create(scale, HOVER, { Scale = 0.95 }):Play()
		end
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
	end)

	function api.SetText(value: string)
		label.Text = value
	end

	function api.SetStyle(name: string)
		local newStyle = BUTTON_STYLES[name]
		button.BackgroundColor3 = newStyle.fill
		stroke.Color = newStyle.border
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

-- ScreenGui (remove uma cópia antiga se o script reiniciar pelo Rojo/Studio)
local oldGui = playerGui:FindFirstChild("PartyUI")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PartyUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.Parent = playerGui

-- Botão fixo da HUD do lobby (tecla P)
local openButton = createButton(screenGui, "Party", "Blue", Vector2.new(150, 60), 30, "P")
openButton.Button.AnchorPoint = Vector2.new(1, 0.5)
openButton.Button.Position = UDim2.new(1, -30, 0.5, 0)

-- Janela: CanvasGroup para o fade, fundo escurecido, painel com borda dourada e faixa de título
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
window.Size = UDim2.fromOffset(600, 520)
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
banner.Size = UDim2.fromOffset(460, 54)
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

local title = createText(banner, { Text = "Party", TextSize = 36, StrokeThickness = 2.5 })

-- Cabeçalho interno: texto da seção à esquerda e contador ou botão Atualizar à direita
local headerLabel = createText(window, {
	TextSize = 24,
	AlignX = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(22, 16),
	Size = UDim2.new(0.6, 0, 0, 36),
})

local counterLabel = createText(window, {
	TextSize = 22,
	Color = COLORS.SecondaryText,
	AlignX = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -22, 0, 16),
	Size = UDim2.fromOffset(160, 36),
})

local refreshButton = createButton(window, "Atualizar", "Blue", Vector2.new(140, 40), 20)
refreshButton.Button.AnchorPoint = Vector2.new(1, 0)
refreshButton.Button.Position = UDim2.new(1, -22, 0, 14)

local CONTENT_TOP, CONTENT_BOTTOM = 62, 128

-- Navegador: lista rolável de parties abertas
local browserFrame = Instance.new("ScrollingFrame")
browserFrame.Position = UDim2.fromOffset(22, CONTENT_TOP)
browserFrame.Size = UDim2.new(1, -44, 1, -(CONTENT_TOP + CONTENT_BOTTOM))
browserFrame.BackgroundTransparency = 1
browserFrame.BorderSizePixel = 0
browserFrame.ScrollBarThickness = 5
browserFrame.ScrollBarImageColor3 = COLORS.Gold
browserFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
browserFrame.CanvasSize = UDim2.new()
browserFrame.Parent = window

local browserLayout = Instance.new("UIListLayout")
browserLayout.Padding = UDim.new(0, 8)
browserLayout.SortOrder = Enum.SortOrder.LayoutOrder
browserLayout.Parent = browserFrame

local emptyLabel = createText(window, {
	TextSize = 22,
	Color = COLORS.SecondaryText,
	Position = UDim2.fromOffset(22, CONTENT_TOP),
	Size = UDim2.new(1, -44, 1, -(CONTENT_TOP + CONTENT_BOTTOM)),
})

-- Tela da party: 4 vagas com losango (coroa para o líder), nome, classe/feat e tags Líder/Você
local partyFrame = Instance.new("Frame")
partyFrame.Position = UDim2.fromOffset(22, CONTENT_TOP)
partyFrame.Size = UDim2.new(1, -44, 1, -(CONTENT_TOP + CONTENT_BOTTOM))
partyFrame.BackgroundTransparency = 1
partyFrame.Parent = window

local partyLayout = Instance.new("UIListLayout")
partyLayout.Padding = UDim.new(0, 10)
partyLayout.SortOrder = Enum.SortOrder.LayoutOrder
partyLayout.Parent = partyFrame

local memberSlots = {}

for index = 1, MAX_PARTY_MEMBERS do
	local slot = Instance.new("Frame")
	slot.Size = UDim2.new(1, 0, 0, 68)
	slot.BackgroundColor3 = COLORS.SlotEmpty
	slot.LayoutOrder = index
	slot.Parent = partyFrame
	addCorner(slot, 10)
	local stroke = addStroke(slot, COLORS.SlotBorder, 2)

	local diamond = createDiamond(slot, UDim2.fromOffset(38, 34), 32, COLORS.SlotBorder)
	local icon = createText(slot, {
		TextSize = 20,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(38, 34),
		Size = UDim2.fromOffset(36, 36),
		ZIndex = 3,
	})

	local name = createText(slot, {
		TextSize = 22,
		AlignX = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(74, 8),
		Size = UDim2.new(1, -220, 0, 28),
	})

	local subtitle = createText(slot, {
		TextSize = 15,
		Color = COLORS.SecondaryText,
		AlignX = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(74, 38),
		Size = UDim2.new(1, -220, 0, 20),
		StrokeThickness = 1.5,
	})

	local tag = createText(slot, {
		TextSize = 18,
		AlignX = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 0),
		Size = UDim2.new(0, 140, 1, 0),
	})

	memberSlots[index] = { Frame = slot, Stroke = stroke, Diamond = diamond, Icon = icon, Name = name, Subtitle = subtitle, Tag = tag }
end

-- Linha de mensagens do servidor (entrou, saiu, erro de teleporte...) acima dos botões
local statusLabel = createText(window, {
	TextSize = 18,
	Color = COLORS.Message,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -84),
	Size = UDim2.new(1, -44, 0, 26),
})
statusLabel.TextTransparency = 1

-- Botões inferiores
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

local createPartyButton = createButton(bottomRow, "Criar Party", "Green", Vector2.new(180, 54), 24)
local leaveButton = createButton(bottomRow, "Sair", "Red", Vector2.new(130, 54), 24)
local playButton = createButton(bottomRow, "Jogar", "Yellow", Vector2.new(160, 54), 26)
local closeButton = createButton(bottomRow, "Fechar", "Gray", Vector2.new(130, 54), 24)

createPartyButton.Button.LayoutOrder = 1
leaveButton.Button.LayoutOrder = 2
playButton.Button.LayoutOrder = 3
closeButton.Button.LayoutOrder = 4

-- Mostra uma mensagem por alguns segundos; cada mensagem nova reinicia o tempo
local messageToken = 0

local function showMessage(text: string?)
	if type(text) ~= "string" or text == "" then
		return
	end

	messageToken += 1
	local token = messageToken

	statusLabel.Text = text
	TweenService:Create(statusLabel, FADE, { TextTransparency = 0 }):Play()

	task.delay(MESSAGE_TIME, function()
		if token == messageToken then
			TweenService:Create(statusLabel, FADE, { TextTransparency = 1 }):Play()
		end
	end)
end

-- Cartão de party no navegador: líder, quantidade e botão Entrar (ou Cheia)
local function createPartyCard(info, index: number)
	local card = Instance.new("Frame")
	card.Name = "PartyCard"
	card.Size = UDim2.new(1, -10, 0, 70)
	card.BackgroundColor3 = COLORS.Slot
	card.LayoutOrder = index
	card.Parent = browserFrame
	addCorner(card, 10)
	addStroke(card, COLORS.SlotBorder, 2)

	createDiamond(card, UDim2.fromOffset(34, 35), 28, COLORS.Leader)
	createText(card, {
		Text = "★",
		TextSize = 18,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(34, 35),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 3,
	})

	createText(card, {
		Text = "Party de " .. tostring(info.leaderName),
		TextSize = 22,
		AlignX = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(66, 8),
		Size = UDim2.new(1, -210, 0, 30),
	})

	createText(card, {
		Text = string.format("%d/%d jogadores", info.memberCount or 0, info.maxPlayers or MAX_PARTY_MEMBERS),
		TextSize = 16,
		Color = COLORS.SecondaryText,
		AlignX = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(66, 38),
		Size = UDim2.new(1, -210, 0, 22),
	})

	local full = (info.memberCount or 0) >= (info.maxPlayers or MAX_PARTY_MEMBERS)
	local joinButton = createButton(card, full and "Cheia" or "Entrar", full and "Gray" or "Green", Vector2.new(120, 48), 22)
	joinButton.Button.AnchorPoint = Vector2.new(1, 0.5)
	joinButton.Button.Position = UDim2.new(1, -12, 0.5, 0)
	joinButton.SetEnabled(not full)

	joinButton.OnClick(function()
		joinButton.SetText("Entrando...")
		joinButton.SetEnabled(false)
		Remotes.JoinParty:FireServer(info.partyId)
	end)
end

-- Busca as parties abertas no servidor (sem travar a interface) e monta a lista
local function searchParties()
	if searching then
		return
	end

	searching = true
	refreshButton.SetEnabled(false)
	refreshButton.SetText("Buscando...")

	for _, child in browserFrame:GetChildren() do
		if child.Name == "PartyCard" then
			child:Destroy()
		end
	end

	emptyLabel.Text = "Procurando parties..."
	emptyLabel.Visible = browserFrame.Visible

	task.spawn(function()
		local ok, parties = pcall(function()
			return Remotes.GetPublicParties:InvokeServer()
		end)

		searching = false
		refreshButton.SetEnabled(true)
		refreshButton.SetText("Atualizar")

		if currentParty then
			return
		end

		if not ok or type(parties) ~= "table" then
			warn("[PartyUI] Erro ao buscar parties:", parties)
			emptyLabel.Text = "Erro ao procurar parties"
			return
		end

		for index, info in parties do
			createPartyCard(info, index)
		end

		emptyLabel.Text = "Nenhuma party aberta.\nCrie uma e chame seus amigos!"
		emptyLabel.Visible = #parties == 0
	end)
end

-- Tela do navegador (sem party)
local function showBrowser()
	title.Text = "Party"
	headerLabel.Text = "Parties abertas"
	counterLabel.Visible = false
	refreshButton.Button.Visible = true

	browserFrame.Visible = true
	partyFrame.Visible = false

	createPartyButton.Button.Visible = true
	leaveButton.Button.Visible = false
	playButton.Button.Visible = false
end

-- Tela da party: preenche as vagas e ajusta os botões para líder, membro ou partida iniciando
local function showParty()
	local party = currentParty
	local isLeader = party.leaderUserId == player.UserId

	title.Text = "Sua Party"
	headerLabel.Text = party.starting and "Entrando na partida..." or "Membros"
	counterLabel.Visible = true
	counterLabel.Text = string.format("%d/%d", #(party.members or {}), party.maxPlayers or MAX_PARTY_MEMBERS)
	refreshButton.Button.Visible = false

	browserFrame.Visible = false
	emptyLabel.Visible = false
	partyFrame.Visible = true

	for index, slot in memberSlots do
		local member = party.members and party.members[index]

		if member then
			local memberIsLeader = member.userId == party.leaderUserId
			local isYou = member.userId == player.UserId
			local tags = {}
			if memberIsLeader then
				table.insert(tags, "Líder")
			end
			if isYou then
				table.insert(tags, "Você")
			end

			slot.Frame.BackgroundColor3 = COLORS.Slot
			slot.Stroke.Color = isYou and COLORS.You or COLORS.SlotBorder
			slot.Diamond.BackgroundColor3 = memberIsLeader and COLORS.Leader or COLORS.Gold
			slot.Icon.Text = memberIsLeader and "★" or tostring(index)
			slot.Name.Text = member.name
			slot.Name.TextColor3 = COLORS.Text
			slot.Subtitle.Text = (member.classLabel or "?") .. ((member.featLabel and member.featLabel ~= "") and (" • " .. member.featLabel) or "")
			slot.Tag.Text = table.concat(tags, " • ")
			slot.Tag.TextColor3 = memberIsLeader and COLORS.Leader or COLORS.You
		else
			slot.Frame.BackgroundColor3 = COLORS.SlotEmpty
			slot.Stroke.Color = COLORS.SlotBorder
			slot.Diamond.BackgroundColor3 = COLORS.SlotBorder
			slot.Icon.Text = ""
			slot.Name.Text = "Vaga livre"
			slot.Name.TextColor3 = COLORS.SecondaryText
			slot.Subtitle.Text = ""
			slot.Tag.Text = ""
		end
	end

	createPartyButton.Button.Visible = false
	leaveButton.Button.Visible = true
	leaveButton.SetEnabled(not party.starting)

	playButton.Button.Visible = true
	if party.starting then
		playButton.SetText("Iniciando...")
		playButton.SetEnabled(false)
	elseif isLeader then
		playButton.SetText("Jogar")
		playButton.SetEnabled(true)
	else
		playButton.SetText("Aguarde")
		playButton.SetEnabled(false)
	end
end

-- Abre/fecha a janela com fade e "pop"; ao abrir sem party já busca a lista
local function setOpen(open: boolean)
	isOpen = open

	if open then
		root.Visible = true
		windowScale.Scale = 0.95
		TweenService:Create(root, FADE, { GroupTransparency = 0 }):Play()
		TweenService:Create(windowScale, POP, { Scale = 1 }):Play()

		if currentParty then
			showParty()
		else
			showBrowser()
			searchParties()
		end
	else
		TweenService:Create(root, FADE, { GroupTransparency = 1 }):Play()
		task.delay(FADE.Time, function()
			if not isOpen then
				root.Visible = false
			end
		end)
	end
end

-- Estado vindo do servidor: party (ou nil) e uma mensagem opcional; abre a janela se chegar mensagem com ela fechada
Remotes.PartyUpdated.OnClientEvent:Connect(function(partyData, message)
	currentParty = type(partyData) == "table" and partyData or nil

	if currentParty then
		showParty()
	else
		showBrowser()
		if isOpen then
			searchParties()
		end
	end

	showMessage(message)
end)

openButton.OnClick(function()
	setOpen(not isOpen)
end)

refreshButton.OnClick(searchParties)
closeButton.OnClick(function()
	setOpen(false)
end)

createPartyButton.OnClick(function()
	if not currentParty then
		Remotes.CreateParty:FireServer()
	end
end)

leaveButton.OnClick(function()
	if currentParty then
		Remotes.LeaveParty:FireServer()
	end
end)

playButton.OnClick(function()
	if currentParty and currentParty.leaderUserId == player.UserId then
		Remotes.StartGame:FireServer()
	end
end)

dim.MouseButton1Click:Connect(function()
	setOpen(false)
end)

-- Atalhos: P abre/fecha e Esc fecha (ignorados enquanto o jogador digita no chat)
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

showBrowser()
print("[PartyUI] Interface inicializada.")
