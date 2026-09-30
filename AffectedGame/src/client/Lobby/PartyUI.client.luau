--------------------------------------------------
-- SERVIÇOS
--------------------------------------------------

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------
-- REMOTES
--------------------------------------------------

local Shared = ReplicatedStorage:WaitForChild("shared")

local Remotes = require(Shared:WaitForChild("Remotes"))

--------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------

local MAX_PARTY_MEMBERS = 4

local COLORS = {

	Background = Color3.fromRGB(16, 18, 24),

	Panel = Color3.fromRGB(24, 27, 35),

	PanelLight = Color3.fromRGB(32, 36, 46),

	Button = Color3.fromRGB(45, 50, 63),

	ButtonHover = Color3.fromRGB(58, 64, 80),

	Green = Color3.fromRGB(55, 130, 80),

	GreenHover = Color3.fromRGB(68, 155, 96),

	Red = Color3.fromRGB(135, 56, 64),

	RedHover = Color3.fromRGB(160, 67, 77),

	Text = Color3.fromRGB(240, 240, 245),

	SecondaryText = Color3.fromRGB(160, 165, 178),

	Stroke = Color3.fromRGB(75, 81, 98),

}

local partyCreated = false

local currentParty = nil

local partyMembers = {}

--------------------------------------------------
-- SCREEN GUI
--------------------------------------------------

-- Evita duplicar a interface caso o script seja reiniciado pelo Studio/Rojo.
local oldPartyUI = playerGui:FindFirstChild("PartyUI")

if oldPartyUI then
	oldPartyUI:Destroy()
end

local screenGui = Instance.new("ScreenGui")

screenGui.Name = "PartyUI"

screenGui.ResetOnSpawn = false

screenGui.IgnoreGuiInset = true

screenGui.Enabled = true

-- Mantém a PartyUI acima de outras ScreenGuis do lobby.
screenGui.DisplayOrder = 100

screenGui.Parent = playerGui

--------------------------------------------------
-- FUNÇÕES AUXILIARES
--------------------------------------------------

local function createCorner(parent, radius)

	local corner = Instance.new("UICorner")

	corner.CornerRadius = UDim.new(0, radius)

	corner.Parent = parent

	return corner

end

--------------------------------------------------

local function createStroke(parent, thickness)

	local stroke = Instance.new("UIStroke")

	stroke.Color = COLORS.Stroke

	stroke.Thickness = thickness or 1

	stroke.Transparency = 0.15

	stroke.Parent = parent

	return stroke

end

--------------------------------------------------

local function addButtonEffects(
	button,
	normalColor,
	hoverColor
)

	button.AutoButtonColor = false

	button.MouseEnter:Connect(function()

		TweenService:Create(

			button,

			TweenInfo.new(0.12),

			{
				BackgroundColor3 = hoverColor
			}

		):Play()

	end)

	button.MouseLeave:Connect(function()

		TweenService:Create(

			button,

			TweenInfo.new(0.12),

			{
				BackgroundColor3 = normalColor
			}

		):Play()

	end)

end

--------------------------------------------------

local function createButton(
	parent,
	text,
	size
)

	local button = Instance.new("TextButton")

	button.Size = size

	button.BackgroundColor3 = COLORS.Button

	button.Text = text

	button.TextColor3 = COLORS.Text

	button.Font = Enum.Font.GothamBold

	button.TextSize = 16

	button.BorderSizePixel = 0

	button.Parent = parent

	createCorner(button, 7)

	createStroke(button, 1)

	addButtonEffects(
		button,
		COLORS.Button,
		COLORS.ButtonHover
	)

	return button

end

--------------------------------------------------
-- BOTÃO DA HUD PARA ABRIR PARTY
--------------------------------------------------

local openPartyButton = Instance.new("TextButton")

openPartyButton.Name = "OpenPartyButton"

openPartyButton.AnchorPoint = Vector2.new(
	1,
	0.5
)

openPartyButton.Position = UDim2.new(
	1,
	-25,
	0.5,
	0
)

openPartyButton.Size = UDim2.fromOffset(
	120,
	48
)

openPartyButton.BackgroundColor3 =
	COLORS.Button

openPartyButton.BorderSizePixel = 0

openPartyButton.Text = "PARTY"

openPartyButton.TextColor3 =
	COLORS.Text

openPartyButton.Font =
	Enum.Font.GothamBold

openPartyButton.TextSize = 16

openPartyButton.Parent =
	screenGui

openPartyButton.ZIndex = 10

createCorner(
	openPartyButton,
	7
)

createStroke(
	openPartyButton,
	1
)

addButtonEffects(
	openPartyButton,
	COLORS.Button,
	COLORS.ButtonHover
)

--------------------------------------------------
-- OVERLAY
--------------------------------------------------

local overlay = Instance.new("Frame")

overlay.Name = "Overlay"

overlay.Size = UDim2.fromScale(
	1,
	1
)

overlay.BackgroundColor3 =
	Color3.new(0, 0, 0)

overlay.BackgroundTransparency =
	0.45

overlay.BorderSizePixel = 0

--------------------------------------------------
-- IMPORTANTE
-- A PARTY COMEÇA FECHADA
--------------------------------------------------

overlay.Visible = false

overlay.Parent = screenGui

overlay.ZIndex = 20

--------------------------------------------------
-- JANELA PRINCIPAL
--------------------------------------------------

local mainFrame = Instance.new("Frame")

mainFrame.Name = "MainFrame"

mainFrame.AnchorPoint =
	Vector2.new(
		0.5,
		0.5
	)

mainFrame.Position =
	UDim2.fromScale(
		0.5,
		0.5
	)

mainFrame.Size =
	UDim2.fromOffset(
		560,
		520
	)

mainFrame.BackgroundColor3 =
	COLORS.Background

mainFrame.BorderSizePixel = 0

mainFrame.Parent = overlay

createCorner(
	mainFrame,
	10
)

createStroke(
	mainFrame,
	2
)

--------------------------------------------------
-- TÍTULO
--------------------------------------------------

local title = Instance.new("TextLabel")

title.Name = "Title"

title.Size = UDim2.new(
	1,
	-40,
	0,
	70
)

title.Position =
	UDim2.fromOffset(
		20,
		0
	)

title.BackgroundTransparency = 1

title.Text = "PARTY"

title.TextColor3 =
	COLORS.Text

title.Font =
	Enum.Font.GothamBold

title.TextSize = 30

title.Parent = mainFrame

--------------------------------------------------
-- LINHA DO TÍTULO
--------------------------------------------------

local titleLine = Instance.new("Frame")

titleLine.Size = UDim2.new(
	1,
	-40,
	0,
	1
)

titleLine.Position =
	UDim2.fromOffset(
		20,
		68
	)

titleLine.BackgroundColor3 =
	COLORS.Stroke

titleLine.BorderSizePixel = 0

titleLine.Parent = mainFrame

--------------------------------------------------
-- CONTEÚDO
--------------------------------------------------

local contentFrame = Instance.new("Frame")

contentFrame.Name = "Content"

contentFrame.Size = UDim2.new(
	1,
	-40,
	1,
	-160
)

contentFrame.Position =
	UDim2.fromOffset(
		20,
		85
	)

contentFrame.BackgroundColor3 =
	COLORS.Panel

contentFrame.BorderSizePixel = 0

contentFrame.Parent = mainFrame

createCorner(
	contentFrame,
	8
)

createStroke(
	contentFrame,
	1
)

--------------------------------------------------
-- BROWSER DE PARTIES
--------------------------------------------------

local browserFrame = Instance.new("Frame")

browserFrame.Name =
	"PartyBrowser"

browserFrame.Size =
	UDim2.fromScale(
		1,
		1
	)

browserFrame.BackgroundTransparency = 1

browserFrame.Parent =
	contentFrame

--------------------------------------------------
-- LISTA DE PARTIES
--------------------------------------------------

local partyList =
	Instance.new("ScrollingFrame")

partyList.Name =
	"PartyList"

partyList.Size =
	UDim2.new(
		1,
		-30,
		1,
		-90
	)

partyList.Position =
	UDim2.fromOffset(
		15,
		15
	)

partyList.BackgroundTransparency = 1

partyList.BorderSizePixel = 0

partyList.ScrollBarThickness = 4

partyList.AutomaticCanvasSize =
	Enum.AutomaticSize.Y

partyList.CanvasSize =
	UDim2.new()

partyList.Parent =
	browserFrame

--------------------------------------------------
-- LAYOUT
--------------------------------------------------

local partyListLayout =
	Instance.new("UIListLayout")

partyListLayout.Padding =
	UDim.new(
		0,
		8
	)

partyListLayout.SortOrder =
	Enum.SortOrder.LayoutOrder

partyListLayout.Parent =
	partyList

--------------------------------------------------
-- NENHUMA PARTY
--------------------------------------------------

local emptyLabel =
	Instance.new("TextLabel")

emptyLabel.Name =
	"EmptyLabel"

emptyLabel.Size =
	UDim2.new(
		1,
		0,
		0,
		60
	)

emptyLabel.BackgroundTransparency = 1

emptyLabel.Text =
	"Nenhuma party encontrada"

emptyLabel.TextColor3 =
	COLORS.SecondaryText

emptyLabel.Font =
	Enum.Font.Gotham

emptyLabel.TextSize = 18

emptyLabel.Parent =
	partyList

--------------------------------------------------
-- SEARCH
--------------------------------------------------

local searchButton =
	createButton(

		browserFrame,

		"Search",

		UDim2.fromOffset(
			220,
			48
		)

	)

searchButton.AnchorPoint =
	Vector2.new(
		0.5,
		1
	)

searchButton.Position =
	UDim2.new(
		0.5,
		0,
		1,
		-20
	)

--------------------------------------------------
-- PARTY CRIADA
--------------------------------------------------

local partyFrame =
	Instance.new("Frame")

partyFrame.Name =
	"CurrentParty"

partyFrame.Size =
	UDim2.fromScale(
		1,
		1
	)

partyFrame.BackgroundTransparency = 1

partyFrame.Visible = false

partyFrame.Parent =
	contentFrame

--------------------------------------------------
-- CABEÇALHO DA PARTY
--------------------------------------------------

local partyHeader =
	Instance.new("Frame")

partyHeader.Size =
	UDim2.new(
		1,
		-30,
		0,
		55
	)

partyHeader.Position =
	UDim2.fromOffset(
		15,
		15
	)

partyHeader.BackgroundColor3 =
	COLORS.PanelLight

partyHeader.BorderSizePixel = 0

partyHeader.Parent =
	partyFrame

createCorner(
	partyHeader,
	7
)

createStroke(
	partyHeader,
	1
)

--------------------------------------------------
-- NOME DA PARTY
--------------------------------------------------

local partyName =
	Instance.new("TextLabel")

partyName.Size =
	UDim2.new(
		1,
		-100,
		1,
		0
	)

partyName.Position =
	UDim2.fromOffset(
		18,
		0
	)

partyName.BackgroundTransparency = 1

partyName.Text =
	"Sua Party"

partyName.TextColor3 =
	COLORS.Text

partyName.Font =
	Enum.Font.GothamBold

partyName.TextSize = 18

partyName.TextXAlignment =
	Enum.TextXAlignment.Left

partyName.Parent =
	partyHeader

--------------------------------------------------
-- CONTADOR
--------------------------------------------------

local memberCounter =
	Instance.new("TextLabel")

memberCounter.AnchorPoint =
	Vector2.new(
		1,
		0
	)

memberCounter.Position =
	UDim2.new(
		1,
		-18,
		0,
		0
	)

memberCounter.Size =
	UDim2.fromOffset(
		70,
		55
	)

memberCounter.BackgroundTransparency = 1

memberCounter.Text = "1/4"

memberCounter.TextColor3 =
	COLORS.SecondaryText

memberCounter.Font =
	Enum.Font.GothamBold

memberCounter.TextSize = 16

memberCounter.Parent =
	partyHeader

--------------------------------------------------
-- CONTAINER DOS MEMBROS
--------------------------------------------------

local membersContainer =
	Instance.new("Frame")

membersContainer.Name =
	"Members"

membersContainer.Size =
	UDim2.new(
		1,
		-30,
		1,
		-100
	)

membersContainer.Position =
	UDim2.fromOffset(
		15,
		85
	)

membersContainer.BackgroundTransparency = 1

membersContainer.Parent =
	partyFrame

--------------------------------------------------
-- LISTA
--------------------------------------------------

local membersLayout =
	Instance.new("UIListLayout")

membersLayout.Padding =
	UDim.new(
		0,
		8
	)

membersLayout.SortOrder =
	Enum.SortOrder.LayoutOrder

membersLayout.Parent =
	membersContainer

--------------------------------------------------
-- CRIAR SLOT DE JOGADOR
--------------------------------------------------

local function createMemberSlot(index)

	local slot =
		Instance.new("Frame")

	slot.Name =
		"Slot" .. index

	slot.Size =
		UDim2.new(
			1,
			0,
			0,
			58
		)

	slot.BackgroundColor3 =
		COLORS.PanelLight

	slot.BorderSizePixel = 0

	slot.LayoutOrder = index

	slot.Parent =
		membersContainer

	createCorner(
		slot,
		7
	)

	createStroke(
		slot,
		1
	)

	--------------------------------------------------
	-- ÍCONE
	--------------------------------------------------

	local icon =
		Instance.new("Frame")

	icon.Name = "Icon"

	icon.Size =
		UDim2.fromOffset(
			38,
			38
		)

	icon.Position =
		UDim2.fromOffset(
			10,
			10
		)

	icon.BackgroundColor3 =
		Color3.fromRGB(
			47,
			51,
			63
		)

	icon.BorderSizePixel = 0

	icon.Parent = slot

	createCorner(
		icon,
		19
	)

	--------------------------------------------------
	-- NOME
	--------------------------------------------------

	local label =
		Instance.new("TextLabel")

	label.Name =
		"PlayerName"

	label.Size =
		UDim2.new(
			1,
			-75,
			1,
			0
		)

	label.Position =
		UDim2.fromOffset(
			62,
			0
		)

	label.BackgroundTransparency = 1

	label.Text =
		"Empty Slot"

	label.TextColor3 =
		COLORS.SecondaryText

	label.Font =
		Enum.Font.GothamMedium

	label.TextSize = 16

	label.TextXAlignment =
		Enum.TextXAlignment.Left

	label.Parent = slot

	return slot

end

--------------------------------------------------
-- CRIAR OS 4 SLOTS
--------------------------------------------------

local memberSlots = {}

for i = 1, MAX_PARTY_MEMBERS do

	memberSlots[i] =
		createMemberSlot(i)

end

--------------------------------------------------
-- BOTÕES INFERIORES
--------------------------------------------------

local bottomFrame =
	Instance.new("Frame")

bottomFrame.Name =
	"BottomButtons"

bottomFrame.Size =
	UDim2.new(
		1,
		-40,
		0,
		60
	)

bottomFrame.Position =
	UDim2.new(
		0,
		20,
		1,
		-70
	)

bottomFrame.BackgroundTransparency = 1

bottomFrame.Parent =
	mainFrame

--------------------------------------------------
-- LAYOUT DOS BOTÕES
--------------------------------------------------

local bottomLayout =
	Instance.new("UIListLayout")

bottomLayout.FillDirection =
	Enum.FillDirection.Horizontal

bottomLayout.HorizontalAlignment =
	Enum.HorizontalAlignment.Center

bottomLayout.VerticalAlignment =
	Enum.VerticalAlignment.Center

bottomLayout.Padding =
	UDim.new(
		0,
		10
	)

bottomLayout.Parent =
	bottomFrame

--------------------------------------------------
-- CREATE PARTY
--------------------------------------------------

local createPartyButton =
	createButton(

		bottomFrame,

		"Create Party",

		UDim2.fromOffset(
			160,
			48
		)

	)

--------------------------------------------------
-- LEAVE PARTY
--------------------------------------------------

local leavePartyButton =
	createButton(

		bottomFrame,

		"Leave Party",

		UDim2.fromOffset(
			160,
			48
		)

	)

leavePartyButton.BackgroundColor3 =
	COLORS.Red

leavePartyButton.Visible = false

addButtonEffects(

	leavePartyButton,

	COLORS.Red,

	COLORS.RedHover

)

--------------------------------------------------
-- PLAY
--------------------------------------------------

local playButton =
	createButton(

		bottomFrame,

		"PLAY",

		UDim2.fromOffset(
			140,
			48
		)

	)

playButton.BackgroundColor3 =
	COLORS.Green

playButton.Visible = false

addButtonEffects(

	playButton,

	COLORS.Green,

	COLORS.GreenHover

)

--------------------------------------------------
-- CLOSE
--------------------------------------------------

local closeButton =
	createButton(

		bottomFrame,

		"Close",

		UDim2.fromOffset(
			130,
			48
		)

	)

--------------------------------------------------
-- ATUALIZAR MEMBROS
--------------------------------------------------

local function refreshPartyMembers()

	for i = 1, MAX_PARTY_MEMBERS do

		local slot =
			memberSlots[i]

		local playerNameLabel =
			slot:FindFirstChild(
				"PlayerName"
			)

		if partyMembers[i] then

			playerNameLabel.Text =
				partyMembers[i]

			playerNameLabel.TextColor3 =
				COLORS.Text

		else

			playerNameLabel.Text =
				"Empty Slot"

			playerNameLabel.TextColor3 =
				COLORS.SecondaryText

		end

	end

	memberCounter.Text =
		#partyMembers
		..
		"/"
		..
		MAX_PARTY_MEMBERS

end

--------------------------------------------------
-- MOSTRAR BROWSER
--------------------------------------------------

local function showBrowser()

	browserFrame.Visible = true

	partyFrame.Visible = false

	createPartyButton.Visible = true

	leavePartyButton.Visible = false

	playButton.Visible = false

	title.Text = "PARTY"

end

--------------------------------------------------
-- MOSTRAR PARTY
--------------------------------------------------

local function showParty()

	browserFrame.Visible = false

	partyFrame.Visible = true

	createPartyButton.Visible = false

	leavePartyButton.Visible = true

	title.Text = "YOUR PARTY"

	refreshPartyMembers()

	--------------------------------------------------
	-- PLAY APENAS PARA O LÍDER
	--------------------------------------------------

	if currentParty then

		playButton.Visible =
			currentParty.leaderUserId
			==
			player.UserId

	else

		playButton.Visible = false

	end

end

--------------------------------------------------
-- CRIAR PARTY
--------------------------------------------------

local function createParty()

	if partyCreated then
		return
	end

	Remotes.CreateParty:FireServer()

end

--------------------------------------------------
-- SAIR DA PARTY
--------------------------------------------------

local function leaveParty()

	if not partyCreated then
		return
	end

	Remotes.LeaveParty:FireServer()

end

--------------------------------------------------
-- SEARCH
--------------------------------------------------

local searching = false

--------------------------------------------------
-- CRIAR PARTY NA LISTA
--------------------------------------------------

local function createPartyCard(
	partyInfo,
	index
)

	local card =
		Instance.new("Frame")

	card.Name =
		"PartyCard"

	card.Size =
		UDim2.new(
			1,
			-5,
			0,
			68
		)

	card.BackgroundColor3 =
		COLORS.PanelLight

	card.BorderSizePixel = 0

	card.LayoutOrder =
		index

	card.Parent =
		partyList

	createCorner(
		card,
		7
	)

	createStroke(
		card,
		1
	)

	--------------------------------------------------
	-- NOME DA PARTY
	--------------------------------------------------

	local nameLabel =
		Instance.new("TextLabel")

	nameLabel.Size =
		UDim2.new(
			1,
			-160,
			0,
			30
		)

	nameLabel.Position =
		UDim2.fromOffset(
			15,
			7
		)

	nameLabel.BackgroundTransparency = 1

	nameLabel.Text =
		partyInfo.leaderName
		..
		"'s Party"

	nameLabel.TextColor3 =
		COLORS.Text

	nameLabel.Font =
		Enum.Font.GothamBold

	nameLabel.TextSize = 16

	nameLabel.TextXAlignment =
		Enum.TextXAlignment.Left

	nameLabel.Parent =
		card

	--------------------------------------------------
	-- QUANTIDADE DE JOGADORES
	--------------------------------------------------

	local countLabel =
		Instance.new("TextLabel")

	countLabel.Size =
		UDim2.new(
			1,
			-160,
			0,
			20
		)

	countLabel.Position =
		UDim2.fromOffset(
			15,
			38
		)

	countLabel.BackgroundTransparency = 1

	countLabel.Text =
		tostring(
			partyInfo.memberCount
		)
		..
		"/"
		..
		tostring(
			partyInfo.maxPlayers
		)
		..
		" Players"

	countLabel.TextColor3 =
		COLORS.SecondaryText

	countLabel.Font =
		Enum.Font.Gotham

	countLabel.TextSize = 13

	countLabel.TextXAlignment =
		Enum.TextXAlignment.Left

	countLabel.Parent =
		card

	--------------------------------------------------
	-- JOIN
	--------------------------------------------------

	local joinButton =
		createButton(

			card,

			"JOIN",

			UDim2.fromOffset(
				110,
				42
			)

		)

	joinButton.AnchorPoint =
		Vector2.new(
			1,
			0.5
		)

	joinButton.Position =
		UDim2.new(
			1,
			-12,
			0.5,
			0
		)

	--------------------------------------------------
	-- PARTY CHEIA
	--------------------------------------------------

	if partyInfo.memberCount
		>= partyInfo.maxPlayers then

		joinButton.Text =
			"FULL"

		joinButton.Active =
			false

		joinButton.BackgroundColor3 =
			Color3.fromRGB(
				60,
				60,
				65
			)

		return

	end

	--------------------------------------------------
	-- ENTRAR NA PARTY
	--------------------------------------------------

	joinButton.MouseButton1Click:Connect(
		function()

			joinButton.Text =
				"JOINING..."

			joinButton.Active =
				false

			print(
				"Tentando entrar na party:",
				partyInfo.partyId
			)

			Remotes.JoinParty:FireServer(
				partyInfo.partyId
			)

		end
	)

end

--------------------------------------------------
-- BUSCAR PARTIES
--------------------------------------------------

local function searchParties()

	if searching then
		return
	end

	searching = true

	searchButton.Text =
		"Searching..."

	--------------------------------------------------
	-- LIMPA CARDS ANTIGOS
	--------------------------------------------------

	for _, child in ipairs(
		partyList:GetChildren()
	) do

		if child.Name == "PartyCard" then

			child:Destroy()

		end

	end

	emptyLabel.Visible = true

	emptyLabel.Text =
		"Procurando parties..."

	--------------------------------------------------
	-- PEDE AS PARTIES AO SERVIDOR
	--
	-- Remotes.GetPublicParties é buscado aqui, na hora do uso.
	-- Como Remotes.luau busca cada remote de forma preguiçosa,
	-- isso não trava a criação do botão PARTY caso o servidor
	-- ainda esteja inicializando -- só essa busca específica
	-- espera, e só quando o jogador realmente clica em Search.
	--------------------------------------------------

	local success, parties =
		pcall(function()

			return Remotes.GetPublicParties:InvokeServer()

		end)

	--------------------------------------------------
	-- ERRO
	--------------------------------------------------

	if not success then

		warn(
			"Erro ao buscar parties:",
			parties
		)

		emptyLabel.Visible = true

		emptyLabel.Text =
			"Erro ao procurar parties"

		searchButton.Text =
			"Search"

		searching = false

		return

	end

	--------------------------------------------------
	-- PROTEÇÃO CONTRA RESPOSTA INVÁLIDA
	--------------------------------------------------

	if type(parties) ~= "table" then

		warn(
			"O servidor retornou uma lista de parties inválida."
		)

		emptyLabel.Visible = true

		emptyLabel.Text =
			"Erro ao carregar parties"

		searchButton.Text =
			"Search"

		searching = false

		return

	end

	--------------------------------------------------
	-- NENHUMA PARTY
	--------------------------------------------------

	if #parties == 0 then

		emptyLabel.Visible = true

		emptyLabel.Text =
			"Nenhuma party encontrada"

	else

		emptyLabel.Visible = false

		--------------------------------------------------
		-- CRIA AS PARTIES
		--------------------------------------------------

		for index, partyInfo in ipairs(
			parties
		) do

			createPartyCard(
				partyInfo,
				index
			)

		end

	end

	searchButton.Text =
		"Search"

	searching = false

end

--------------------------------------------------
-- ATUALIZAÇÕES DA PARTY VINDAS DO SERVIDOR
--------------------------------------------------

Remotes.PartyUpdated.OnClientEvent:Connect(
	function(partyData)

		--------------------------------------------------
		-- JOGADOR NÃO ESTÁ MAIS EM UMA PARTY
		--------------------------------------------------

		if not partyData then

			print(
				"Você não está mais em uma Party."
			)

			currentParty = nil

			partyCreated = false

			table.clear(
				partyMembers
			)

			showBrowser()

			--------------------------------------------------
			-- ATUALIZA LISTA SE O MENU ESTIVER ABERTO
			--------------------------------------------------

			if overlay.Visible then

				searchParties()

			end

			return

		end

		--------------------------------------------------
		-- GUARDA PARTY RECEBIDA DO SERVIDOR
		--------------------------------------------------

		currentParty =
			partyData

		partyCreated =
			true

		table.clear(
			partyMembers
		)

		--------------------------------------------------
		-- CONVERTE USER IDS PARA NOMES
		--------------------------------------------------

		for _, userId in ipairs(
			partyData.memberUserIds or {}
		) do

			local memberPlayer =
				Players:GetPlayerByUserId(
					userId
				)

			if memberPlayer then

				table.insert(
					partyMembers,
					memberPlayer.DisplayName
				)

			else

				table.insert(
					partyMembers,
					"Player"
				)

			end

		end

		print(
			"Party atualizada:",
			partyData.partyId,
			#partyMembers .. "/" .. MAX_PARTY_MEMBERS
		)

		--------------------------------------------------
		-- MOSTRA PARTY
		--------------------------------------------------

		showParty()

	end
)

--------------------------------------------------
-- ABRIR PARTY UI
--------------------------------------------------

local function openUI()

	overlay.Visible = true

	if partyCreated then

		showParty()

	else

		showBrowser()

		searchParties()

	end

end

--------------------------------------------------
-- FECHAR PARTY UI
--------------------------------------------------

local function closeUI()

	overlay.Visible = false

end

--------------------------------------------------
-- BOTÃO PRINCIPAL DA HUD
--------------------------------------------------

openPartyButton.MouseButton1Click:Connect(
	openUI
)

--------------------------------------------------
-- CREATE PARTY
--------------------------------------------------

createPartyButton.MouseButton1Click:Connect(
	createParty
)

--------------------------------------------------
-- LEAVE PARTY
--------------------------------------------------

leavePartyButton.MouseButton1Click:Connect(
	leaveParty
)
--------------------------------------------------
-- PLAY
--------------------------------------------------

local function playParty()

	if not currentParty then

		warn(
			"Você não está em uma Party."
		)

		return

	end

	--------------------------------------------------
	-- APENAS O LÍDER
	--------------------------------------------------

	if currentParty.leaderUserId
		~= player.UserId then

		warn(
			"Apenas o líder pode iniciar."
		)

		return

	end

	print(
		"Iniciando partida..."
	)

	Remotes.StartGame:FireServer()

end

playButton.MouseButton1Click:Connect(
	playParty
)

--------------------------------------------------
-- SEARCH
--------------------------------------------------

searchButton.MouseButton1Click:Connect(
	searchParties
)

--------------------------------------------------
-- CLOSE
--------------------------------------------------

closeButton.MouseButton1Click:Connect(
	closeUI
)

--------------------------------------------------
-- INICIALIZAÇÃO
--------------------------------------------------

showBrowser()

overlay.Visible = false

print("[PartyUI] Interface inicializada com sucesso.")