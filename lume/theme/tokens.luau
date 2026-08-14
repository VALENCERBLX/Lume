--!strict

--[[
	@name tokens
	@module lume/theme/tokens

	The default token set. Every component reads from here, never from
	literals, so a single extend() call restyles the whole tree.
]]

return {
	color = {
		surface = Color3.fromRGB(18, 18, 20),
		surfaceRaised = Color3.fromRGB(26, 26, 29),
		surfaceSunken = Color3.fromRGB(13, 13, 15),
		overlay = Color3.fromRGB(0, 0, 0),

		border = Color3.fromRGB(48, 48, 54),
		borderStrong = Color3.fromRGB(72, 72, 80),

		text = Color3.fromRGB(238, 238, 242),
		textMuted = Color3.fromRGB(146, 146, 158),
		textGhost = Color3.fromRGB(96, 96, 106),

		accent = Color3.fromRGB(126, 170, 255),
		accentMuted = Color3.fromRGB(74, 102, 156),

		success = Color3.fromRGB(137, 255, 126),
		warn = Color3.fromRGB(255, 214, 126),
		danger = Color3.fromRGB(255, 126, 126),
	},

	rich = {
		text = "#EEEEF2",
		muted = "#9292A0",
		accent = "#7EAAFF",
		success = "#89FF7E",
		warn = "#FFD67E",
		danger = "#FF7E7E",
	},

	transparency = {
		surface = 0.08,
		overlay = 0.45,
		border = 0.35,
		text = 0,
		muted = 0.15,
		shadow = 0.55,
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
	},

	space = {
		none = 0,
		xs = 4,
		sm = 8,
		md = 12,
		lg = 16,
		xl = 24,
	},

	radius = {
		sm = 6,
		md = 10,
		lg = 14,
		pill = 999,
	},

	stroke = {
		hairline = 1,
		thick = 2,
	},

	--// shadow: opt-in. point image at a 9-sliced soft shadow asset of your
	--// own and every surface picks it up; empty means no shadow instances.
	shadow = {
		image = "",
		slice = Rect.new(64, 64, 64, 64),
		color = Color3.new(),
		transparency = 0.55,
		spread = 24,
	},

	size = {
		control = 32,
		row = 26,
		hint = 20,
		touch = 44,
	},

	motion = {
		--// tween specs
		instant = { duration = 0 },
		enter = { duration = 0.22, easing = "outQuint" },
		exit = { duration = 0.16, easing = "outQuad" },
		hover = { duration = 0.12, easing = "outQuad" },
		press = { duration = 0.08, easing = "outQuad" },

		--// spring specs: used wherever the target can be retargeted mid-flight
		layout = { stiffness = 190, damping = 24 },
		drag = { stiffness = 320, damping = 30 },
		reveal = { stiffness = 150, damping = 20 },
	},
}
