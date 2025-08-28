-- lua/micro-project/modules/config.lua
-- Configuration and setup functions

local M = {}

-- Plugin configuration with sensible defaults
M.config = {
  -- User-defined library paths
  user_lib_paths = {},
  -- Build command template (can be customized per project)
  build_command = "make",
  -- Project marker files to detect microcontroller projects
  project_markers = { ".microproject" },
  -- Auto-detect projects on startup
  auto_detect = true,
}

-- Internal state
M.current_project = nil
M.project_libs = {}

-- Setup function called by user in their config
function M.setup(user_config)
  -- Merge user config with defaults
  if user_config then
    M.config = vim.tbl_deep_extend("force", M.config, user_config)
  end

  print("Micro-project plugin loaded!")
end

return M
