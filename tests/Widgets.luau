--!nocheck

--- The wider widget set. One section each, and each one leans on whatever the
--- widget claims to be for rather than on the fact that it constructs.

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

panel:open()

local available = Shim.Vector2.new(320, 600)

--// radio -----------------------------------------------------------------------
do
	local radio = panel:radio("Team")

	radio:setOptions({ "Red", "Blue", { id = "spec", text = "Spectator" } })

	local heard = {}

	radio:onChanged(function(id)
		table.insert(heard, id)
	end)

	Shim.step()

	check("radio builds a row per option", #radio.rows == 3, `{#radio.rows}`)
	check("radio starts with nothing chosen", radio:value() == nil)

	radio.rows[2].button.Activated:Fire()

	check("clicking chooses", radio:value() == "Blue", tostring(radio:value()))
	check("choosing reports once", #heard == 1 and heard[1] == "Blue")

	radio.rows[2].button.Activated:Fire()

	check("clicking the chosen one changes nothing", #heard == 1, `{#heard}`)

	radio.rows[3].button.Activated:Fire()

	check("an explicit id is what comes back", radio:value() == "spec", tostring(radio:value()))

	--// a selection that survives into a list it is not on would report a value
	--// while showing none
	radio:setOptions({ "Red", "Blue" })

	check("a selection off the new list is dropped", radio:value() == nil, tostring(radio:value()))

	radio:setValue("Red")

	check("setValue takes", radio:value() == "Red")
	check("and does not fire changed", #heard == 2, `{#heard}`)
end

--// rating ----------------------------------------------------------------------
do
	local rating = panel:rating("How was it?")

	local heard = {}

	rating:onChanged(function(score)
		table.insert(heard, score)
	end)

	Shim.step()

	check("five stars by default", #rating.stars == 5, `{#rating.stars}`)

	rating.stars[4].Activated:Fire()
	--// the lighting is a spring, so it needs frames before it has arrived
	Shim.advance(0.6)

	check("clicking the fourth star scores four", rating:value() == 4, `{rating:value()}`)
	check("the first four are lit", rating.stars[4].TextTransparency == 0)
	check("the fifth is not", rating.stars[5].TextTransparency > 0)

	--// the preview is the whole run, not one star: the question is how many
	rating.stars[2].MouseEnter:Fire()
	Shim.advance(0.6)

	check("hovering previews the run", rating.preview == 2, tostring(rating.preview))
	check("and lights only up to there", rating.stars[3].TextTransparency > 0)

	rating.stars[2].MouseLeave:Fire()
	Shim.advance(0.6)

	check("leaving restores the score", rating.preview == nil and rating.stars[3].TextTransparency == 0)

	rating.stars[4].Activated:Fire()
	Shim.advance(0.6)

	check("clicking the current score clears it", rating:value() == 0, `{rating:value()}`)

	rating:setMaximum(10)

	check("the count can change", #rating.stars == 10, `{#rating.stars}`)
end

--// meter -----------------------------------------------------------------------
do
	local meter = panel:meter("Health")
	local zone = Lume.Elements.Meter.zone

	meter:setRange(0, 100)
	meter:setBands(25, 60)
	meter:setValue(80)

	Shim.advance(0.6)

	--// the colour is sprung, and a spring converges rather than arriving, so
	--// the band is asserted on directly and the colour only checked for having
	--// set off in the right direction
	check("a healthy reading is ok", zone(meter) == "ok", zone(meter))
	check("and the fill is green", meter.refs.fill.BackgroundColor3 == app.theme.color.success)

	meter:setValue(40)

	check("the middle band warns", zone(meter) == "warn", zone(meter))

	meter:setValue(10)

	check("below the floor is danger", zone(meter) == "danger", zone(meter))

	Shim.advance(1.5)

	check("and the fill has set off towards red", meter.refs.fill.BackgroundColor3.R > meter.refs.fill.BackgroundColor3.G)

	--// the same widget pointed the other way: for disk usage, high is the
	--// problem and low is healthy
	meter:setOptimum("low")

	check("optimum low flips the reading", zone(meter) == "ok", zone(meter))

	meter:setValue(90)

	check("and high becomes the danger", zone(meter) == "danger", zone(meter))

	meter:setValue(40)

	check("with the middle still the warning", zone(meter) == "warn", zone(meter))

	--// no bands at all means no opinion
	local plain = panel:meter("Progress")

	plain:setRange(0, 100)
	plain:setValue(3)

	check("without bands nothing is alarming", zone(plain) == "ok", zone(plain))

	check("the readout is a percentage", meter.refs.readout.Text == "40%", meter.refs.readout.Text)

	meter:setFormat(function(value, max)
		return `{value}/{max} hp`
	end)

	check("a formatter takes over", meter.refs.readout.Text == "40/100 hp", meter.refs.readout.Text)
end

--// spinner ---------------------------------------------------------------------
do
	local spinner = panel:spinner("Loading")

	Shim.step()

	local gradient = spinner.refs.ring:FindFirstChildOfClass("UIGradient")
	local before = gradient.Rotation

	Shim.step(0.2)

	check("the sweep turns", gradient.Rotation ~= before, `{gradient.Rotation}`)

	spinner:setSpinning(false)

	local stopped = gradient.Rotation

	Shim.step(0.2)

	check("stopping stops it", gradient.Rotation == stopped)
	check("and hides the ring", spinner.refs.ring.Visible == false)

	spinner:setSpinning(true)

	check("starting keeps its place rather than snapping to the top", spinner.angle == stopped)
end

--// table -----------------------------------------------------------------------
do
	local grid = panel:table()

	grid:setColumns({
		{ key = "name", title = "Player", weight = 2 },
		{ key = "score", title = "Score", align = "right" },
	})

	grid:setRows({
		{ name = "Rin", score = 120 },
		{ name = "Kai", score = 90 },
		{ name = "Ada", score = 40 },
	})

	local activated = {}

	grid:onActivated(function(row, index)
		table.insert(activated, { row = row, index = index })
	end)

	Shim.step()

	check("a row per entry", #grid.built == 3, `{#grid.built}`)
	check("a cell per column", #grid.built[1].cells == 2, `{#grid.built[1].cells}`)
	check("cells read their column's key", grid.built[1].cells[1].Text == "Rin", grid.built[1].cells[1].Text)
	check("a number becomes text", grid.built[1].cells[2].Text == "120", grid.built[1].cells[2].Text)

	--// weights, not pixels: a column of weight 2 out of 3 takes two thirds
	check("weight decides width", math.abs(grid.built[1].cells[1].Size.X.Scale - 2 / 3) < 0.01, `{grid.built[1].cells[1].Size.X.Scale}`)
	check("and the next cell starts where it ends", math.abs(grid.built[1].cells[2].Position.X.Scale - 2 / 3) < 0.01)

	check("stripes alternate", grid.built[2].instance.BackgroundTransparency < 1)
	check("and odd rows stay clear", grid.built[1].instance.BackgroundTransparency == 1)

	grid.built[2].instance.Activated:Fire()

	check("clicking a row reports it", #activated == 1 and activated[1].index == 2)
	check("with the row itself", activated[1].row.name == "Kai")

	grid:setSelectable(true)
	grid:setSelected(3)

	check("selection is visible", grid.built[3].instance.BackgroundTransparency < 0.9)
	check("and readable", grid:selected().name == "Ada")

	grid:setRows({ { name = "Rin", score = 1 } })

	check("a selection past the new end is dropped", grid:selected() == nil)
end

--// tree ------------------------------------------------------------------------
do
	local tree = panel:tree()

	tree:setNodes({
		{
			id = "world",
			text = "Workspace",
			children = {
				{ id = "map", text = "Map", children = { { id = "spawn", text = "Spawn" } } },
				{ id = "props", text = "Props" },
			},
		},
		{ id = "lighting", text = "Lighting" },
	})

	Shim.step()

	--// closed, only the roots exist as rows — the point of flattening rather
	--// than hiding
	check("closed, only the roots are rows", tree:count() == 2, `{tree:count()}`)

	tree:expandNode("world")

	check("expanding adds its children", tree:count() == 4, `{tree:count()}`)
	check("but not its grandchildren", tree.expanded["map"] == nil)

	tree:expandNode("map")

	check("expanding deeper adds more", tree:count() == 5, `{tree:count()}`)
	check("depth becomes indent", tree.rows[3].Chevron.Position.X.Offset > tree.rows[1].Chevron.Position.X.Offset)

	tree:collapseNode("world")

	check("collapsing takes the whole branch", tree:count() == 2, `{tree:count()}`)

	tree:expandAll()

	check("expandAll opens everything", tree:count() == 5, `{tree:count()}`)

	local picked = {}

	tree:onSelected(function(node, id)
		table.insert(picked, id)
	end)

	tree.rows[5].Activated:Fire()

	check("clicking a leaf selects it", tree:value() == "lighting", tostring(tree:value()))
	check("and reports it", #picked == 1 and picked[1] == "lighting")

	tree:collapseAll()

	check("collapseAll closes everything", tree:count() == 2, `{tree:count()}`)
end

--// avatar ----------------------------------------------------------------------
do
	local avatar = panel:avatar(1)

	avatar:setName("Rin Okabe")

	Shim.step()

	check("a user id becomes a thumbnail url", avatar.image:match("^rbxthumb://") ~= nil, avatar.image)
	check("with the id in it", avatar.image:match("id=1") ~= nil, avatar.image)
	check("initials come from the name", avatar.initials == "RO", avatar.initials)

	avatar:setName("Rin")

	check("one word gives two letters", avatar.initials == "RI", avatar.initials)

	avatar:setUserId(nil)

	check("no user means no image", avatar.image == "", avatar.image)
	check("and the initials are what is left", avatar.refs.initials.Visible == true)

	avatar:setStatus("busy")

	check("a status dot shows", avatar.refs.status.Visible == true)
	check("and takes its colour from the status", avatar.refs.status.BackgroundColor3 == app.theme.color.danger)
end

--// breadcrumb ------------------------------------------------------------------
do
	local trail = panel:breadcrumb({ "Home", "Maps", "Arena" })

	local picked = {}

	trail:onPicked(function(id, index)
		table.insert(picked, { id = id, index = index })
	end)

	Shim.step()

	check("a button per crumb", #trail.buttons == 3, `{#trail.buttons}`)

	trail.buttons[1].Activated:Fire()

	check("clicking a crumb reports it", #picked == 1 and picked[1].id == "Home")

	--// the last crumb is where you are, and a link that does nothing reads as
	--// broken rather than as "you are already here"
	trail.buttons[3].Activated:Fire()

	check("the last crumb is not a link", #picked == 1, `{#picked}`)
	check("and is drawn as the current one", trail.buttons[3].TextTransparency == 0)
	check("while the others are muted", trail.buttons[1].TextTransparency > 0)
end

--// pagination ------------------------------------------------------------------
do
	local pager = panel:pagination(20)

	local heard = {}

	pager:onChanged(function(page)
		table.insert(heard, page)
	end)

	Shim.step()

	check("it starts on page one", pager:value() == 1)

	local slots = Lume.Elements.Pagination.slotsFor(1, 20, 1)

	check("a long run collapses", #slots < 20, `{#slots}`)
	check("the first page survives", slots[1] == 1)
	check("the last page survives", slots[#slots] == 20)
	check("and an ellipsis stands in", table.find(slots, 0) ~= nil)

	local middle = Lume.Elements.Pagination.slotsFor(10, 20, 1)

	check("the neighbourhood survives", table.find(middle, 9) and table.find(middle, 10) and table.find(middle, 11))
	check("with an ellipsis either side", middle[2] == 0 and middle[#middle - 1] == 0)

	local short = Lume.Elements.Pagination.slotsFor(1, 4, 1)

	check("a short run does not collapse", #short == 4 and table.find(short, 0) == nil)

	pager:goTo(7)

	check("goTo moves", pager:value() == 7)
	check("and reports", #heard == 1 and heard[1] == 7)

	pager:goTo(999)

	check("past the end clamps", pager:value() == 20, `{pager:value()}`)
end

--// scrubber --------------------------------------------------------------------
do
	local scrubber = panel:scrubber("Z")

	scrubber:setStep(1)

	local heard = {}
	local committed = {}

	scrubber:onChanged(function(value)
		table.insert(heard, value)
	end)

	scrubber:onCommitted(function(value)
		table.insert(committed, value)
	end)

	Shim.step()

	local box = scrubber.refs.box

	local function drag(from: number, to: number)
		box.InputBegan:Fire({
			UserInputType = Shim.Enum.UserInputType.MouseButton1,
			Position = Shim.Vector2.new(from, 0),
		})
		Shim.services.UserInputService.InputChanged:Fire({
			UserInputType = Shim.Enum.UserInputType.MouseMovement,
			Position = Shim.Vector2.new(to, 0),
		})
		Shim.services.UserInputService.InputEnded:Fire({
			UserInputType = Shim.Enum.UserInputType.MouseButton1,
			Position = Shim.Vector2.new(to, 0),
		})
	end

	--// no range at all: the thing a slider cannot do
	check("it has no range to begin with", scrubber.minimum == nil and scrubber.maximum == nil)

	drag(100, 130)

	check("dragging right adds", scrubber:value() == 30, `{scrubber:value()}`)
	check("and commits on release", #committed == 1, `{#committed}`)

	drag(100, 60)

	check("dragging left subtracts", scrubber:value() == -10, `{scrubber:value()}`)
	check("with no floor to stop it", scrubber:value() < 0)

	--// a drag that wanders back where it started leaves the number alone,
	--// because the maths is against the anchor rather than the last frame
	local settled = scrubber:value()

	box.InputBegan:Fire({ UserInputType = Shim.Enum.UserInputType.MouseButton1, Position = Shim.Vector2.new(0, 0) })

	for _, x in { 40, 80, 20, 0 } do
		Shim.services.UserInputService.InputChanged:Fire({
			UserInputType = Shim.Enum.UserInputType.MouseMovement,
			Position = Shim.Vector2.new(x, 0),
		})
	end

	Shim.services.UserInputService.InputEnded:Fire({
		UserInputType = Shim.Enum.UserInputType.MouseButton1,
		Position = Shim.Vector2.new(0, 0),
	})

	check("a wandering drag does not drift", scrubber:value() == settled, `{scrubber:value()} vs {settled}`)

	scrubber:setRange(0, nil)

	check("adding a floor clamps", scrubber:value() == 0, `{scrubber:value()}`)

	scrubber:setSensitivity(0.1)
	drag(0, 100)

	check("sensitivity scales the drag", scrubber:value() == 10, `{scrubber:value()}`)
end

--// vector ----------------------------------------------------------------------
do
	local vector = panel:vector("Position", 3)

	vector:setStep(1)

	local heard = {}

	vector:onChanged(function(value)
		table.insert(heard, value)
	end)

	Shim.step()

	check("three axes", #vector.axes == 3, `{#vector.axes}`)
	check("named X Y Z", vector.axes[1].key == "X" and vector.axes[3].key == "Z")
	check("each tinted differently", vector.axes[1].tint ~= vector.axes[2].tint)

	vector:setValue(Shim.Vector3.new(1, 2, 3))

	check("a Vector3 goes in", table.concat(vector:value(), ",") == "1,2,3", table.concat(vector:value(), ","))
	check("and comes back out", vector:vector3().Y == 2)

	vector:setAxis(2, 9)

	check("one axis moves alone", table.concat(vector:value(), ",") == "1,9,3")
	check("and reports the whole vector", #heard == 1 and heard[1][2] == 9)

	vector:setCount(2)

	check("it can be a Vector2", #vector.axes == 2, `{#vector.axes}`)
	check("and each axis is half the row", math.abs(vector.axes[1].box.Size.X.Scale - 0.5) < 0.01)
end

--// sparkline -------------------------------------------------------------------
do
	local spark = panel:sparkline({ 1, 4, 2, 8, 5 })

	--// no AbsoluteSize is set on purpose: Roblox has not laid the element out
	--// on the frame it is built, and a line drawn from AbsoluteSize came out as
	--// a row of one-pixel stubs and stayed that way, because nothing rebuilt it
	panel:refreshNow()
	Shim.step()

	check("segments are drawn at a real length", spark.segments[1].Size.X.Offset > 4, `{spark.segments[1].Size.X.Offset}`)
	check("and the element knows the size it was given", spark.plot.X > 4, `{spark.plot.X}`)

	--// a rising step and a falling one lean opposite ways
	check("the line follows the data", spark.segments[1].Rotation < 0 and spark.segments[2].Rotation > 0,
		`{spark.segments[1].Rotation} / {spark.segments[2].Rotation}`)

	check("a segment between each pair", #spark.segments == 4, `{#spark.segments}`)
	check("the last point is readable", spark:last() == 5, tostring(spark:last()))

	--// the lowest point sits at the bottom and the highest at the top, which
	--// is the whole information content of the shape
	local lowest = spark.segments[1].Position.Y.Scale

	check("the minimum is at the bottom", math.abs(lowest - 1) < 0.01, `{lowest}`)

	spark:setPoints({ 5, 5, 5 })

	--// a flat line has no span to divide by, and belongs down the middle
	check("a flat line sits in the middle", math.abs(spark.segments[1].Position.Y.Scale - 0.5) < 0.01, `{spark.segments[1].Position.Y.Scale}`)

	spark:setPoints({ 1 })

	check("one point draws nothing", #spark.segments == 0, `{#spark.segments}`)
end

--// graph ------------------------------------------------------------------------
do
	local graph = panel:graph("Frame time")

	graph:setUnit("ms")
	graph:setWindow(5)
	graph:setThresholds(16, 33)
	graph:setOptimum("low")

	Shim.step()

	graph:push(8)
	graph:push(12)

	check("pushing adds samples", #graph.samples == 2, `{#graph.samples}`)
	check("a bar per sample", graph.bars[2].Visible == true)
	check("the readout carries the unit", graph.refs.readout.Text == "12ms", graph.refs.readout.Text)
	check("the last sample is readable", graph:last() == 12)
	check("and the mean", graph:average() == 10, `{graph:average()}`)

	--// thresholds are what makes a debug graph worth looking at: a number is
	--// only interesting against the number you would accept
	check("under the warning is fine", Lume.Elements.Graph.grade(graph, 8) == "ok")
	check("over it warns", Lume.Elements.Graph.grade(graph, 20) == "warn")
	check("over the failure line fails", Lume.Elements.Graph.grade(graph, 40) == "fail")

	graph:push(40)

	check("a failing bar turns red", graph.bars[3].BackgroundColor3 == app.theme.color.danger)
	check("and so does the readout", graph.refs.readout.TextColor3 == app.theme.color.danger)

	--// the same graph pointed the other way: for frames per second, low is bad
	graph:setOptimum("high")

	check("optimum high flips it", Lume.Elements.Graph.grade(graph, 8) == "fail", Lume.Elements.Graph.grade(graph, 8))

	graph:setOptimum("low")

	--// the window is a window
	graph:push(1)
	graph:push(2)
	graph:push(3)

	check("the window drops the oldest", #graph.samples == 5, `{#graph.samples}`)
	check("and keeps the newest", graph:last() == 3)

	--// the threshold lines have to be inside the scale, or a quiet graph draws
	--// its warning line off the top
	local low, high = Lume.Elements.Graph.bounds(graph)

	check("the scale swallows the thresholds", high >= 33 and low <= 1, `{low}..{high}`)

	graph:setRange(0, 50)

	local fixedLow, fixedHigh = Lume.Elements.Graph.bounds(graph)

	check("a fixed range wins", fixedLow == 0 and fixedHigh == 50, `{fixedLow}..{fixedHigh}`)

	graph:clear()

	check("clearing empties it", #graph.samples == 0)
	check("and hides the bars", graph.bars[1].Visible == false)
end

--// growing inside a row ----------------------------------------------------------
do
	--// `grow` absorbs leftover space along the *parent's* main axis. Group and
	--// Accordion wrote their own commit and only implemented the vertical
	--// case, so a growing child of a horizontal row took its share of the
	--// leftover width and applied it to its height — a three-line readout came
	--// out three hundred pixels tall and sat on top of everything under it.
	local row = panel:group("horizontal")

	row:setFill(true)
	row:setGap(8)

	row:avatar(1):setDiameter(28)

	local lines = row:group("vertical")

	lines:setGrow(true)
	lines:setGap(2)

	lines:label("team: red")
	lines:label("grid: 4 studs")
	lines:label("hour: 12:00")

	panel:refreshNow()
	Shim.step()

	local natural = lines:measure(Shim.Vector2.new(420, 600))

	check("a grown child of a row keeps its own height", lines.instance.Size.Y.Offset == natural.Y, `{lines.instance.Size.Y.Offset} vs {natural.Y}`)
	check("and takes the leftover width instead", lines.instance.Size.X.Offset > natural.X, `{lines.instance.Size.X.Offset} vs {natural.X}`)
	check("so it fits the row it is in", lines.instance.Size.Y.Offset <= row.instance.Size.Y.Offset)

	--// the same rule for an accordion, which copied the same commit
	local nested = panel:group("horizontal")

	nested:setFill(true)

	local folds = nested:accordion()

	folds:setGrow(true)
	folds:section("One"):label("a")

	panel:refreshNow()
	Shim.step()

	local foldsNatural = folds:measure(Shim.Vector2.new(420, 600))

	check("an accordion in a row behaves the same", folds.instance.Size.Y.Offset == foldsNatural.Y, `{folds.instance.Size.Y.Offset} vs {foldsNatural.Y}`)
end

print(`Widgets: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
