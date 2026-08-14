--!strict

--[[
	@name motion
	@module lume/motion

	One heartbeat driver for the whole app. Tracks are keyed by
	instance + property, so retargeting a property cancels only that property
	and inherits its current velocity: nothing ever restarts from a standstill.
]]

--// imports
local Imports = {
	RunService = game:GetService("RunService"),

	Easing = require("./easing"),
	Signal = require("../core/signal"),
	Spring = require("./spring"),
	Lerp = require("./lerp"),
}

--// locals
local tracks: { [Instance]: { [string]: any } } = {}
local connection: RBXScriptConnection? = nil
local activeCount = 0

local function readSpec(app, spec)
	if type(spec) == "string" then
		return app.theme:spec(spec)
	end

	if type(spec) == "table" then
		return spec
	end

	return app.theme.motion.enter
end

local function drop(instance: Instance, property: string)
	local bucket = tracks[instance]

	if not bucket or not bucket[property] then
		return
	end

	bucket[property] = nil
	activeCount -= 1

	if next(bucket) == nil then
		tracks[instance] = nil
	end
end

local function stepTrack(track, delta: number): boolean
	local instance = track.instance

	if not instance.Parent and not track.orphanOk then
		return true
	end

	if track.springs then
		local parts = {}
		local settled = true

		for index, spring in track.springs do
			parts[index] = spring:step(delta)

			if not spring:settled(track.epsilon) then
				settled = false
			end
		end

		if settled then
			(instance :: any)[track.property] = track.goal

			return true
		end

		(instance :: any)[track.property] = Imports.Lerp.rebuild(track.kind, parts)

		return false
	end

	track.elapsed += delta

	local alpha = track.duration <= 0 and 1 or math.clamp(track.elapsed / track.duration, 0, 1)

	;(instance :: any)[track.property] = Imports.Lerp.between(track.from, track.goal, track.easing(alpha))

	return alpha >= 1
end

local function pump(delta: number)
	for instance, bucket in table.clone(tracks) do
		for property, track in table.clone(bucket) do
			if stepTrack(track, delta) then
				drop(instance, property)

				track.done()
			end
		end
	end

	if activeCount == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function ensureDriver()
	if connection then
		return
	end

	connection = Imports.RunService.Heartbeat:Connect(pump)
end

--// animation handle
local Animation = {}
Animation.__index = Animation

function Animation.active(self)
	return self.remaining > 0
end

function Animation.cancel(self)
	for _, entry in self.entries do
		drop(entry.instance, entry.property)
	end

	self.remaining = 0
	self.completed:destroy()
end

function Animation.finish(self)
	for _, entry in self.entries do
		local bucket = tracks[entry.instance]
		local track = bucket and bucket[entry.property]

		if track then
			(entry.instance :: any)[entry.property] = track.goal

			drop(entry.instance, entry.property)
		end
	end

	self.remaining = 0
	self.completed:fire()
end

--// public api
local Motion = {}

Motion.Easing = Imports.Easing
Motion.Spring = Imports.Spring
Motion.Lerp = Imports.Lerp

function Motion.animate(app, instance: Instance, props: { [string]: any }, spec: any?)
	local resolved = readSpec(app, spec)

	local animation = setmetatable({
		completed = Imports.Signal.new(),
		entries = {},
		remaining = 0,
	}, Animation)

	local springy = resolved.stiffness ~= nil

	for property, goal in props do
		local from = (instance :: any)[property]

		if not Imports.Lerp.supports(goal) then
			(instance :: any)[property] = goal
			continue
		end

		local previous = tracks[instance] and tracks[instance][property]

		if previous then
			drop(instance, property)
			previous.done()
		end

		if not springy and (resolved.duration or 0) <= 0 then
			(instance :: any)[property] = goal
			continue
		end

		local track: { [string]: any } = {
			instance = instance,
			property = property,

			kind = typeof(goal),
			from = from,
			goal = goal,

			orphanOk = resolved.orphanOk == true,
			epsilon = resolved.epsilon,
			elapsed = 0,
		}

		if springy then
			local current = Imports.Lerp.components(from)
			local target = Imports.Lerp.components(goal)

			local springs = {}

			for index, value in current do
				local spring = Imports.Spring.new(value, resolved.stiffness, resolved.damping or 24)

				--// inherit velocity from the track we just replaced
				if previous and previous.springs and previous.springs[index] then
					spring.velocity = previous.springs[index].velocity
				end

				spring:retarget(target[index] or value)

				springs[index] = spring
			end

			track.springs = springs
		else
			track.easing = Imports.Easing.resolve(resolved.easing)
			track.duration = resolved.duration or 0.2
		end

		animation.remaining += 1

		track.done = function()
			animation.remaining -= 1

			if animation.remaining <= 0 then
				animation.completed:fire()
			end
		end

		tracks[instance] = tracks[instance] or {}
		tracks[instance][property] = track

		activeCount += 1

		table.insert(animation.entries, { instance = instance, property = property })
	end

	if animation.remaining > 0 then
		ensureDriver()
	else
		task.defer(function()
			animation.completed:fire()
		end)
	end

	return animation
end

function Motion.stop(instance: Instance, property: string?)
	local bucket = tracks[instance]

	if not bucket then
		return
	end

	for key in table.clone(bucket) do
		if property == nil or key == property then
			drop(instance, key)
		end
	end
end

--// sequence: run specs back to back, returns a cancel function
function Motion.sequence(app, steps)
	local cancelled = false
	local index = 0

	local function advance()
		index += 1

		local step = steps[index]

		if cancelled or not step then
			return
		end

		Motion.animate(app, step.instance, step.props, step.spec).completed:once(advance)
	end

	advance()

	return function()
		cancelled = true
	end
end

--// stagger: same props across many instances, offset in time
function Motion.stagger(app, instances: { Instance }, props: { [string]: any }, spec: any?, delay: number)
	for index, instance in instances do
		task.delay((index - 1) * delay, function()
			if instance.Parent then
				Motion.animate(app, instance, props, spec)
			end
		end)
	end
end

return Motion
