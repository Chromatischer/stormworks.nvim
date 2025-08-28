require("sw-micro-project.lua.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Base")
require("sw-micro-project.lua.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.FileSystemUtils")

local config = require("sw-micro-project.lua.modules.config")
local project = require("sw-micro-project.lua.modules.project")
local library = require("sw-micro-project.lua.modules.library")
local build = require("sw-micro-project.lua.modules.build")
local commands = require("sw-micro-project.lua.modules.commands")

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

-- Setup function called by user in their config
function M.setup(user_config)
  -- Setup configuration
  config.setup(user_config)

  -- Create commands
  commands.create_commands()

  -- Setup autodetection
  commands.setup_autodetection()
end

return M
