require("sw-micro-project.lua.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Base")
require("sw-micro-project.lua.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.FileSystemUtils")

local config = require("sw-micro-project.lua.modules.config")
local project = require("sw-micro-project.lua.modules.project")
local library = require("sw-micro-project.lua.modules.library")
local build = require("sw-micro-project.lua.modules.build")
local commands = require("sw-micro-project.lua.modules.commands")
local love_runner = require("sw-micro-project.lua.modules.love_runner")
local keys = require("sw-micro-project.lua.modules.keys")

local M = {}

-- Export config, project, library, build, and commands functions
M.config = config.config
M.setup = config.setup
M.mark_as_micro_project = project.mark_as_micro_project
M.setup_project_libraries = project.setup_project_libraries
M.get_build_params = project.get_build_params
M.add_library = project.add_library
M.register_libraries_with_lsp = library.register_libraries_with_lsp
M.build_micro_project = build.build_micro_project
M.create_commands = commands.create_commands
M.setup_autodetection = commands.setup_autodetection
M.run_love_ui = love_runner.run_current_script
M.register_keymaps = keys.register_keymaps

  -- Auto-load VSCode-style snippets for LuaSnip (if available)
  pcall(function()
    local ok, loader = pcall(require, 'luasnip.loaders.from_vscode')
    if not (ok and loader and loader.lazy_load) then return end
    local src = debug.getinfo(1, 'S').source or ''
    if src:sub(1,1) == '@' then src = src:sub(2) end
    -- This file is .../lua/sw-micro-project/lua/main.lua
    local script_dir = src:match('(.*/)') or ''
    -- plugin root = .../lua/sw-micro-project/
    local plugin_root = script_dir .. '../'
    -- normalize any /segment/../
    plugin_root = plugin_root:gsub('/%./', '/'):gsub('/[^/]+/%.%./', '/'):gsub('/[^/]+/%.%./', '/')
    local snippets_dir = plugin_root .. 'snippets'
    loader.lazy_load({ paths = { snippets_dir } })
  end)


-- Setup function called by user in their config
function M.setup(user_config)
  -- Setup configuration
  config.setup(user_config)

  -- Create commands
  commands.create_commands()

  -- Setup autodetection
  commands.setup_autodetection()

  -- Register default keymaps and which-key group if available
  keys.register_keymaps()
end

return M
