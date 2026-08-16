--!strict

--- The default token set. Components read from here and never from literals,
--- so one `app:restyle{…}` call restyles the whole tree.
---
--- The palette is a translucent near-black with cool grey type — the console
--- look — but nothing below is load-bearing except the *names*. Swap every
--- colour and the layout, motion and measurement all still hold.
--- @section Theme

return {
	name = "default",

	color = {
		--// surfaces, lightest on top
		surface = Color3.fromRGB(10, 10, 12),
		surfaceRaised = Color3.fromRGB(18, 18, 22),
		surfaceSunken = Color3.fromRGB(6, 6, 8),
		surfaceHover = Color3.fromRGB(28, 28, 34),
		surfaceActive = Color3.fromRGB(38, 38, 46),
		overlay = Color3.fromRGB(0, 0, 0),

		border = Color3.fromRGB(60, 60, 70),
		borderStrong = Color3.fromRGB(96, 96, 112),

		text = Color3.fromRGB(238, 238, 242),
		textMuted = Color3.fromRGB(146, 146, 158),
		textGhost = Color3.fromRGB(96, 96, 106),
		textInverse = Color3.fromRGB(12, 12, 14),

		accent = Color3.fromRGB(126, 170, 255),
		accentMuted = Color3.fromRGB(74, 102, 156),
		accentText = Color3.fromRGB(12, 14, 20),

		success = Color3.fromRGB(126, 226, 150),
		warn = Color3.fromRGB(255, 206, 122),
		danger = Color3.fromRGB(255, 126, 126),

		track = Color3.fromRGB(48, 48, 58),
		selection = Color3.fromRGB(126, 170, 255),
	},

	--// hex mirrors of the palette, for RichText spans
	rich = {
		text = "#EEEEF2",
		muted = "#9292A0",
		ghost = "#60606A",
		accent = "#7EAAFF",
		success = "#7EE296",
		warn = "#FFCE7A",
		danger = "#FF7E7E",
	},

	transparency = {
		surface = 0.08,
		surfaceRaised = 0.04,
		overlay = 0.45,
		border = 0.4,
		text = 0,
		muted = 0.25,
		ghost = 0.45,
		track = 0.3,
		shadow = 0.6,
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
		md = 12,
		lg = 16,
		xl = 24,
		xxl = 32,
	},

	radius = {
		xs = 4,
		sm = 6,
		md = 10,
		lg = 14,
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
		hint = 20,
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
		slice = Rect.new(64, 64, 64, 64),
		color = Color3.fromRGB(0, 0, 0),
		transparency = 0.6,
		spread = 22,
		offset = Vector2.new(0, 4),
	},

	--// motion: `duration` + `easing` tweens, `stiffness` + `damping` springs.
	--// Anything whose target can change mid-flight is a spring on purpose.
	motion = {
		instant = { duration = 0 },

		enter = { duration = 0.22, easing = "outQuint" },
		exit = { duration = 0.16, easing = "outQuad" },
		hover = { duration = 0.12, easing = "outQuad" },
		press = { duration = 0.07, easing = "outQuad" },
		fade = { duration = 0.14, easing = "outQuad" },

		layout = { stiffness = 190, damping = 24 },
		morph = { stiffness = 210, damping = 26 },
		drag = { stiffness = 420, damping = 34 },
		reveal = { stiffness = 150, damping = 20 },
		snap = { stiffness = 600, damping = 40 },
	},
}
