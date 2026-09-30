local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local cameraPart = workspace:WaitForChild("BattleCamera")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function setBattleCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cameraPart.CFrame
end

setBattleCamera()

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	setBattleCamera()
end)

RunService:BindToRenderStep(
	"BattleCamera",
	Enum.RenderPriority.Camera.Value + 1,
	function()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cameraPart.CFrame
	end
)
