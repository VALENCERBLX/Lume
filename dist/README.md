# dist/

`install.luau` is a single self-contained build of the engine. It carries every
module's source and creates the instance tree in your place — no Rojo, no
manual copying.

## Install from Studio

Paste one line into the **command bar**:

```lua
loadstring(game:GetService("HttpService"):GetAsync("https://RAW_HOST/USER/REPO/main/dist/install.luau"))()
```

Replace the URL with the raw URL of this file in your repo. Requirements:

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
    name      = "lume",                               -- root instance name
    overwrite = true,                                 -- replace an existing install
    select    = true,                                 -- select the root when done
    silent    = false,                                -- suppress output
}

loadstring(game:GetService("HttpService"):GetAsync("https://RAW_HOST/USER/REPO/main/dist/install.luau"))()
```

## What you get

```
ReplicatedStorage
└── lume                (ModuleScript)
    ├── app  types  text
    ├── core/           signal · scope · state · create · handle
    ├── theme           (ModuleScript) → tokens
    ├── motion          (ModuleScript) → easing · spring · lerp
    ├── layout/         measure · autosize · placement · virtual
    ├── input/          drag · focus · keys
    └── components      (ModuleScript) → surface · window · modal · tooltip ·
                        button · toggle · slider · select · field · chips ·
                        suggest · tabs · list
```

```lua
local Lume = require(game:GetService("ReplicatedStorage").lume)

local app = Lume.app({ name = "Inspector" })
local window = app:window({ title = "Inspector", width = 320 })
```

## Regenerating

`install.luau` is **generated** from the `lume/` source tree; do not hand-edit
it. The packer walks `lume/`, rewrites the string requires (`require("./state")`)
into Roblox instance requires (`require(script.Parent.state)`), and inlines each
source into the manifest. Edit `lume/`, repack, commit both.

MIT. Original console UI by driftingAurora, dullflowerr, alias, kioukaii.
