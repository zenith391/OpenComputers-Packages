local Goomba = {}

function Goomba:init()
	self.vx = -1
end

function Goomba:onHorizontalCollision()
	self.vx = -self.vx
end

function Goomba:update()
	
end

return Goomba
