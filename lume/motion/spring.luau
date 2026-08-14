--!strict

--[[
	@name spring
	@module lume/motion/spring

	Semi-implicit Euler solver, substepped so a dropped frame cannot make a
	stiff spring explode. Springs are the default for anything retargetable
	(layout, drag release, reveal) because the target can change mid-flight
	without a visible restart.
]]

--// locals
local MaxStep = 1 / 240

--// public api
local Spring = {}
Spring.__index = Spring

function Spring.new(position: number, stiffness: number, damping: number)
	return setmetatable({
		stiffness = stiffness,
		damping = damping,

		position = position,
		velocity = 0,
		target = position,
	}, Spring)
end

function Spring.retarget(self, target: number)
	self.target = target
end

function Spring.tune(self, stiffness: number, damping: number)
	self.stiffness = stiffness
	self.damping = damping
end

function Spring.step(self, delta: number): number
	local remaining = math.min(delta, 0.1)

	while remaining > 0 do
		local step = math.min(remaining, MaxStep)

		local force = (self.target - self.position) * self.stiffness
		local drag = self.velocity * self.damping

		self.velocity += (force - drag) * step
		self.position += self.velocity * step

		remaining -= step
	end

	return self.position
end

function Spring.settled(self, epsilon: number?): boolean
	local tolerance = epsilon or 0.05

	return math.abs(self.target - self.position) < tolerance and math.abs(self.velocity) < tolerance * 4
end

function Spring.snap(self, position: number)
	self.position = position
	self.target = position
	self.velocity = 0
end

return Spring
