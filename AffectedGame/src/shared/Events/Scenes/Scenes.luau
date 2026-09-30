local Event = require(script.Parent.Parent.Event)

local Scene = {}
Scene.__index = Scene

setmetatable(Scene, {
	__index = Event
})

function Scene.new(sceneType)
	
	local self = Event.new("Scene")

	setmetatable(self, Scene)

	self.sceneType = sceneType or "Unknown"

	return self
end

return Scene