local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local FONT = Enum.Font.FredokaOne
local FADE_IN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local DIM_TRANSPARENCY = 0.45

local COLORS = {
	Text = Color3.new(1, 1, 1),
	TextStroke = Color3.fromRGB(20, 15, 15),
	Dim = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(22, 22, 26),
	Gold = Color3.fromRGB(215, 150, 45),
	Banner = Color3.fromRGB(70, 70, 70),
	KeyBack = Color3.fromRGB(70, 70, 75),
	KeyBorder = Color3.fromRGB(35, 35, 38),
	Locked = Color3.fromRGB(60, 60, 65),
	LockedBorder = Color3.fromRGB(95, 95, 100),
	LockedText = Color3.fromRGB(175, 175, 180),
	Waiting = Color3.fromRGB(200, 200, 205),
}

-- Cores das opções na ordem (mesma paleta dos botões Fight/Itens/Focus) e as teclas 1 a 4
local OPTION_STYLES = {
	{ fill = Color3.fromRGB(150, 10, 10), border = Color3.fromRGB(215, 20, 20) },
	{ fill = Color3.fromRGB(205, 165, 10), border = Color3.fromRGB(235, 195, 25) },
	{ fill = Color3.fromRGB(10, 80, 205), border = Color3.fromRGB(25, 105, 235) },
	{ fill = Color3.fromRGB(30, 130, 20), border = Color3.fromRGB(80, 190, 45) },
}
local OPTION_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

-- Helpers visuais: cantos, contornos e texto com contorno grosso (mesmo padrão da HUD de batalha)
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

local function createText(parent: Instance, props): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = props.Text or ""
	label.TextColor3 = props.Color or COLORS.Text
	label.TextSize = props.TextSize or 22
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

-- Estrutura da tela: CanvasGroup para fazer fade de tudo junto, fundo escurecido e conteúdo com leve "pop"
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EventUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 200
screenGui.Enabled = false
screenGui.Parent = playerGui

local root = Instance.new("CanvasGroup")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.GroupTransparency = 1
root.Parent = screenGui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = COLORS.Dim
dim.BackgroundTransparency = DIM_TRANSPARENCY
dim.BorderSizePixel = 0
dim.Parent = root

local content = Instance.new("Frame")
content.Size = UDim2.fromScale(1, 1)
content.BackgroundTransparency = 1
content.Parent = root

local contentScale = Instance.new("UIScale")
contentScale.Parent = content

-- Faixa de título com fade nas duas pontas, no estilo do banner de turno
local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 1)
banner.Position = UDim2.new(0.5, 0, 0.4, -100)
banner.Size = UDim2.fromOffset(480, 52)
banner.BackgroundColor3 = COLORS.Banner
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = content

local bannerFade = Instance.new("UIGradient")
bannerFade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.15),
	NumberSequenceKeypoint.new(0.8, 0.15),
	NumberSequenceKeypoint.new(1, 1),
})
bannerFade.Parent = banner

local bannerLabel = createText(banner, { TextSize = 34, StrokeThickness = 2.5 })

-- Caixa do texto do evento: fundo escuro, borda dourada e texto que se ajusta ao tamanho
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.4)
panel.Size = UDim2.new(0.55, 0, 0, 170)
panel.BackgroundColor3 = COLORS.Panel
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = content
addCorner(panel, 12)
addStroke(panel, COLORS.Gold, 3)

local panelLimit = Instance.new("UISizeConstraint")
panelLimit.MinSize = Vector2.new(420, 170)
panelLimit.MaxSize = Vector2.new(780, 170)
panelLimit.Parent = panel

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingLeft = UDim.new(0, 22)
panelPadding.PaddingRight = UDim.new(0, 22)
panelPadding.PaddingTop = UDim.new(0, 14)
panelPadding.PaddingBottom = UDim.new(0, 14)
panelPadding.Parent = panel

local textLabel = createText(panel, { MaxTextSize = 26 })

-- Linha das opções e o aviso de espera para quem não é o líder
local optionsRow = Instance.new("Frame")
optionsRow.AnchorPoint = Vector2.new(0.5, 0)
optionsRow.Position = UDim2.new(0.5, 0, 0.4, 110)
optionsRow.Size = UDim2.fromOffset(1100, 68)
optionsRow.BackgroundTransparency = 1
optionsRow.Parent = content

local optionsLayout = Instance.new("UIListLayout")
optionsLayout.FillDirection = Enum.FillDirection.Horizontal
optionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
optionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
optionsLayout.Padding = UDim.new(0, 18)
optionsLayout.Parent = optionsRow

local waitingLabel = createText(content, {
	TextSize = 20,
	Color = COLORS.Waiting,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.4, 196),
	Size = UDim2.fromOffset(600, 30),
})
waitingLabel.Visible = false

-- Cada tela recebe um id: o servidor fecha uma tela e abre a próxima quase junto,
-- então o fechamento atrasado só limpa se ainda for dono da tela atual
local promptId = 0
local answered = false
local currentCanChoose = false
local optionButtons = {}

local function clearOptions()
	for _, option in optionButtons do
		option.Button:Destroy()
	end
	table.clear(optionButtons)
end

-- Envia a escolha uma única vez, destaca o botão escolhido e apaga os outros
local function choose(index: number)
	local option = optionButtons[index]
	if answered or not currentCanChoose or not option then
		return
	end

	answered = true
	TweenService:Create(option.Scale, POP, { Scale = 1.08 }):Play()

	for otherIndex, other in optionButtons do
		if otherIndex ~= index then
			TweenService:Create(other.Button, HOVER, { BackgroundTransparency = 0.5 }):Play()
		end
	end

	Remotes.EventChoice:FireServer(index)
end

-- Botão de opção estilo cartoon com a tecla no canto; bloqueado fica cinza e sem interação
local function createOption(text: string, index: number, canChoose: boolean)
	local style = canChoose and OPTION_STYLES[(index - 1) % #OPTION_STYLES + 1]
		or { fill = COLORS.Locked, border = COLORS.LockedBorder }

	local button = Instance.new("TextButton")
	button.Name = "Option" .. index
	button.Size = UDim2.fromOffset(240, 64)
	button.BackgroundColor3 = style.fill
	button.AutoButtonColor = false
	button.Text = ""
	button.LayoutOrder = index
	button.Active = canChoose
	button.Parent = optionsRow
	addCorner(button, 14)
	addStroke(button, style.border, 4)

	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175))
	shine.Rotation = 90
	shine.Parent = button

	local scale = Instance.new("UIScale")
	scale.Parent = button

	createText(button, {
		Text = text,
		Color = canChoose and COLORS.Text or COLORS.LockedText,
		MaxTextSize = 22,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -34, 1, -12),
		ZIndex = 2,
	})

	if index <= #OPTION_KEYS then
		local keyCap = Instance.new("Frame")
		keyCap.AnchorPoint = Vector2.new(0.5, 0.5)
		keyCap.Position = UDim2.fromOffset(6, 6)
		keyCap.Size = UDim2.fromOffset(28, 28)
		keyCap.BackgroundColor3 = COLORS.KeyBack
		keyCap.ZIndex = 3
		keyCap.Parent = button
		addCorner(keyCap, 6)
		addStroke(keyCap, COLORS.KeyBorder, 2.5)
		createText(keyCap, { Text = tostring(index), TextSize = 17, ZIndex = 4 })
	end

	if canChoose then
		button.MouseEnter:Connect(function()
			if not answered then
				TweenService:Create(scale, HOVER, { Scale = 1.05 }):Play()
			end
		end)
		button.MouseLeave:Connect(function()
			if not answered then
				TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
			end
		end)
		button.MouseButton1Click:Connect(function()
			choose(index)
		end)
	end

	optionButtons[index] = { Button = button, Scale = scale }
end

-- Abre (ou troca) a tela: título, texto, opções e aviso de líder, com fade e "pop"
local function showPrompt(data)
	promptId += 1
	answered = false
	clearOptions()

	local title = type(data.title) == "string" and data.title or ""
	bannerLabel.Text = title
	banner.Visible = title ~= ""
	textLabel.Text = data.text or ""

	currentCanChoose = data.canChoose ~= false
	for index, optionText in ipairs(data.options or {}) do
		createOption(tostring(optionText), index, currentCanChoose)
	end

	waitingLabel.Visible = not currentCanChoose
	waitingLabel.Text = data.leaderName and ("Aguardando " .. data.leaderName .. "...") or "Aguardando o líder..."

	screenGui.Enabled = true
	TweenService:Create(root, FADE_IN, { GroupTransparency = 0 }):Play()
	contentScale.Scale = 0.96
	TweenService:Create(contentScale, POP, { Scale = 1 }):Play()
end

local function hidePrompt()
	promptId += 1
	local id = promptId

	TweenService:Create(root, FADE_OUT, { GroupTransparency = 1 }):Play()

	task.delay(FADE_OUT.Time, function()
		if id ~= promptId then
			return
		end

		screenGui.Enabled = false
		clearOptions()
	end)
end

-- Teclas 1 a 4 escolhem a opção correspondente enquanto a tela está aberta
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not screenGui.Enabled or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	local index = table.find(OPTION_KEYS, input.KeyCode)
	if index then
		choose(index)
	end
end)

Remotes.EventPrompt.OnClientEvent:Connect(function(data)
	if data then
		showPrompt(data)
	else
		hidePrompt()
	end
end)
