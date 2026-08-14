--!strict

--[[
	@name components
	@module lume/components
]]

return table.freeze({
	Surface = require("./surface"),
	Window = require("./window"),
	Modal = require("./modal"),

	Button = require("./button"),
	Toggle = require("./toggle"),
	Slider = require("./slider"),
	Select = require("./select"),

	Field = require("./field"),
	Chips = require("./chips"),
	Suggest = require("./suggest"),

	Tabs = require("./tabs"),
	Tooltip = require("./tooltip"),
	List = require("./list"),
})
