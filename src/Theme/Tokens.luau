--!strict

--- The default token set. Components read from here and never from literals,
--- so one `app:restyle{…}` call restyles the whole tree.
---
--- These values are the console look, not an invention. The surfaces are pure
--- black at roughly a third transparency, which is what the original terminal
--- used and what the demo capture measures back to: panel interior reads 12.7
--- over ground at 36.8, so `12.7 / 36.8 ≈ 0.34` against black.
---
--- Numbers marked *(console)* are lifted from the original UI's own fallbacks
--- (`panel.stackGap or 8`, `motion.outputSmoothTime or 0.24`, and so on), so
--- the defaults match the thing they came from rather than approximating it.
--- @section Theme

return {
	name = "default",

	color = {
		--// pure black surfaces. The separation between layers comes from
		--// transparency, not from lightening each one — which is why the
		--// console reads as glass over the world instead of as grey boxes
		surface = Color3.fromRGB(0, 0, 0),
		surfaceRaised = Color3.fromRGB(0, 0, 0),
		surfaceSunken = Color3.fromRGB(0, 0, 0),
		surfaceHover = Color3.fromRGB(255, 255, 255),
		surfaceActive = Color3.fromRGB(255, 255, 255),
		overlay = Color3.fromRGB(0, 0, 0),

		border = Color3.fromRGB(0, 0, 0),
		borderStrong = Color3.fromRGB(96, 96, 106),

		text = Color3.fromRGB(238, 238, 242),
		textMuted = Color3.fromRGB(146, 146, 158),
		textGhost = Color3.fromRGB(96, 96, 106),
		textInverse = Color3.fromRGB(12, 12, 14),

		--// the terminal green: measured off the demo at hue 142°, un-blended
		--// from the near-black panel behind it
		terminal = Color3.fromRGB(102, 209, 140),

		accent = Color3.fromRGB(102, 209, 140),
		accentMuted = Color3.fromRGB(64, 130, 88),
		accentText = Color3.fromRGB(8, 14, 10),

		--// v0's blue, kept for anyone who wants the non-terminal accent back:
		--// `app:restyle({ color = { accent = theme.color.info } })`
		info = Color3.fromRGB(126, 170, 255),

		success = Color3.fromRGB(137, 255, 126),
		warn = Color3.fromRGB(255, 214, 126),
		danger = Color3.fromRGB(255, 126, 126),

		track = Color3.fromRGB(255, 255, 255),
		selection = Color3.fromRGB(102, 209, 140),
	},

	--// hex mirrors of the palette, for RichText spans
	rich = {
		text = "#EEEEF2",
		muted = "#9292A0",
		ghost = "#60606A",
		terminal = "#66D18C",
		accent = "#66D18C",
		success = "#89FF7E",
		warn = "#FFD67E",
		danger = "#FF7E7E",
	},

	transparency = {
		--// the console's own values: surfaces at a third, borders faint,
		--// body text solid
		surface = 0.3,
		surfaceRaised = 0.3,
		overlay = 0.45,
		border = 0.35,
		text = 0,
		muted = 0.5,
		ghost = 0.6,
		track = 0.88,
		shadow = 0.55,
		disabled = 0.6,
	},

	font = {
		body = Enum.Font.Gotham,
		medium = Enum.Font.GothamMedium,
		bold = Enum.Font.GothamBold,
		mono = Enum.Font.Code,
	},

	text = {
		xs = 11,
		sm = 13,
		md = 14,
		lg = 17,
		xl = 22,
		xxl = 28,
	},

	space = {
		none = 0,
		xs = 4,
		sm = 8,
		--// (console) layout.paddingX
		md = 12,
		lg = 16,
		--// (console) viewportTopInset — how close a panel comes to the edge
		xl = 24,
		xxl = 32,
	},

	radius = {
		xs = 4,
		sm = 6,
		--// (console) suggestionRadius
		md = 10,
		--// (console) outputRadius — what the pill morphs into
		lg = 12,
		xl = 20,
		pill = 999,
	},

	stroke = {
		hairline = 1,
		thick = 2,
	},

	size = {
		control = 32,
		row = 26,
		--// (console) hintHeight
		hint = 18,
		icon = 18,
		touch = 44,
		bar = 44,
		title = 34,
		thumb = 14,
		rail = 4,
	},

	--// shadow: opt-in. point `image` at your own 9-sliced soft shadow and every
	--// surface picks it up; leave it empty and no shadow instance is created.
	shadow = {
		image = "",
		slice = Rect.new(10, 10, 118, 118),
		color = Color3.fromRGB(0, 0, 0),
		transparency = 0.55,
		spread = 22,
		offset = Vector2.new(0, 3),
	},

	--// motion: `duration` + `easing` tweens, `stiffness` + `damping` springs.
	--// The tween durations are the console's own smooth times; anything whose
	--// target can change mid-flight stays a spring on purpose.
	motion = {
		instant = { duration = 0 },

		--// (console) openSmoothTime / collapseSmoothTime
		enter = { duration = 0.46, easing = "outQuint" },
		exit = { duration = 0.38, easing = "outQuad" },
		hover = { duration = 0.12, easing = "outQuad" },
		press = { duration = 0.07, easing = "outQuad" },
		--// (console) textFadeTime
		fade = { duration = 0.14, easing = "outQuad" },
		--// (console) itemSlideSmoothTime
		item = { duration = 0.18, easing = "outQuad" },

		layout = { stiffness = 190, damping = 24 },
		morph = { stiffness = 210, damping = 26 },
		drag = { stiffness = 420, damping = 34 },
		reveal = { stiffness = 150, damping = 20 },
		snap = { stiffness = 600, damping = 40 },
	},
}
