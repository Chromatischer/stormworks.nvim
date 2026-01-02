# stormworks.nvim

A Neovim plugin that streamlines Stormworks microcontroller and addon script development. It bundles helpers and build tooling inspired by the excellent Stormworks VSCode ecosystem, adds a convenient LÖVE2D-based UI runner, and integrates with lua-language-server for a smooth editing experience.

- Single-file or project-wide builds using LifeBoatAPI tools
- Project discovery via a lightweight .microproject file
- Library management and automatic LSP (lua_ls) "workspace.library" registration
- Optional keymaps and which-key integration
- LÖVE2D UI runner for quickly testing your script logic and screens

> Huge thanks to nameouschangey for the original Stormworks VSCode extension that this plugin heavily builds upon: https://github.com/nameouschangey/Stormworks_VSCodeExtension.git


## Requirements

- Neovim 0.9+ (tested with recent versions)
- lua-language-server (lua_ls)
- LÖVE2D 11.x installed and on PATH
  - macOS users can also set a direct path to the app binary


## Installation
Using lazy.nvim:

```lua
return {
  "Chromatischer/stormworks.nvim",
  config = function()
    require("stormworks").setup({})
  end,
}
```
## Quick start

1) Mark your current directory as a Stormworks microcontroller project:

```vim
:MicroProject mark
```

2) Add additional library folders (top-level dirs you want included):

```vim
:MicroProject add /absolute/path/to/your/library
:MicroProject setup
```

3) Build the project (entire tree) or only the current file:

```vim
:MicroProject build   " builds the whole project
:MicroProject here    " builds just the current buffer
```

4) Run the LÖVE2D UI against the current buffer:

```vim
:MicroProject ui [--tiles 3x2] [--tick 60] [--scale 3] [--debug-canvas true] [--props k=v,k2=v2] [--log-file /path/to/log.txt] [--log-truncate]
```

- --tiles: grid of Stormworks screens, e.g. 3x2
- --tick:  tick rate for the simulation (per second)
- --scale: pixel scale for the window
- --debug-canvas: true/false to show an extra debug canvas
- --props: comma-separated custom properties (k=v)


## Commands

- :MicroProject mark
  - Creates a `.microproject` file in the project root with sensible defaults.
- :MicroProject setup
  - Reads `.microproject`, collects libraries, and registers them with lua_ls.
- :MicroProject add <path>
  - Adds a top-level library path to your project and saves it into `.microproject`.
- :MicroProject build
  - Builds all Lua files in the project using LifeBoatAPI’s Builder (microcontroller by default).
- :MicroProject here
  - Builds only the current buffer file.
- :MicroProject ui [...flags]
  - Launches the bundled LÖVE2D UI pointed at the current buffer with optional flags.

The `.microproject` file is a small Lua table the plugin writes/reads, for example:

```lua
-- .microproject
return {
  name = "my-scripts",
  is_microcontroller = true,
  libraries = { "/abs/path/to/lib1", "/abs/path/to/lib2" },
  build_params = {
    -- LifeBoat build options
    reduceAllWhitespace = true,
    reduceNewlines = true,
    removeRedundancies = true,
    removeComments = true,
    shortenStringDuplicates = true,
    stripOnDebugDraw = true,
    shortenVariables = true,
    shortenGlobals = true,
    shortenNumbers = true,
  },
}
```


## Configuration

Configure via `setup()`. Defaults are shown below:

```lua
require("stormworks").setup({
  -- User-defined library paths included for all projects
  user_lib_paths = {},

  -- Marker files to detect a Stormworks project
  project_markers = { ".microproject" },

  -- Auto-detect projects when LSP (lua_ls) first attaches
  auto_detect = true,

  -- Keymaps and which-key integration
  enable_keymaps = true,
  which_key_prefix = "<leader>S",
  keymaps = {
    mark = "m",   -- :MicroProject mark
    setup = "l",  -- :MicroProject setup (libraries)
    build = "b",  -- :MicroProject build
    here  = "h",  -- :MicroProject here
    ui    = "r",  -- :MicroProject ui (run with LÖVE)
    add   = "a",  -- :MicroProject add
  },

  -- LÖVE2D binary discovery
  love_command = "love",                           -- use PATH if available
  love_macos_path = "/Applications/love.app/Contents/MacOS/love", -- macOS fallback
})
```

Notes:
- The plugin will attempt to update the running lua_ls client’s `workspace.library` setting so that your libraries are recognized for completion and diagnostics. If a `.luarc.json` exists in your project root, the plugin tries to preserve its structure and only adjusts the library section.
- The standard LifeBoat microcontroller library is bundled and automatically included when available.


## Keymaps (optional)

If enabled, the following default mappings are provided under `<leader>S`:

- `<leader>Sm` → :MicroProject mark
- `<leader>Sl` → :MicroProject setup
- `<leader>Sb` → :MicroProject build
- `<leader>Sh` → :MicroProject here
- `<leader>Sr` → :MicroProject ui (run with LÖVE)
- `<leader>Sa` → prompt to add a library path

If you use which-key, a "MicroProject" group will be registered automatically.


## How building works

The plugin uses LifeBoatAPI’s Builder to compile your Lua files for Stormworks. By default it assumes a microcontroller project (`is_microcontroller = true`). You can toggle addon-style builds by setting `is_microcontroller = false` in `.microproject`.

Current status:
- Single-threaded build path is used by default.
- Multithreaded builds are planned.
- Addon build flow is on the roadmap.
 - By default, any user-defined `onDebugDraw()` or `onAttatch()` function is stripped from compiled output. You can override this by setting `stripOnDebugDraw = false` or `stripOnAttatch = false` in your project's `build_params`.


## Troubleshooting

- LÖVE2D not found: set `love_command` or `love_macos_path` in setup.
- lua_ls not updating libraries: ensure lua-language-server is attached to your project; open a Lua file within the project root.
- Standard library missing: the plugin expects the bundled LifeBoat microcontroller library to be present. If you customized the plugin layout, ensure it remains in `lua/common/nameouschangey/MicroController/microcontroller.lua`.


## Credits and licenses

- Core build tooling and many utilities are adapted from or inspired by the Stormworks VSCode Extension by nameouschangey — thank you for the amazing work!
  - Repository: https://github.com/nameouschangey/Stormworks_VSCodeExtension.git
  - Portions of this plugin include code under the original author’s licensing; see the upstream repository for details.

- Iconography: Material Icons / Material Symbols from Google Fonts
  - Source: https://fonts.google.com/icons
  - Copyright: © Google LLC
  - License: Apache License 2.0 (see: https://www.apache.org/licenses/LICENSE-2.0)
  - Attribution: "Material Icons by Google" (icons included in the LÖVE UI are derived from Google Fonts)

- This repository is licensed under the MIT License (see LICENSE). Third-party assets and code may be under their respective licenses as noted above.


## Contributing

Issues and pull requests are welcome. If you’re proposing larger changes, please open an issue first to discuss the approach.

  - Additionally supports multiple --lib <path> flags to whitelist module roots for 'require' inside the simulator. Defaults to including the script's directory, the project root, and bundled Common libraries.

## Input Simulator (via onAttatch)

You can define an input simulator module and attach it through your microcontroller script’s `onAttatch()` to programmatically drive inputs each tick, before your `onTick()` runs. This is useful for automated testing, synthetic signals, or reproducing scenarios.

- In your MC script:

```lua
function onAttatch()
  return {
    input_simulator = require('simulators.wave_and_toggle'),
    input_simulator_config = { amplitude = 1.0, freq_hz = 0.5, target_num = 1, target_bool = 1 },
    debugCanvas = true,
    debugCanvasSize = { w = 320, h = 120 },
  }
end
```

- Simulator module interface:
  - function form: returns a function(ctx) to be called every tick
  - table form: `{ onInit(ctx, cfg?), onTick(ctx), onDebugDraw?() }`

- Context (ctx):
  - `ctx.input.setBool(ch, v)`, `ctx.input.setNumber(ch, v)` — writes to the input channels (1..32)
  - `ctx.input.getBool(ch)`, `ctx.input.getNumber(ch)` — reads current inputs
  - `ctx.properties` — read-only view of `state.properties`
  - `ctx.time.getDelta()` — per-tick delta time

- Debug canvas: If `debugCanvas` is enabled, the simulator may implement `onDebugDraw()` to draw with the `dbg.*` API.

- UI reflection: The simulator mutates the same `state.inputB/N` the UI uses; changes appear in the Inputs panel automatically.

- Hot reload: Edits to the MC or simulator will be picked up on reload; `onInit` is called after reload.

### Writing an Input Simulator

There are two supported styles: a function-form simulator or a table-form simulator.

1) Function-form (simplest)

```lua
-- simulators/my_sim.lua
---@param ctx SimulatorCtx
return function(ctx)
  -- Called every tick before your microcontroller's onTick()
  -- Write to inputs:
  ctx.input.setBool(1, true)
  ctx.input.setNumber(1, math.sin(love.timer.getTime()))
end
```

Attach it in your MC script:
```lua
---@type InputSimulator
local sim = require('simulators.my_sim')

function onAttatch()
  return {
    input_simulator = sim,
  }
end
```

2) Table-form (lifecycle + debug drawing)

```lua
-- simulators/my_adv_sim.lua
---@class MyAdvSim : InputSimulatorTable
local M = { t = 0 }

---@param ctx SimulatorCtx
---@param cfg table|nil
function M.onInit(ctx, cfg)
  -- Optional, runs once on load and on reload
  M.freq = (cfg and tonumber(cfg.freq_hz)) or 1.0
  M.chN = (cfg and tonumber(cfg.num_ch)) or 1
  M.chB = (cfg and tonumber(cfg.bool_ch)) or 1
end

---@param ctx SimulatorCtx
function M.onTick(ctx)
  local dt = ctx.time.getDelta()
  M.t = M.t + dt
  local v = math.sin(2*math.pi*M.freq*M.t)
  ctx.input.setNumber(M.chN, v)     -- no clamp (can be any numeric range)
  ctx.input.setBool(M.chB, v > 0)   -- derived boolean
end

-- Optional: draws to Debug canvas (if enabled)
function M.onDebugDraw()
  dbg.setColor(0,255,0)
  local w, h = dbg.getWidth(), dbg.getHeight()
  local cx, cy = w/2, h/2
  dbg.drawLine(cx-20, cy, cx+20, cy)
end

return M
```

Attach with configuration:
```lua
---@type InputSimulator
local sim = require('simulators.my_adv_sim')

function onAttatch()
  return {
    input_simulator = sim,
    input_simulator_config = {
      freq_hz = 0.5,
      num_ch = 2,
      bool_ch = 1
    },
    debugCanvas = true,
    debugCanvasSize = { w = 256, h = 128 },
  }
end
```

Notes and best practices
- Simulator order: The simulator’s onTick(ctx) runs before your microcontroller’s onTick().
- Input ranges: ctx.input.setNumber does not clamp — you can write any number. The Inputs panel sliders still range 0..1 for manual user input.
- UI reflection: Values written by the simulator show up in Inputs panel (same data source).
- Debug drawing: If you set debugCanvas = true, implement onDebugDraw and use dbg.* to draw overlays.
- Reload: Editing either the microcontroller or the simulator triggers a reload; onInit(ctx, cfg) runs again.
- Require paths: Your simulator module must be discoverable via:
  - The microcontroller script’s directory (auto-whitelisted), or
  - Any extra paths passed using :MicroProject ui --lib /path or added via :MicroProject add.
- LSP hinting: The repository ships with type stubs for the simulator and context so lua-language-server provides completions. See:
  - lua/common/chromatischer/LspHinting/simulator.lua
  - lua/common/chromatischer/LspHinting/love.lua
