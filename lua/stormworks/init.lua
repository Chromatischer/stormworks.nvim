require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.Base")
require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Utils.FileSystemUtils")

local config = require("stormworks.modules.config")
local project = require("stormworks.modules.project")
local library = require("stormworks.modules.library")
local build = require("stormworks.modules.build")
local commands = require("stormworks.modules.commands")
local love_runner = require("stormworks.modules.love_runner")
local keys = require("stormworks.modules.keys")

local M = {}

-- Export config, project, library, build, and commands functions
M.config = config.config
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
	config.setup(user_config)

	commands.create_commands()

	commands.setup_autodetection()

	keys.register_keymaps()

	-- Load LuaSnip snippets from JSON dynamically (safe if LuaSnip missing)
	local ok, err = pcall(require, "stormworks.snippets.snippets")
	if not ok and vim and vim.notify then
		vim.notify("stormworks: snippets not loaded: " .. tostring(err), vim.log.levels.INFO)
	end
end

return M
