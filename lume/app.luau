--!strict

--[[
	@name app
	@module lume/app

	An app is the one piece of shared state: its ScreenGui, theme, root scope,
	measurement cache, focus ring, and key binder. Layers are z-ordered
	full-screen frames so popovers, modals, and tooltips can never be clipped
	by the surface that spawned them.
]]

--// imports
local Imports = {
	Players = game:GetService("Players"),
	Workspace = game:GetService("Workspace"),

	Components = require("./components"),
	Measure = require("./layout/measure"),
	Signal = require("./core/signal"),
	Theme = require("./theme"),
	Scope = require("./core/scope"),
	Focus = require("./input/focus"),
	Keys = require("./input/keys"),
}

--// locals
local LayerOrder = {
	default = 1,
	popover = 10,
	modal = 100,
	tooltip = 1000,
}

local function hostGui(options, scope): LayerCollector
	if options.gui then
		return options.gui
	end

	local player = Imports.Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

	local gui = Instance.new("ScreenGui")

	gui.Name = options.name or "LumeApp"
	gui.IgnoreGuiInset = options.ignoreGuiInset ~= false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = options.displayOrder or 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	gui.Parent = playerGui or Imports.Workspace

	scope:add(gui)

	return gui
end

--// public api
local App = {}
App.__index = App

function App.new(options)
	options = options or {}

	local scope = Imports.Scope.new()

	local self = setmetatable({
		resized = Imports.Signal.new(),

		theme = Imports.Theme.new(options.theme),
		measure = Imports.Measure.new(),
		layers = {},
		scope = scope,
	}, App)

	self.gui = hostGui(options, scope)

	self.focus = Imports.Focus.new(self)
	self.keys = Imports.Keys.new(self)

	scope:add(self.resized)

	local camera = Imports.Workspace.CurrentCamera

	if camera then
		scope:add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self.resized:fire(camera.ViewportSize)
		end))
	end

	return self
end

--// surface: get or create a named layer
function App.surface(self, name: string): Frame
	local existing = self.layers[name]

	if existing then
		return existing
	end

	local layer = Instance.new("Frame")

	layer.BackgroundTransparency = 1
	layer.BorderSizePixel = 0
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = LayerOrder[name] or 1
	layer.Name = "Layer_" .. name
	layer.Parent = self.gui

	self.layers[name] = layer
	self.scope:add(layer)

	return layer
end

function App.restyle(self, overrides)
	self.theme = self.theme:extend(overrides)
	self.measure:flush()

	return self.theme
end

--// component sugar: app:button{...} instead of Button.new(app, {...})
for name, component in Imports.Components do
	local key = string.lower(string.sub(name, 1, 1)) .. string.sub(name, 2)

	if type(component) == "table" and type((component :: any).new) == "function" then
		App[key] = function(self, props)
			return (component :: any).new(self, props or {})
		end
	end
end

function App.destroy(self)
	self.scope:destroy()
	self.layers = {}
end

return App
