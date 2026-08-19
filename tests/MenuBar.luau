--!nocheck

--- The menu bar: a strip of titles, one shared popover, and the crossing
--- behaviour that makes it feel like a bar rather than a row of buttons.

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

local picked: { { item: any, from: string } } = {}

local bar = panel:menuBar({
	{
		text = "File",
		items = {
			{ id = "new", text = "New" },
			{ id = "open", text = "Open", shortcut = "Ctrl+O" },
			{ divider = true, text = "" },
			{ id = "quit", text = "Quit", danger = true },
		},
	},
	{
		text = "Edit",
		items = {
			{ id = "undo", text = "Undo" },
			{ id = "redo", text = "Redo", disabled = true },
		},
	},
	{ id = "help", text = "Help", items = { { id = "about", text = "About" } } },
})

bar:onPicked(function(item, from)
	table.insert(picked, { item = item, from = from })
end)

panel:open()
Shim.step()

--// the strip --------------------------------------------------------------
local buttons = (bar :: any).buttons

check("a button per menu", #buttons == 3, `{#buttons}`)
check("titles are the text given", buttons[1].Text == "File" and buttons[2].Text == "Edit")
check("an id defaults to the text", (bar :: any).menus[1].id == "File", (bar :: any).menus[1].id)
check("an explicit id is kept", (bar :: any).menus[3].id == "help", (bar :: any).menus[3].id)
check("titles are laid out in order", buttons[1].LayoutOrder < buttons[2].LayoutOrder)
check("the bar measures wider than one title", bar:measure(Shim.Vector2.new(800, 600)).X > buttons[1].AbsoluteSize.X)
check("nothing is open to begin with", bar:openId() == nil)

--// opening ----------------------------------------------------------------
buttons[1].Activated:Fire()
Shim.step()

check("clicking a title opens it", bar:openId() == "File", tostring(bar:openId()))

local menu = (bar :: any).menu
local surface = menu:surface()

check("a popover exists", surface ~= nil)
check("the popover is open", surface and surface.opened == true)
check("it hangs off the title it belongs to", surface and surface.attachTarget == buttons[1])
check("it closes on a click elsewhere", surface and surface.dismissable == true)

--// crossing the strip -------------------------------------------------------
--// hovering a neighbour with a menu already down switches to it, without a
--// second click. This is the behaviour that separates a bar from three buttons
buttons[2].MouseEnter:Fire()
Shim.step()

check("hovering a neighbour switches", bar:openId() == "Edit", tostring(bar:openId()))
check("the popover moved rather than multiplying", menu:surface() == surface)
check("and now hangs off the neighbour", surface.attachTarget == buttons[2])

--// hovering with nothing open does not open anything
bar:closeMenu()
Shim.step()

buttons[2].MouseEnter:Fire()
Shim.step()

check("hovering alone opens nothing", bar:openId() == nil, tostring(bar:openId()))

--// clicking the open title closes it -----------------------------------------
buttons[1].Activated:Fire()
Shim.step()

check("open again", bar:openId() == "File")

buttons[1].Activated:Fire()
Shim.step()

check("clicking the open title closes it", bar:openId() == nil, tostring(bar:openId()))

--// picking -------------------------------------------------------------------
buttons[3].Activated:Fire()
Shim.step()

check("Help is open", bar:openId() == "help")

--// press the row the menu built, rather than emitting past it. A Lume button
--// keeps its words in a TextLabel child, so the label is what to look for and
--// the button above it is what to click
local pressed = false

for _, child in menu:surface().instance:GetDescendants() do
	if child.ClassName == "TextLabel" and child.Text == "About" then
		local button = child:FindFirstAncestorOfClass("TextButton")

		if button then
			button.Activated:Fire()

			pressed = true
		end
	end
end

Shim.step()

check("the menu rendered its item as a button", pressed)
check("picking reports the item", #picked == 1 and picked[1].item.id == "about", `{#picked}`)
check("picking reports which menu it came from", #picked == 1 and picked[1].from == "help", picked[1] and picked[1].from)
check("picking closes the bar", bar:openId() == nil, tostring(bar:openId()))

--// a disabled title ----------------------------------------------------------
bar:setMenus({
	{ id = "file", text = "File", items = { { id = "new", text = "New" } } },
	{ id = "edit", text = "Edit", disabled = true, items = { { id = "undo", text = "Undo" } } },
})

Shim.step()

buttons = (bar :: any).buttons

check("setMenus rebuilds the strip", #buttons == 2, `{#buttons}`)

buttons[2].Activated:Fire()
Shim.step()

check("a disabled title does not open", bar:openId() == nil, tostring(bar:openId()))

buttons[1].Activated:Fire()
Shim.step()

check("its neighbour still does", bar:openId() == "file")

--// replacing the menus while one is open ---------------------------------------
bar:setMenus({ { id = "view", text = "View", items = { { id = "zoom", text = "Zoom" } } } })
Shim.step()

check("replacing the menus closes what was open", bar:openId() == nil, tostring(bar:openId()))
check("and leaves one title", #(bar :: any).buttons == 1)

print(`MenuBar: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
