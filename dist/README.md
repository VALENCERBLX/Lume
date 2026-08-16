# dist/

`install.luau` is a single self-contained build of the library. It carries every
module's source and creates the instance tree in your place — no Rojo, no manual
copying.

## Install from Studio

Paste one line into the **command bar**:

```lua
loadstring(game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/VALENCERBLX/Lume/master/dist/install.luau"))()
```

Requirements:

* **Game Settings → Security → Allow HTTP Requests** on,
* run it from the **command bar** or a **plugin** — `ModuleScript.Source` is not
  writable from an ordinary script, and the installer says so if you try.

The installer builds under `ReplicatedStorage` by default, replaces any previous
install, stamps `LumeVersion` / `LumeInstalledAt` attributes on the root, and
selects it in the Explorer.

## Options

Set these before running:

```lua
_G.LumeInstall = {
    parent    = game:GetService("ReplicatedStorage"), -- where to build
    name      = "Lume",                               -- root instance name
    overwrite = true,                                 -- replace an existing install
    select    = true,                                 -- select the root when done
    silent    = false,                                -- suppress output
}

loadstring(game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/VALENCERBLX/Lume/master/dist/install.luau"))()
```

## What you get

```
ReplicatedStorage
└── Lume                (ModuleScript)
    ├── Types  Text  App
    ├── Core/           Scope · Signal · State · Create · Node
    ├── Theme           (ModuleScript) → Tokens
    ├── Motion          (ModuleScript) → Easing · Spring
    ├── Layout/         Measure · Placement · Autosize · Virtual · Stack
    ├── Input/          Drag · Focus · Hover · Keys
    ├── Panel           (ModuleScript) → Chrome · Presets
    └── Elements        (ModuleScript) → Label · Icon · Button · Field ·
                        Toggle · Slider · Select · List · Divider · Spacer ·
                        Group · Progress · Tabs · Chips · Suggest · Menu ·
                        Badge · Scroll · Keybind
```

```lua
local Lume = require(game:GetService("ReplicatedStorage").Lume)

local app = Lume.app({ name = "Inspector" })

app:panel("window")
    :setTitle("Inspector")
    :setAnchor("bottomRight")
    :open()
```

## Regenerating

`install.luau` is **generated** from `src/`; do not hand-edit it. The packer
walks the tree, turns folders-with-an-`init` into ModuleScripts, and inlines
each source into the manifest. Edit `src/`, repack, commit both:

```sh
lune run scripts/build-installer
```

The build self-checks that the bundle compiles before writing it.

MIT. Original console UI by driftingAurora, dullflowerr, alias, kioukaii.
