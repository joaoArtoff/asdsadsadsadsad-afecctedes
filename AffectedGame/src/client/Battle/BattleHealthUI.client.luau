local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local BAR_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local COLORS = {
	Gold = Color3.fromRGB(215, 150, 45),
	BarBack = Color3.fromRGB(35, 25, 25),
	PortraitBack = Color3.fromRGB(45, 40, 50),
	Health = Color3.fromRGB(205, 15, 15),
	Energy = Color3.fromRGB(15, 120, 235),
	Text = Color3.new(1, 1, 1),
	TextStroke = Color3.fromRGB(25, 20, 20),
	LabelBack = Color3.fromRGB(165, 130, 100),
	Selected = Color3.fromRGB(255, 225, 70),
	Dead = Color3.fromRGB(110, 110, 115),
	Buff = Color3.fromRGB(35, 125, 15),
	BuffBorder = Color3.fromRGB(95, 200, 50),
	Debuff = Color3.fromRGB(135, 5, 5),
	DebuffBorder = Color3.fromRGB(225, 25, 25),
	Banner = Color3.fromRGB(70, 70, 70),
}

-- Medidas do painel em pixels de design; o painel do inimigo é o mesmo, espelhado e reduzido por UIScale
local PANEL = {
	Width = 440,
	Height = 150,
	Portrait = { X = 75, Y = 82, Size = 96 },
	Health = { X = 118, Y = 40, W = 300, H = 40, TextSize = 26 },
	Energy = { X = 128, Y = 88, W = 240, H = 24, TextSize = 18 },
	Label = { X = 132, Y = 118, W = 240, H = 24 },
	Status = { X = 112, Y = 2, Size = 30, Gap = 40, Max = 6 },
	EnemyScale = 0.72,
	EnemyGap = 6,
	Margin = 20,
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BattleHealthUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Helpers visuais: texto com contorno grosso (estilo cartoon), cantos e gradientes de brilho/fade
local function createText(parent: Instance, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = props.Font or FONT
	label.TextSize = props.TextSize or 18
	label.TextColor3 = props.Color or COLORS.Text
	label.TextXAlignment = props.AlignX or Enum.TextXAlignment.Left
	label.TextYAlignment = props.AlignY or Enum.TextYAlignment.Center
	label.Text = props.Text or ""
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.Position = props.Position or UDim2.new()
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.ZIndex = props.ZIndex or 1
	label.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.TextStroke
	stroke.Thickness = props.StrokeThickness or 2
	stroke.Parent = label

	return label
end

local function addCorner(object: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
end

local function addShine(object: GuiObject, rotation: number)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(165, 165, 165))
	gradient.Rotation = rotation
	gradient.Parent = object
end

local function addFade(object: GuiObject, fromLeft: boolean)
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, fromLeft and 0 or 1),
		NumberSequenceKeypoint.new(0.55, 0.25),
		NumberSequenceKeypoint.new(1, fromLeft and 1 or 0),
	})
	gradient.Parent = object
end

-- Forma de seta: retângulo + ponta em losango; direction 1 aponta para a direita e -1 para a esquerda
local function buildArrow(parent: Instance, width: number, height: number, color: Color3, direction: number, zIndex: number): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(width, height)
	holder.ZIndex = zIndex
	holder.Parent = parent

	local body = Instance.new("Frame")
	body.BorderSizePixel = 0
	body.BackgroundColor3 = color
	body.Size = UDim2.fromOffset(width - height / 2, height)
	body.Position = UDim2.fromOffset(direction == 1 and 0 or height / 2, 0)
	body.ZIndex = zIndex
	body.Parent = holder
	addShine(body, 90)

	local side = height / math.sqrt(2)
	local tip = Instance.new("Frame")
	tip.BorderSizePixel = 0
	tip.BackgroundColor3 = color
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Size = UDim2.fromOffset(side, side)
	tip.Position = UDim2.fromOffset(direction == 1 and width - height / 2 or height / 2, height / 2)
	tip.Rotation = 45
	tip.ZIndex = zIndex
	tip.Parent = holder
	addShine(tip, 45)

	return holder
end

-- Posição X espelhada: no painel do inimigo tudo é desenhado a partir da direita
local function mirrorX(x: number, width: number, direction: number): number
	return direction == 1 and x or PANEL.Width - x - width
end

-- Barra em seta com borda dourada; o preenchimento é recortado por um frame que encolhe a partir da ponta
local function createBar(parent: Instance, spec, color: Color3, direction: number)
	local border = 3
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(spec.W + border * 2, spec.H + border * 2)
	root.Position = UDim2.fromOffset(mirrorX(spec.X, spec.W + border * 2, direction), spec.Y)
	root.Parent = parent

	buildArrow(root, spec.W + border * 2, spec.H + border * 2, COLORS.Gold, direction, 2)
	buildArrow(root, spec.W, spec.H, COLORS.BarBack, direction, 3).Position = UDim2.fromOffset(border, border)

	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.AnchorPoint = Vector2.new(direction == 1 and 0 or 1, 0)
	clip.Position = UDim2.fromOffset(direction == 1 and border or border + spec.W, border)
	clip.Size = UDim2.fromOffset(spec.W, spec.H)
	clip.ZIndex = 4
	clip.Parent = root

	local fill = buildArrow(clip, spec.W, spec.H, color, direction, 5)
	fill.AnchorPoint = Vector2.new(direction == 1 and 0 or 1, 0)
	fill.Position = UDim2.fromScale(direction == 1 and 0 or 1, 0)

	local text = createText(root, {
		TextSize = spec.TextSize,
		AlignX = direction == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(direction == 1 and 26 or spec.H / 2, 0),
		Size = UDim2.new(1, -26 - spec.H / 2, 1, 0),
		ZIndex = 6,
		StrokeThickness = 2.5,
	})

	return { Clip = clip, Width = spec.W, Height = spec.H, Text = text }
end

local function setBar(bar, current: number, maximum: number)
	local ratio = maximum > 0 and math.clamp(current / maximum, 0, 1) or 0
	TweenService:Create(bar.Clip, BAR_TWEEN, { Size = UDim2.fromOffset(bar.Width * ratio, bar.Height) }):Play()
	bar.Text.Text = string.format("%d/%d", math.floor(current + 0.5), math.floor(maximum + 0.5))
end

-- Retrato em losango dourado com um ViewportFrame por cima mostrando o busto do personagem
local function createPortrait(parent: Instance, direction: number)
	local spec = PANEL.Portrait
	local centerX = direction == 1 and spec.X or PANEL.Width - spec.X

	local border = Instance.new("Frame")
	border.AnchorPoint = Vector2.new(0.5, 0.5)
	border.Position = UDim2.fromOffset(centerX, spec.Y)
	border.Size = UDim2.fromOffset(spec.Size, spec.Size)
	border.Rotation = 45
	border.BorderSizePixel = 0
	border.BackgroundColor3 = COLORS.Gold
	border.ZIndex = 7
	border.Parent = parent

	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.BorderSizePixel = 0
	inner.BackgroundColor3 = COLORS.PortraitBack
	inner.ZIndex = 8
	inner.Parent = border
	addShine(inner, 0)

	local viewport = Instance.new("ViewportFrame")
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromOffset(centerX, spec.Y - 6)
	viewport.Size = UDim2.fromOffset(spec.Size * 1.3, spec.Size * 1.3)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(190, 190, 200)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.ZIndex = 9
	viewport.Parent = parent

	return { Border = border, Viewport = viewport, Direction = direction }
end

-- Clona o modelo para o retrato (sem scripts/efeitos) e aponta a câmera para o rosto
local function setPortraitModel(portrait, model: Model?)
	local viewport = portrait.Viewport
	viewport:ClearAllChildren()
	if not model or not model.Parent then
		return
	end

	local wasArchivable = model.Archivable
	model.Archivable = true
	local ok, clone = pcall(model.Clone, model)
	model.Archivable = wasArchivable
	if not ok or not clone then
		return
	end

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("Highlight") or descendant:IsA("Sound") or descendant:IsA("ForceField") then
			descendant:Destroy()
		end
	end
	clone.Parent = viewport

	local head = clone:FindFirstChild("Head")
	local focus = head and head:IsA("BasePart") and head.CFrame or clone:GetPivot()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 38
	camera.CFrame = CFrame.lookAt((focus * CFrame.new(-1.1 * portrait.Direction, 0.2, -4.4)).Position, focus.Position - Vector3.new(0, 0.7, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- Cartão de efeito (verde para buff, vermelho para debuff) que segue o mouse ao passar sobre um ícone
local tooltip = Instance.new("Frame")
tooltip.Name = "StatusTooltip"
tooltip.Size = UDim2.fromOffset(360, 82)
tooltip.BorderSizePixel = 0
tooltip.Visible = false
tooltip.ZIndex = 50
tooltip.Parent = screenGui

local tooltipStroke = Instance.new("UIStroke")
tooltipStroke.Thickness = 4
tooltipStroke.Parent = tooltip

local tooltipGradient = Instance.new("UIGradient")
tooltipGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 120))
tooltipGradient.Rotation = 20
tooltipGradient.Parent = tooltip

local tooltipTitleBack = Instance.new("Frame")
tooltipTitleBack.Position = UDim2.fromOffset(-8, 10)
tooltipTitleBack.Size = UDim2.new(1, 0, 0, 30)
tooltipTitleBack.BackgroundTransparency = 0.2
tooltipTitleBack.BorderSizePixel = 0
tooltipTitleBack.ZIndex = 51
tooltipTitleBack.Parent = tooltip
addFade(tooltipTitleBack, true)

local tooltipTitle = createText(tooltip, { TextSize = 24, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -120, 0, 32), ZIndex = 52 })
local tooltipTurns = createText(tooltip, {
	TextSize = 20,
	AlignX = Enum.TextXAlignment.Right,
	Position = UDim2.new(1, -14, 0, 8),
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(110, 32),
	ZIndex = 52,
})
local tooltipText = createText(tooltip, {
	TextSize = 17,
	Position = UDim2.fromOffset(22, 44),
	Size = UDim2.new(1, -36, 0, 30),
	ZIndex = 52,
})
tooltipText.TextWrapped = true

local function moveTooltip()
	local mouse = UserInputService:GetMouseLocation()
	local viewportSize = screenGui.AbsoluteSize
	local x = math.clamp(mouse.X + 18, 8, viewportSize.X - tooltip.AbsoluteSize.X - 8)
	local y = math.clamp(mouse.Y - tooltip.AbsoluteSize.Y - 14, 8, viewportSize.Y - tooltip.AbsoluteSize.Y - 8)
	tooltip.Position = UDim2.fromOffset(x, y)
end

local function showTooltip(effect)
	local isBuff = effect.kind ~= "Debuff"
	tooltip.BackgroundColor3 = isBuff and COLORS.Buff or COLORS.Debuff
	tooltipStroke.Color = isBuff and COLORS.BuffBorder or COLORS.DebuffBorder
	tooltipTitleBack.BackgroundColor3 = isBuff and COLORS.BuffBorder or COLORS.DebuffBorder
	tooltipTitle.Text = effect.name or effect.id or "?"
	tooltipTurns.Text = "Turno: " .. tostring(effect.turns or 0)
	tooltipText.Text = effect.description ~= "" and effect.description or "-"
	tooltip.Visible = true
	moveTooltip()
end

local function hideTooltip()
	tooltip.Visible = false
end

-- Desenha os ícones em losango dos efeitos ativos (letra + turnos restantes) com o cartão no hover
local function renderStatus(hud, json)
	for _, icon in hud.StatusIcons do
		icon:Destroy()
	end
	table.clear(hud.StatusIcons)
	hideTooltip()

	local ok, list = pcall(HttpService.JSONDecode, HttpService, json or "[]")
	if not ok or type(list) ~= "table" then
		return
	end

	local spec = PANEL.Status
	for index, effect in list do
		if index > spec.Max then
			break
		end

		local x = spec.X + (index - 1) * spec.Gap
		local holder = Instance.new("TextButton")
		holder.Text = ""
		holder.AutoButtonColor = false
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(spec.Size + 6, spec.Size + 6)
		holder.Position = UDim2.fromOffset(mirrorX(x, spec.Size + 6, hud.Direction), spec.Y)
		holder.ZIndex = 20
		holder.Parent = hud.Root

		local isBuff = effect.kind ~= "Debuff"
		local diamond = Instance.new("Frame")
		diamond.AnchorPoint = Vector2.new(0.5, 0.5)
		diamond.Position = UDim2.fromScale(0.5, 0.5)
		diamond.Size = UDim2.fromOffset(spec.Size - 6, spec.Size - 6)
		diamond.Rotation = 45
		diamond.BorderSizePixel = 0
		diamond.BackgroundColor3 = isBuff and COLORS.Buff or COLORS.Debuff
		diamond.ZIndex = 20
		diamond.Parent = holder

		local stroke = Instance.new("UIStroke")
		stroke.Color = isBuff and COLORS.BuffBorder or COLORS.DebuffBorder
		stroke.Thickness = 2
		stroke.Parent = diamond

		local letter = (type(effect.icon) == "string" and effect.icon) or string.upper(string.sub(effect.name or effect.id or "?", 1, 1))
		createText(holder, { Text = letter, TextSize = 17, AlignX = Enum.TextXAlignment.Center, ZIndex = 21 })
		createText(holder, {
			Text = tostring(effect.turns or ""),
			TextSize = 12,
			AlignX = Enum.TextXAlignment.Center,
			Position = UDim2.new(1, 0, 0, -4),
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(16, 14),
			ZIndex = 22,
			StrokeThickness = 1.5,
		})

		holder.MouseEnter:Connect(function()
			showTooltip(effect)
		end)
		holder.MouseMoved:Connect(moveTooltip)
		holder.MouseLeave:Connect(hideTooltip)

		table.insert(hud.StatusIcons, holder)
	end
end

-- Monta um painel completo (retrato, vida, energia, "Classe - Lvl", efeitos); inimigos são clicáveis para mirar
local function createPanel(direction: number, clickable: boolean)
	local root = Instance.new(clickable and "TextButton" or "Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(PANEL.Width, PANEL.Height)
	root.AnchorPoint = Vector2.new(direction == 1 and 0 or 1, 1)
	root.Parent = screenGui
	if clickable then
		root.Text = ""
		root.AutoButtonColor = false
	end

	local labelSpec = PANEL.Label
	local labelBack = Instance.new("Frame")
	labelBack.BorderSizePixel = 0
	labelBack.BackgroundColor3 = COLORS.LabelBack
	labelBack.Position = UDim2.fromOffset(mirrorX(labelSpec.X, labelSpec.W, direction), labelSpec.Y)
	labelBack.Size = UDim2.fromOffset(labelSpec.W, labelSpec.H)
	labelBack.ZIndex = 1
	labelBack.Parent = root
	addFade(labelBack, direction == 1)

	local label = createText(labelBack, {
		TextSize = 17,
		AlignX = direction == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(direction == 1 and 12 or 0, 0),
		Size = UDim2.new(1, -12, 1, 0),
		ZIndex = 2,
	})

	local targetTag = createText(root, {
		Text = "▶ ALVO",
		TextSize = 18,
		Color = COLORS.Selected,
		AlignX = direction == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(mirrorX(PANEL.Health.X, 120, direction), 16),
		Size = UDim2.fromOffset(120, 22),
		ZIndex = 20,
	})
	targetTag.Visible = false

	return {
		Root = root,
		Direction = direction,
		Health = createBar(root, PANEL.Health, COLORS.Health, direction),
		Energy = createBar(root, PANEL.Energy, COLORS.Energy, direction),
		Portrait = createPortrait(root, direction),
		Label = label,
		TargetTag = targetTag,
		StatusIcons = {},
		Connections = {},
	}
end

local function clearConnections(hud)
	for _, connection in hud.Connections do
		connection:Disconnect()
	end
	table.clear(hud.Connections)
end

-- Liga um painel a um Model: vida pelo Humanoid, energia/nível/classe/efeitos pelos Attributes que o Character sincroniza
local function bindPanel(hud, model: Model, onRefresh)
	clearConnections(hud)
	hud.Model = model

	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end
	hud.Humanoid = humanoid

	local function refreshHealth()
		setBar(hud.Health, humanoid.Health, humanoid.MaxHealth)
		if onRefresh then
			onRefresh()
		end
	end

	local function refreshEnergy()
		local energy = model:GetAttribute("Energy") or 0
		setBar(hud.Energy, energy, model:GetAttribute("MaxEnergy") or math.max(energy, 1))
	end

	local function refreshLabel()
		local classLabel = model:GetAttribute("ClassLabel") or model.Name
		local level = model:GetAttribute("Level")
		hud.Label.Text = level and string.format("%s - Lvl %d", classLabel, level) or classLabel
	end

	local function refreshStatus()
		renderStatus(hud, model:GetAttribute("StatusEffects"))
	end

	table.insert(hud.Connections, humanoid.HealthChanged:Connect(refreshHealth))
	table.insert(hud.Connections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refreshHealth))
	for _, attribute in { "Energy", "MaxEnergy" } do
		table.insert(hud.Connections, model:GetAttributeChangedSignal(attribute):Connect(refreshEnergy))
	end
	for _, attribute in { "Level", "ClassLabel" } do
		table.insert(hud.Connections, model:GetAttributeChangedSignal(attribute):Connect(refreshLabel))
	end
	table.insert(hud.Connections, model:GetAttributeChangedSignal("StatusEffects"):Connect(refreshStatus))

	refreshHealth()
	refreshEnergy()
	refreshLabel()
	refreshStatus()
	setPortraitModel(hud.Portrait, model)
end

-- Painel do jogador local no canto inferior esquerdo; o retrato é refeito depois que a aparência carrega
local playerHUD = createPanel(1, false)
playerHUD.Root.Position = UDim2.new(0, PANEL.Margin, 1, -PANEL.Margin)

local function connectCharacter(character: Model)
	bindPanel(playerHUD, character)
	task.delay(1.5, function()
		if playerHUD.Model == character then
			setPortraitModel(playerHUD.Portrait, character)
		end
	end)
end

player.CharacterAdded:Connect(connectCharacter)
player.CharacterAppearanceLoaded:Connect(function(character)
	if playerHUD.Model == character then
		setPortraitModel(playerHUD.Portrait, character)
	end
end)
if player.Character then
	task.spawn(connectCharacter, player.Character)
end

-- Estado dos inimigos: um painel por Model, ordem de chegada, alvo selecionado e contorno 3D
local enemyEntries = {}
local orderCounter = 0
local selectedModel: Model? = nil
local highlight: Highlight? = nil

local function isEnemyAlive(model: Model?): boolean
	local entry = model and enemyEntries[model]
	return entry ~= nil and entry.hud.Humanoid ~= nil and entry.hud.Humanoid.Health > 0
end

-- Empilha os painéis dos inimigos no canto inferior direito, o primeiro inimigo em cima
local function layoutEnemies()
	local ordered = {}
	for _, entry in enemyEntries do
		table.insert(ordered, entry)
	end
	table.sort(ordered, function(a, b) return a.order < b.order end)

	local step = PANEL.Height * PANEL.EnemyScale + PANEL.EnemyGap
	for index, entry in ordered do
		local offset = (#ordered - index) * step
		entry.hud.Root.Position = UDim2.new(1, -PANEL.Margin, 1, -PANEL.Margin - offset)
	end
end

-- Marca o alvo: borda amarela no retrato, tag "ALVO", contorno no modelo 3D e atributo local lido pela BattleUI
local function selectTarget(model: Model?)
	if model and not isEnemyAlive(model) then
		return
	end

	selectedModel = model
	player:SetAttribute("SelectedTarget", model and model.Name or nil)

	for enemyModel, entry in enemyEntries do
		local selected = enemyModel == model
		entry.hud.TargetTag.Visible = selected
		entry.hud.Portrait.Border.BackgroundColor3 = selected and COLORS.Selected
			or (isEnemyAlive(enemyModel) and COLORS.Gold or COLORS.Dead)
	end

	if not model then
		if highlight then
			highlight.Enabled = false
		end
		return
	end

	if not highlight or not highlight.Parent then
		highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = COLORS.Selected
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	end
	highlight.Parent = model
	highlight.Enabled = true
end

-- Garante um alvo válido: se o atual morreu ou sumiu, pega o primeiro inimigo vivo
local function ensureTarget()
	if isEnemyAlive(selectedModel) then
		return
	end

	local best = nil
	for model, entry in enemyEntries do
		if isEnemyAlive(model) and (not best or entry.order < enemyEntries[best].order) then
			best = model
		end
	end

	selectTarget(best)
end

-- Visual de inimigo derrotado: retrato acinzentado e texto "Derrotado"
local function refreshEnemyState(model: Model)
	local entry = enemyEntries[model]
	if not entry then
		return
	end

	local alive = isEnemyAlive(model)
	entry.hud.Portrait.Viewport.ImageColor3 = alive and Color3.new(1, 1, 1) or COLORS.Dead
	entry.hud.Portrait.Viewport.ImageTransparency = alive and 0 or 0.35
	if not alive then
		entry.hud.Label.Text = model.Name .. " - Derrotado"
		entry.hud.Portrait.Border.BackgroundColor3 = COLORS.Dead
	end

	ensureTarget()
end

local function addEnemy(model: Instance)
	if not model:IsA("Model") or enemyEntries[model] then
		return
	end

	orderCounter += 1
	local hud = createPanel(-1, true)
	local scale = Instance.new("UIScale")
	scale.Scale = PANEL.EnemyScale
	scale.Parent = hud.Root

	local entry = { hud = hud, order = orderCounter }
	enemyEntries[model] = entry
	layoutEnemies()

	;(hud.Root :: TextButton).MouseButton1Click:Connect(function()
		selectTarget(model)
	end)

	bindPanel(hud, model, function()
		refreshEnemyState(model)
	end)

	table.insert(hud.Connections, model:GetPropertyChangedSignal("Name"):Connect(function()
		if selectedModel == model then
			player:SetAttribute("SelectedTarget", model.Name)
		end
	end))

	ensureTarget()
end

local function removeEnemy(model: Instance)
	local entry = enemyEntries[model]
	if not entry then
		return
	end

	clearConnections(entry.hud)
	entry.hud.Root:Destroy()
	enemyEntries[model] = nil
	hideTooltip()

	if selectedModel == model then
		selectedModel = nil
	end

	layoutEnemies()
	ensureTarget()
end

-- Clique (ou toque) direto no modelo 3D do inimigo também escolhe o alvo
local function setupWorldClick(enemiesFolder: Folder)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { enemiesFolder }

	UserInputService.InputBegan:Connect(function(input, processed)
		local inputType = input.UserInputType
		if processed or (inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch) then
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		local model = hit and hit.Instance
		while model and model.Parent ~= enemiesFolder do
			model = model.Parent
		end

		if model and enemyEntries[model] then
			selectTarget(model :: Model)
		end
	end)
end

task.spawn(function()
	local enemiesFolder = Workspace:WaitForChild("Enemies") :: Folder

	for _, model in enemiesFolder:GetChildren() do
		task.spawn(addEnemy, model)
	end

	enemiesFolder.ChildAdded:Connect(addEnemy)
	enemiesFolder.ChildRemoved:Connect(removeEnemy)
	setupWorldClick(enemiesFolder)
end)

-- Banner do canto superior esquerdo: "Turno N" e "Área - cena/total", lidos dos Attributes do Workspace
local function createBanner(y: number, height: number, width: number, textSize: number)
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = COLORS.Banner
	frame.Position = UDim2.fromOffset(PANEL.Margin, y)
	frame.Size = UDim2.fromOffset(width, height)
	frame.Visible = false
	frame.Parent = screenGui
	addFade(frame, true)

	local label = createText(frame, {
		TextSize = textSize,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -14, 1, 0),
		StrokeThickness = 2.5,
	})

	return frame, label
end

local roundBanner, roundLabel = createBanner(64, 46, 320, 32)
local areaBanner, areaLabel = createBanner(120, 28, 260, 20)

local function refreshBanners()
	local round = Workspace:GetAttribute("BattleRound")
	local area = Workspace:GetAttribute("AreaName")
	local progress = Workspace:GetAttribute("AreaProgress")

	roundBanner.Visible = round ~= nil
	roundLabel.Text = "Turno " .. tostring(round or "")

	areaBanner.Visible = area ~= nil
	areaLabel.Text = progress and string.format("%s - %s", tostring(area), progress) or tostring(area or "")
end

for _, attribute in { "BattleRound", "AreaName", "AreaProgress" } do
	Workspace:GetAttributeChangedSignal(attribute):Connect(refreshBanners)
end
refreshBanners()
