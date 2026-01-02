require("sw-micro-project.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Base")
require("sw-micro-project.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.FileSystemUtils")

local config = require("sw-micro-project.modules.config")
local project = require("sw-micro-project.modules.project")
local library = require("sw-micro-project.modules.library")
local build = require("sw-micro-project.modules.build")
local commands = require("sw-micro-project.modules.commands")
local love_runner = require("sw-micro-project.modules.love_runner")
local keys = require("sw-micro-project.modules.keys")

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

  -- Load LuaSnip snippets from JSON dynamically (safe if LuaSnip missing)
  local ok, err = pcall(require, "sw-micro-project.snippets.snippets")
  if not ok and vim and vim.notify then
    vim.notify(
      "sw-micro-project: snippets not loaded: " .. tostring(err),
      (vim.log and vim.log.levels and vim.log.levels.WARN) or 3
    )
  end
end

return M
