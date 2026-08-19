--!nocheck

--- Runs every shipped example. An example that no longer builds is a broken
--- promise in the README, and compiling one proves only that it parses.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Shim = require("./Shim")

local Lume = Shim.load("./src", "Lume")

--// examples reach for ReplicatedStorage.Packages.Lume, which is where Wally
--// puts it in a real place
local packages = Shim.Instance.new("Folder")

packages.Name = "Packages"
packages.Parent = Shim.services.ReplicatedStorage

local tree = Shim.services.ReplicatedStorage:FindFirstChild("Lume")

if tree then
	tree.Parent = packages
end

local failed = 0

for _, entry in fs.readDir("examples") do
	if not entry:match("%.luau$") then
		continue
	end

	table.clear(Shim.warnings)

	local name = entry:match("^(.*)%.client%.luau$") or entry
	local chunk = Shim.compile(`examples/{entry}`, name)
	local thread = coroutine.create(chunk)
	local ok, err = coroutine.resume(thread)

	for _ = 1, 240 do
		if coroutine.status(thread) == "dead" then
			break
		end

		Shim.step(1 / 30)
	end

	if not ok then
		failed += 1

		print(`  FAIL  {name} — {err}`)
	elseif #Shim.warnings > 0 then
		failed += 1

		print(`  FAIL  {name} warned: {table.concat(Shim.warnings, " | ")}`)
	else
		print(`  ok    {name}`)
	end
end

if failed > 0 then
	print(`Examples: {failed} failed`)

	process.exit(1)
end

print("Examples: all clean")
