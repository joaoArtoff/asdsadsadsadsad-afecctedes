local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local FONT = Enum.Font.FredokaOne
local SHOW_TIME = 3.5
local MAX_WIDTH = 700
local FADE = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Transparências da faixa visível; escondida tudo vai para 1
local VISIBLE = { Back = 0.55, Text = 0, Stroke = 0.3 }

local COLORS = {
	Back = Color3.fromRGB(10, 10, 12),
	Text = Color3.new(1, 1, 1),
	Private = Color3.fromRGB(255, 120, 120),
	Stroke = Color3.fromRGB(20, 15, 15),
}

-- Faixa escura semitransparente no topo central, que cresce conforme o tamanho do texto
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BattleLogUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local bar = Instance.new("Frame")
bar.Name = "LogBar"
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 14)
bar.Size = UDim2.fromOffset(0, 34)
bar.AutomaticSize = Enum.AutomaticSize.X
bar.BackgroundColor3 = COLORS.Back
bar.BackgroundTransparency = 1
bar.BorderSizePixel = 0
bar.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = bar

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 18)
padding.PaddingRight = UDim.new(0, 18)
padding.Parent = bar

local scale = Instance.new("UIScale")
scale.Parent = bar

local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(0, 1)
label.AutomaticSize = Enum.AutomaticSize.X
label.Font = FONT
label.TextSize = 19
label.TextColor3 = COLORS.Text
label.TextTransparency = 1
label.TextTruncate = Enum.TextTruncate.AtEnd
label.Text = ""
label.Parent = bar

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(MAX_WIDTH, math.huge)
sizeLimit.Parent = label

local stroke = Instance.new("UIStroke")
stroke.Color = COLORS.Stroke
stroke.Thickness = 1.5
stroke.Transparency = 1
stroke.Parent = label

local function fadeTo(back: number, text: number, strokeValue: number)
	TweenService:Create(bar, FADE, { BackgroundTransparency = back }):Play()
	TweenService:Create(label, FADE, { TextTransparency = text }):Play()
	TweenService:Create(stroke, FADE, { Transparency = strokeValue }):Play()
end

-- Mostra uma mensagem com um pequeno "pop"; cada nova mensagem reinicia o tempo até sumir
local showToken = 0

local function showMessage(text: string, isPrivate: boolean?)
	if type(text) ~= "string" or text == "" then
		return
	end

	showToken += 1
	local token = showToken

	label.Text = text
	label.TextColor3 = isPrivate and COLORS.Private or COLORS.Text

	scale.Scale = 0.9
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
	fadeTo(VISIBLE.Back, VISIBLE.Text, VISIBLE.Stroke)

	task.delay(SHOW_TIME, function()
		if token == showToken then
			fadeTo(1, 1, 1)
		end
	end)
end

Remotes.BattleLog.OnClientEvent:Connect(showMessage)
