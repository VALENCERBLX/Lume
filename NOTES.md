# Lume — design notes

**Pitch (decided 2026-08-16):** the house UI standard. Two primitives — **Panel**
(every surface) and **Element** (everything a surface hosts) — carrying the look
and feel of the Repl command bar, generalised so it works for any occasion.

## Where it came from

Distilled from the Repl console UI (`driftingAurora, dullflowerr, alias;
kioukaii`, MIT) and the abandoned first-pass generalisation (`Lume` v0, which
was App/Component shaped and re-derived layout per component).

The sleekness of that UI is not a colour palette. It is six mechanics:

1. **Content-driven sizing.** `activeWidth()` measures the widest visible text,
   clamps against the viewport, animates to it. Nothing has a hardcoded size.
2. **Morphing radius.** Pill (`UDim.new(1, 0)`) to rounded rect as content
   appears. That single tween is most of the feel.
3. **Anchored growth.** The anchored edge never moves; the panel grows away
   from whatever it is stuck to.
4. **One motion driver, sequence-tokened.** `layoutSeq += 1` invalidates every
   stale deferred callback, so retargeting mid-flight never leaves half-applied
   state.
5. **Coordinated fades.** Children fade on one duration while the shell morphs
   on another. They are deliberately different.
6. **Stacking and detaching.** Panels stack with a gap, detach into free
   floating draggables, each with a shadow tracking its bounds.

## Decided

- **Two primitives.** Panel and Element. A panel nested in a panel is how
  stacking, popovers and modals all fall out of one implementation.
- **The layout contract.** Every element implements `measure(available)`
  returning a desired size. Panel runs *one* pass: sum measures → clamp to
  viewport-aware limits → animate with the anchored edge pinned. This is the
  whole responsiveness story, and it is why elements never touch the ScreenGui.
- **`fill` belongs to commit, never to measure.** Found the hard way: the first
  implementation had filling elements report the full available width as their
  *desired* width, which dragged every auto-sized panel straight to its
  `maxWidth`. The command bar came out 900px wide with one empty field in it.
  Measure reports the element's natural size; `commit(inner, vertical, share)`
  stretches it afterwards, once the panel has settled. Every element's `measure`
  now uses `available` only as a **ceiling** (`math.min(natural, available)`),
  never as the answer.
- **The morph threshold is per-panel, not a token.** "One row tall" means
  `padY * 2 + size.control + chrome`, computed from the panel's own padding. A
  panel with roomier padding is still a single row and should still be a pill;
  keying it to a global `size.bar` silently disabled the morph for any panel
  whose padding did not happen to match.
- **Chained builders.** Every setter returns self. `Panel.new(app):setPreset(…)
  :setTitle(…):open()`. Elements expose `onClicked`-style chained event
  methods alongside the generic `on(name, fn)`.
- **Bindable props, built in.** Every setter takes a raw value *or* a `Value` /
  `Computed`. No external reactivity dependency; rebinding a key disposes the
  previous subscription.
- **Typed fields.** Runtime fields are declared on the Luau class types in
  `Types.luau`. No `(x :: any).field = …` smuggling anywhere.
- **Presets over subclasses.** `window`, `bar`, `popover`, `tooltip`, `modal`,
  `toast`, `card`, `sheet` are all configuration of the same Panel.
- **Springs are retargetable.** The motion driver decomposes UDim2/Color3/etc.
  into scalar channels and springs each one, so a target that changes mid
  flight is absorbed instead of restarted.

## Deliberately not doing

- A virtual DOM or diffing reconciler. Handles are the retained tree.
- Baked asset ids. Shadows are opt-in via `theme.shadow.image`; ship without
  one and no shadow instances are created at all.
- A layout engine that competes with UIListLayout. Lume measures, decides a
  size, and lets Roblox's own layout place the children.
