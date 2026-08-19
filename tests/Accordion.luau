--!nocheck

--- The accordion. Its sections are groups, so the interesting checks are about
--- what a hidden section does to the layout around it, not about the fold.

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

local accordion = panel:accordion()

local general = accordion:section("General")
local advanced = accordion:section("Advanced")
local danger = accordion:section("Danger", "danger")

--// a section body is a group, so everything a panel hosts works here
general:label("Wireframe")
general:toggle("Draw collision volumes")

advanced:slider("Opacity"):setRange(0, 100)
advanced:stepper("Grid"):setRange(1, 16)

danger:button("Delete everything")

local toggled = {}

accordion:onToggled(function(id, open)
	table.insert(toggled, { id = id, open = open })
end)

panel:open()
Shim.step()

local available = Shim.Vector2.new(320, 600)

--// closed to begin with -------------------------------------------------------
check("three sections", #accordion.sections == 3, `{#accordion.sections}`)
check("a title becomes its id", accordion.sections[1].id == "General")
check("an explicit id is kept", accordion.sections[3].id == "danger")
check("everything starts closed", #accordion:openIds() == 0)
check("a closed body is hidden", general.instance.Visible == false)

local shut = accordion:measure(available)

check("closed, it is only headers tall", shut.Y < 100, `{shut.Y}`)

--// a closed section still has a width -----------------------------------------
--// measured on purpose: a panel that widened every time a section opened would
--// jump under the pointer
check("a closed section is still measured", general.measured == true)

--// opening --------------------------------------------------------------------
accordion:openSection("General")

local one = accordion:measure(available)

check("opening makes it taller", one.Y > shut.Y, `{one.Y} vs {shut.Y}`)
check("the body shows", general.instance.Visible == true)
check("opening reports it", #toggled == 1 and toggled[1].id == "General" and toggled[1].open == true)
check("openIds lists it", table.concat(accordion:openIds(), ",") == "General")

accordion:openSection("Advanced")

local two = accordion:measure(available)

check("two open is taller than one", two.Y > one.Y, `{two.Y} vs {one.Y}`)
check("both are listed", table.concat(accordion:openIds(), ",") == "General,Advanced")

--// opening an open section changes nothing
local before = #toggled

accordion:openSection("General")

check("opening what is already open does nothing", #toggled == before)

--// closing ---------------------------------------------------------------------
accordion:closeSection("General")

check("closing hides the body", general.instance.Visible == false)
check("closing reports it", toggled[#toggled].id == "General" and toggled[#toggled].open == false)

local back = accordion:measure(available)

check("and the height comes back down", back.Y < two.Y, `{back.Y} vs {two.Y}`)

--// the header ------------------------------------------------------------------
accordion.sections[1].header.Activated:Fire()

check("clicking a header opens it", general.instance.Visible == true)

accordion.sections[1].header.Activated:Fire()

check("clicking again closes it", general.instance.Visible == false)

--// exclusive -------------------------------------------------------------------
accordion:openSection("General")
accordion:openSection("danger")

check("three open before the rule", #accordion:openIds() == 3, table.concat(accordion:openIds(), ","))

accordion:setExclusive(true)

check("turning it on keeps exactly one", #accordion:openIds() == 1, table.concat(accordion:openIds(), ","))
check("and keeps the first that was open", accordion:openIds()[1] == "General", accordion:openIds()[1])

accordion:openSection("danger")

check("opening another closes the first", table.concat(accordion:openIds(), ",") == "danger")
check("the closure was reported", toggled[#toggled - 1].id == "General" and toggled[#toggled - 1].open == false)

--// an unknown id ----------------------------------------------------------------
local quiet = #toggled

accordion:openSection("nonexistent")
accordion:closeSection("nonexistent")
accordion:toggleSection("nonexistent")

check("an unknown id is ignored quietly", #toggled == quiet, `{#toggled} vs {quiet}`)

--// reaching a body afterwards ------------------------------------------------------
check("bodyOf finds a section", accordion:bodyOf("danger") == danger)
check("and returns nil for one that is not there", accordion:bodyOf("nope") == nil)

--// a control inside a hidden section still works ------------------------------------
local slider = advanced.children[1]

check("the section kept its children", #advanced.children == 2, `{#advanced.children}`)

slider:setValue(50)

check("a control in a closed section still takes a value", slider:value() == 50, `{slider:value()}`)

--// clear ----------------------------------------------------------------------------
accordion:clear()

check("clear empties it", #accordion.sections == 0)
check("and the height goes to nothing", accordion:measure(available).Y == 0, `{accordion:measure(available).Y}`)

print(`Accordion: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
