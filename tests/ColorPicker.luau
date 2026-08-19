--!nocheck

--- The colour picker. Mostly this is about the state being HSV rather than a
--- Color3 — every check below that involves black or white exists because the
--- RGB version of this element loses information the user never gave away.

local process = require("@lune/process")

local Shim = require("./Shim")

local Lume = Shim.load("./src", "Lume")

local passed, failed = 0, 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
	else
		failed += 1

		print(`  FAIL  {name}{if detail then ` — {detail}` else ""}`)
	end
end

local function near(a: number, b: number, slack: number?): boolean
	return math.abs(a - b) <= (slack or 0.02)
end

local app = Lume.app({ name = "Test" })
local panel = app:panel("window")

local picker = panel:colorPicker("Trail colour")

panel:open()
Shim.step()

local square = picker.refs.square
local rail = picker.refs.rail

--// the shim lays nothing out, so the geometry the drag maths reads has to be
--// stated rather than measured
square.AbsolutePosition = Shim.Vector2.new(100, 200)
square.AbsoluteSize = Shim.Vector2.new(200, 120)
rail.AbsolutePosition = Shim.Vector2.new(100, 340)
rail.AbsoluteSize = Shim.Vector2.new(200, 12)

local changed = {}
local committed = {}

picker:onChanged(function(color)
	table.insert(changed, color)
end)

picker:onCommitted(function(color)
	table.insert(committed, color)
end)

local function press(target, x: number, y: number)
	target.InputBegan:Fire({
		UserInputType = Shim.Enum.UserInputType.MouseButton1,
		Position = Shim.Vector2.new(x, y),
	})
end

local function move(x: number, y: number)
	Shim.services.UserInputService.InputChanged:Fire({
		UserInputType = Shim.Enum.UserInputType.MouseMovement,
		Position = Shim.Vector2.new(x, y),
	})
end

local function release()
	Shim.services.UserInputService.InputEnded:Fire({
		UserInputType = Shim.Enum.UserInputType.MouseButton1,
		Position = Shim.Vector2.new(0, 0),
	})
end

--// defaults -------------------------------------------------------------------
check("starts at red", picker:hex() == "#FF0000", picker:hex())
check("the label shows", picker.refs.label.Text == "Trail colour" and picker.refs.label.Visible)

--// the hue rail ---------------------------------------------------------------
press(rail, 200, 346)
release()

check("dragging the rail moves the hue", near(picker.hue, 0.5, 0.01), `{picker.hue}`)
check("half way along the rail is cyan", picker:hex() == "#00FFFF", picker:hex())
check("dragging fires changed", #changed == 1, `{#changed}`)
check("releasing fires committed once", #committed == 1, `{#committed}`)

--// the square -----------------------------------------------------------------
press(square, 300, 200)

check("top right is full saturation and value", picker:hex() == "#00FFFF", picker:hex())

move(100, 200)

check("the left edge is white", picker:hex() == "#FFFFFF", picker:hex())
check("saturation went to zero", near(picker.saturation, 0), `{picker.saturation}`)

move(300, 320)

check("the bottom is black", picker:hex() == "#000000", picker:hex())

--// this is the whole reason the state is HSV: at black there is no hue left in
--// the Color3 to read back, so an RGB picker would have forgotten cyan
check("black keeps the hue", near(picker.hue, 0.5, 0.01), `{picker.hue}`)
check("and the square stays cyan", picker.refs.square.BackgroundColor3 == Lume.Elements.ColorPicker.value({
	hue = 0.5,
	saturation = 1,
	brightness = 1,
}))

move(300, 200)

check("dragging back out returns to cyan", picker:hex() == "#00FFFF", picker:hex())

release()

check("one committed per release", #committed == 2, `{#committed}`)
check("changed fired for every move", #changed >= 5, `{#changed}`)

--// dragging past the edges ------------------------------------------------------
press(square, 9999, -9999)
release()

check("a drag past the corner clamps", picker.saturation == 1 and picker.brightness == 1)

--// the hex field -----------------------------------------------------------------
local hex = picker.refs.hex

check("the field shows the colour", hex.Text == picker:hex(), hex.Text)

hex.Focused:Fire()
hex.Text = "#7EAAFF"
hex.FocusLost:Fire()

check("typing a hex sets the colour", picker:hex() == "#7EAAFF", picker:hex())
check("and fires committed", #committed == 4, `{#committed}`)

hex.Focused:Fire()
hex.Text = "not a colour"
hex.FocusLost:Fire()

check("nonsense is rejected", picker:hex() == "#7EAAFF", picker:hex())
check("and the field goes back to the truth", hex.Text == "#7EAAFF", hex.Text)

--// setValue --------------------------------------------------------------------
picker:setValue(Shim.Color3.fromRGB(255, 128, 0))

check("setValue takes", picker:hex() == "#FF8000", picker:hex())
check("setValue does not fire changed", #changed == 7, `{#changed}`)

local before = #changed

picker:setSilent(Shim.Color3.fromRGB(0, 0, 0))

check("setSilent takes", picker:hex() == "#000000", picker:hex())
check("setSilent stays silent", #changed == before)
check("and black off setSilent keeps the hue it had", near(picker.hue, 0.0833, 0.01), `{picker.hue}`)

--// reactive binding -----------------------------------------------------------
local bound = Lume.value(Shim.Color3.fromRGB(255, 0, 255))

picker:setValue(bound)

check("a bindable takes immediately", picker:hex() == "#FF00FF", picker:hex())

bound:set(Shim.Color3.fromRGB(0, 255, 0))

check("and follows when it changes", picker:hex() == "#00FF00", picker:hex())

--// layout ----------------------------------------------------------------------
local size = picker:measure(Shim.Vector2.new(400, 600))

check("it measures taller than its square", size.Y > 120, `{size.Y}`)

picker:setHexField(false)

local shorter = picker:measure(Shim.Vector2.new(400, 600))

check("hiding the hex field makes it shorter", shorter.Y < size.Y, `{shorter.Y} vs {size.Y}`)
check("and hides the row", picker.refs.row.Visible == false)

print(`ColorPicker: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
