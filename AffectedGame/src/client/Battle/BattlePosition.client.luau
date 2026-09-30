-- BattlePosition.client.luau
-- Bloqueia os controles do jogador durante a batalha.

local ContextActionService =
	game:GetService("ContextActionService")

local function blockMovement()
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(
	"BattleBlockMovement",
	blockMovement,
	false,
	Enum.ContextActionPriority.High.Value + 100,

	Enum.PlayerActions.CharacterForward,
	Enum.PlayerActions.CharacterBackward,
	Enum.PlayerActions.CharacterLeft,
	Enum.PlayerActions.CharacterRight,
	Enum.PlayerActions.CharacterJump
)

print("[BattlePosition] Movimento bloqueado.")