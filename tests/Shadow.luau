--!nocheck

--- No element may carry a field named after a method it inherits.
---
--- An instance field shadows its metatable, so a Toggle with a boolean field
--- called `on` makes `toggle:on("changed", fn)` read the boolean and fail with
--- *attempt to call a boolean value* — which is what `onChanged` does
--- internally, so the failure surfaces nowhere near the field that caused it.
---
--- This has now bitten four times: Container.Open, Field.value, Notice.OnShow
--- in Flare, and Toggle.on. It is mechanical, so it should be checked
--- mechanically rather than remembered.

local process = require("@lune/process")

local Shim = require("./Shim")

local Lume = Shim.load("./src", "Lume")

local app = Lume.app({ name = "Test" })

local passed, failed = 0, 0

--- Every method reachable through a class's metatable chain.
local function methods(class: any): { [string]: boolean }
	local found: { [string]: boolean } = {}
	local seen: { [any]: boolean } = {}
	local current = class

	while type(current) == "table" and not seen[current] do
		seen[current] = true

		for key, value in current do
			if type(value) == "function" and key ~= "__index" then
				found[key] = true
			end
		end

		local meta = getmetatable(current)

		current = if type(meta) == "table" then rawget(meta, "__index") else nil
	end

	return found
end

for name, class in Lume.Elements do
	if name == "Element" or type(class) ~= "table" or type(class.new) ~= "function" then
		continue
	end

	local ok, element = pcall(class.new, app)

	if not ok then
		failed += 1

		print(`  FAIL  {name} could not be constructed — {element}`)

		continue
	end

	local reachable = methods(class)
	local collisions = {}

	for key in element do
		if reachable[key] then
			table.insert(collisions, key)
		end
	end

	if #collisions > 0 then
		failed += 1

		print(`  FAIL  {name} has fields shadowing its methods: {table.concat(collisions, ", ")}`)
	else
		passed += 1
	end
end

print(`Shadow: {passed} elements clean, {failed} with collisions`)

if failed > 0 then
	process.exit(1)
end
