--!strict

--- A colour picker wired to something that changes as you drag.
---
--- The pairing to notice is `changed` against `committed`. The preview follows
--- every pixel of the drag; the "saved" line only moves when you let go. Doing
--- both from one event gives you either a preview that lags or a hundred writes
--- per drag.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lume = require(ReplicatedStorage.Packages.Lume)

local app = Lume.app({ name = "Trail" })

local live = Lume.value(Color3.fromRGB(126, 170, 255))
local saved = Lume.value("#7EAAFF")

local window = app:panel("window")

window:setTitle("Trail colour")
window:setAnchor("center")
window:setWidth(260)

local picker = window:colorPicker("Pick a colour")

picker:setValue(live:get())

--// preview while dragging
picker:onChanged(function(color)
	live:set(color)
end)

--// and write once, on release
picker:onCommitted(function(color)
	saved:set(`#{string.upper(color:ToHex())}`)
end)

window:divider()

--// setters take a reactive value as happily as a plain one, so the preview
--// needs no handler of its own — it is bound to the same source the picker
--// writes to
window:label("The quick brown fox"):setTextSize(18):setColor(live)

window:label(Lume.format(saved, "saved: %s")):setMuted(true)

window:open()
