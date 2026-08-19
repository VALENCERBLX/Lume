--!nocheck

--- The stepper: clicks, holds, typed input, and the two events that keep a
--- forty-step hold from becoming forty writes.

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

local app = Lume.app({ name = "Test" })
local panel = app:panel("window")

local stepper = panel:stepper("Quantity")

stepper:setRange(0, 10)
stepper:setValue(3)

panel:open()
Shim.step()

local minus = stepper.refs.minus
local plus = stepper.refs.plus
local box = stepper.refs.value

local changed = {}
local committed = {}

stepper:onChanged(function(n)
	table.insert(changed, n)
end)

stepper:onCommitted(function(n)
	table.insert(committed, n)
end)

local function click(target)
	target.MouseButton1Down:Fire()
	target.MouseButton1Up:Fire()
end

--// the basics ------------------------------------------------------------------
check("starts where it was set", stepper:value() == 3, `{stepper:value()}`)
check("the field shows the number", box.Text == "3", box.Text)
check("the label shows", stepper.refs.label.Text == "Quantity" and stepper.refs.label.Visible)

click(plus)

check("plus adds a step", stepper:value() == 4, `{stepper:value()}`)
check("a click fires changed once", #changed == 1, `{#changed}`)
check("and committed once", #committed == 1, `{#committed}`)
check("the field followed", box.Text == "4", box.Text)

click(minus)
click(minus)

check("minus subtracts", stepper:value() == 2, `{stepper:value()}`)

--// the ends of the range -----------------------------------------------------------
for _ = 1, 20 do
	click(minus)
end

check("it stops at the floor", stepper:value() == 0, `{stepper:value()}`)
check("and the floor button says so", minus.TextTransparency > 0)

local silent = #changed

click(minus)

check("a click at the floor changes nothing", #changed == silent, `{#changed} vs {silent}`)

for _ = 1, 20 do
	click(plus)
end

check("it stops at the ceiling", stepper:value() == 10, `{stepper:value()}`)
check("and the ceiling button says so", plus.TextTransparency > 0)

--// holding ------------------------------------------------------------------------
stepper:setValue(0)
table.clear(changed)
table.clear(committed)

plus.MouseButton1Down:Fire()

check("the press itself steps once", stepper:value() == 1, `{stepper:value()}`)

--// the hold has not started repeating yet: that waits out the delay
Shim.advance(0.3)

check("a short hold does not repeat", stepper:value() == 1, `{stepper:value()}`)

Shim.advance(1.0)

check("a long hold repeats", stepper:value() > 3, `{stepper:value()}`)

local reached = stepper:value()

check("repeating fires changed every step", #changed >= 3, `{#changed}`)
check("but has not committed yet", #committed == 0, `{#committed}`)

plus.MouseButton1Up:Fire()

check("releasing commits once", #committed == 1, `{#committed}`)
check("and only once", committed[1] == reached, `{committed[1]} vs {reached}`)

Shim.advance(0.5)

check("releasing stops the repeat", stepper:value() == reached, `{stepper:value()} vs {reached}`)

--// pressing the other button mid-hold --------------------------------------------
--// each hold carries a token, and the loop stops as soon as it is not the one
--// holding any more — otherwise both directions would repeat at once
stepper:setValue(5)

plus.MouseButton1Down:Fire()
Shim.advance(0.6)

minus.MouseButton1Down:Fire()

local swapped = stepper:value()

Shim.advance(0.5)

check("the second press takes the hold over", stepper:value() < swapped, `{stepper:value()} vs {swapped}`)

minus.MouseButton1Up:Fire()
Shim.advance(0.5)

local settled = stepper:value()

Shim.advance(0.5)

check("and only one hold survives the release", stepper:value() == settled, `{stepper:value()} vs {settled}`)

--// the pointer leaving mid-hold ------------------------------------------------------
stepper:setValue(0)
table.clear(committed)

plus.MouseButton1Down:Fire()
Shim.advance(0.8)

local wandered = stepper:value()

plus.MouseLeave:Fire()
Shim.advance(0.8)

check("leaving the button stops the repeat", stepper:value() == wandered, `{stepper:value()} vs {wandered}`)
check("and commits", #committed == 1, `{#committed}`)

--// typing ------------------------------------------------------------------------
table.clear(committed)

box.Focused:Fire()
box.Text = "7"
box.FocusLost:Fire()

check("typing a number takes", stepper:value() == 7, `{stepper:value()}`)
check("and commits", #committed == 1, `{#committed}`)

box.Focused:Fire()
box.Text = "  9 kg "
box.FocusLost:Fire()

check("stray characters are ignored", stepper:value() == 9, `{stepper:value()}`)

box.Focused:Fire()
box.Text = "nonsense"
box.FocusLost:Fire()

check("nonsense is rejected", stepper:value() == 9, `{stepper:value()}`)
check("and the field goes back to the number", box.Text == "9", box.Text)

box.Focused:Fire()
box.Text = "999"
box.FocusLost:Fire()

check("a typed number is still clamped", stepper:value() == 10, `{stepper:value()}`)

--// steps that are not whole ------------------------------------------------------
local fine = panel:stepper("Opacity")

fine:setRange(0, 1)
fine:setStep(0.1)
fine:setValue(0)

fine:bump(1)
fine:bump(1)
fine:bump(1)

check("fractional steps add up", fine:value() == 0.3, `{fine:value()}`)
check("and do not leak float dust", fine.refs.value.Text == "0.3", fine.refs.value.Text)

--// wrapping ------------------------------------------------------------------------
local hour = panel:stepper("Hour")

hour:setRange(0, 23)
hour:setStep(1)
hour:setWrap(true)
hour:setValue(23)

hour:bump(1)

check("wrapping past the top comes back to the bottom", hour:value() == 0, `{hour:value()}`)

hour:bump(-1)

check("and past the bottom returns to the top", hour:value() == 23, `{hour:value()}`)
check("a wrapping stepper has no dead ends", hour.refs.minus.TextTransparency == 0)

--// formatting ---------------------------------------------------------------------
local weight = panel:stepper("Weight")

weight:setRange(0, 100)
weight:setValue(12)
weight:setFormat(function(n)
	return `{n} kg`
end)

check("a formatter writes the field", weight.refs.value.Text == "12 kg", weight.refs.value.Text)

--// reactive binding ----------------------------------------------------------------
local bound = Lume.value(5)

local followed = panel:stepper()

followed:setRange(0, 10)
followed:setValue(bound)

check("a bindable takes immediately", followed:value() == 5, `{followed:value()}`)

bound:set(8)

check("and follows when it changes", followed:value() == 8, `{followed:value()}`)

print(`Stepper: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
