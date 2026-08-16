# Lume

A panel-and-element UI standard for Roblox.

Two primitives. A **Panel** is every surface — window, command bar, dropdown,
tooltip, modal, toast. An **Element** is everything a surface hosts. Panels size
themselves from their elements, grow away from whatever edge they are anchored
to, and morph as their content changes.

```lua
local Lume = require(ReplicatedStorage.Packages.Lume)

local app = Lume.app({ name = "Inspector" })

local panel = app:panel("window")
    :setTitle("Inspector")
    :setAnchor("bottomRight")
    :setWidth(320)

panel:field("Search")
    :setPrefix(">")
    :onSubmitted(print)

panel:button("Refresh")
    :setVariant("solid")
    :onClicked(refresh)

panel:open()
```

Every setter returns the receiver, and every setter takes a plain value or a
reactive one.

## Why it looks the way it does

The feel is not a palette. It is six mechanics, and the library exists to make
all six automatic:

| | |
|---|---|
| **Content-driven sizing** | Nothing has a hardcoded size. Elements report what they want, the panel adds them up and clamps against how much screen is actually left in the direction it grows. |
| **Anchored growth** | The anchored edge never moves. A bottom-anchored panel expands upward. |
| **The morph** | A pill-shaped bar becomes a rounded rectangle the moment it stops being one row tall. |
| **One motion driver** | Springs that keep their velocity when you retarget them mid-flight, so a size that changes three times while the panel is still moving bends instead of restarting. |
| **Coordinated fades** | Children fade on one duration while the shell morphs on another. Deliberately different. |
| **Stacking** | Panels queue from a shared anchor, each pushed along by the ones before it. |

## The layout contract

Every element answers two calls:

```lua
element:measure(available)              --> the size it wants
element:commit(inner, vertical, share)  --> apply the size the panel decided on
```

`measure` reports the element's **natural** size and mutates nothing. `commit`
applies what the panel settled on — the first moment a `fill` element can know
how wide it is allowed to be.

The split matters. An element that reported the full available width as its
*desired* width would drag every auto-sized panel to its maximum, and a command
bar that is always 900px wide is not content-driven, it is just wide. So
**`fill` belongs to commit, never to measure.**

That one rule is where the responsiveness comes from. Nothing needs re-tuning
per screen size, because nothing was tuned to a screen size to begin with.

## Panels

```lua
local panel = app:panel("window")
    :setTitle("Settings")
    :setSubtitle("v2")
    :setAnchor("bottomRight")
    :setWidth("auto")        -- or a number
    :setMaxSize(720, 640)
    :setPadding(12)
    :setGap(8)
    :setDraggable(true)
    :setDismissable(true)
    :setShadow(true)
```

Presets are configuration, not subclasses: `window`, `bar`, `popover`,
`tooltip`, `modal`, `toast`, `card`, `sheet`, `plain`. Each is the same Panel
with different numbers, which is why they all inherit the sizing, the growth
and the morph for free.

Panels nest. A panel inside a panel is laid out as an element, which is how
stacking, popovers and inline cards are one code path:

```lua
local card = panel:panel("card")
card:label("nested, and still content-sized")
```

Layers keep popovers out of trouble. A dropdown opened from the bottom of a
small panel is not clipped by it, because it lives on the popover layer and
positions itself against the trigger — flipping above when there is no room
below.

## Elements

`label` `icon` `button` `field` `toggle` `slider` `select` `list` `divider`
`spacer` `group` `progress` `tabs` `chips` `suggest` `menu` `badge` `scroll`
`keybind`

```lua
panel:label("Wrapped body copy"):setWrapped(true):setMuted(true)
panel:toggle("Wireframe"):setDescription("Draw collision volumes"):setValue(true)
panel:slider("Opacity"):setRange(0, 100):setStep(1):onCommitted(save)
panel:select("Mode"):setOptions({ "Solid", "Wireframe" }):setSearchable(true)
panel:tabs():setTabs({ "General", "Advanced" }):setVariant("underline")
```

Use a `group` for a row inside a column, with a flexible spacer to push things
apart:

```lua
local row = panel:group("horizontal")

row:label("Status")
row:spacer():setFlexible(true)
row:badge("live"):setTone("success"):setDot(true)
```

Lists are virtualised. Only the rows on screen exist as instances, so ten
thousand items cost the same as ten — and the list still reports its widest row,
which is how a panel ends up exactly as wide as its longest line.

```lua
panel:list()
    :setItems(items)     -- 5000 items -> 7 instances
    :setMaxRows(8)
    :onActivated(open)
```

## Inline autocomplete

`suggest` filters a source against a query and writes the remainder of the best
match into the attached field as a ghost hint, sitting right after the caret.
Up and Down move the highlight, Tab accepts it.

```lua
local field = bar:field("Type a command…"):setPrefix(">")

bar:suggest()
    :setSource(commandNames)
    :attach(field)
    :onAccepted(function(option)
        print("chose", option.text)
    end)
```

## State

Reactivity is built in. Any setter takes a plain value or a source.

```lua
local count = Lume.value(0)
local label = Lume.computed(function()
    return `{count:get()} selected`
end)

panel:label(label)          -- updates itself
panel:label(Lume.format(count, "%d selected"))

count:update(function(n) return n + 1 end)

Lume.batch(function()       -- one notification per changed cell
    first:set(1)
    second:set(2)
end)
```

Computeds track their dependencies automatically and resubscribe on every
recompute, so branching stays correct. Rebinding a setter disposes the previous
subscription.

## Theming

The defaults **are** the console look, not an approximation of it: pure black
surfaces at `0.3` transparency, the terminal green at hue 142°, a pill that
morphs to a 12px radius. The surface values are the ones the original used, and
the demo capture measures back to them — panel interior reads 12.7 over ground
at 36.8, so `12.7 / 36.8 ≈ 0.34` against black.

Separation between layers comes from transparency, not from lightening each
surface. That is what makes it read as glass over the world instead of as grey
boxes, and it is the single thing most worth preserving if you retheme.

Tokens are deep-merged. Components read names, never literals.

```lua
app:restyle({
    color = { accent = Color3.fromRGB(255, 120, 200) },
    radius = { md = 6 },
    motion = { layout = { stiffness = 260, damping = 28 } },
})
```

A restyle flushes the measurement cache and refreshes every panel, because sizes
are text-derived — a font change is a layout change.

`accent` defaults to the terminal green. If you want the neutral blue instead,
it is kept as `info`:

```lua
app:restyle({ color = { accent = app.theme.color.info } })
```

Shadows are opt-in and ship with no baked asset. Point `theme.shadow.image` at
your own nine-sliced soft shadow and every panel picks it up; leave it empty and
no shadow instances are created at all.

## Motion

One driver, two paths, chosen by the spec:

- **Tween** (`duration` + `easing`) — handed to TweenService. Cheap, correct for
  one-shot fades and presses.
- **Spring** (`stiffness` + `damping`) — stepped analytically, one channel per
  instance-property, identical at 30fps and 240fps. Retargeting keeps position
  *and velocity*.

Anything content-driven is a spring on purpose. Starting a tween on a property
cancels its spring and vice versa, so the two can never fight over one value.

## Lifecycle

Scopes own everything. Destroying a panel takes its elements, their instances,
their connections and their subscriptions with it, in reverse creation order.

```lua
panel:destroy()
app:destroy()    -- and everything under it
```

## Examples

`examples/Terminal.client.luau` is the original console command bar rebuilt on
Lume — a 1:1, with every metric taken from the original's own fallbacks rather
than eyeballed. Verified against it: a 220×36 pill at radius 18, anchored 24px
off the bottom, growing to 456 tall (`historyMaxHeight` 420 + 36) at radius 12
with the bottom edge held.

`examples/CommandBar.client.luau` is a smaller take on the same idea, and
`examples/Inspector.client.luau` is a settings window with tabs, a modal and
stacked toasts.

## Install

```toml
# wally.toml
[dependencies]
Lume = "kr3ative/lume@0.1.0"
```

Or drop `src/` in as a ModuleScript tree. No runtime dependencies — Lume ships
its own reactivity, motion driver and measurement cache.

## Credit

Distilled from the Repl console UI by driftingAurora, dullflowerr, alias and
kioukaii (MIT), generalised into a component library.

MIT.
