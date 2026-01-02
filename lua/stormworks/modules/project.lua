-- lua/micro-project/modules/project.lua
-- Project detection and management functions

local config = require("stormworks.modules.config")

local M = {}

local function get_plugin_directory()
  -- Get the directory where THIS script (init.lua) is located
  local script_path = debug.getinfo(1, "S").source:sub(2) -- Remove the '@' prefix
  local script_dir = script_path:match("(.*/)") -- Extract directory
  return script_dir
end

-- Hardcoded standard library path (relative to plugin directory)
local STANDARD_LIB_PATH = get_plugin_directory() .. "../common/nameouschangey/MicroController/microcontroller.lua"
local LOVE_LIB_PATH = get_plugin_directory() .. "../common/chromatischer/LspHinting/love.lua"
local SIM_LIB_PATH  = get_plugin_directory() .. "../common/chromatischer/LspHinting/simulator.lua"

-- Utility function to check if file exists
local function file_exists(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == "file"
end

-- Utility function to check if directory exists
local function dir_exists(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == "directory"
end

-- Function to detect if current directory is a microcontroller project
function M.detect_micro_project()
  -- Prefer searching from current buffer's directory; fallback to CWD
  local buf = vim.api and vim.api.nvim_buf_get_name and vim.api.nvim_buf_get_name(0) or ""
  local start_dir = (buf and #buf > 0) and vim.fn.fnamemodify(buf, ":p:h") or vim.fn.getcwd()

  local function parent_dir(path)
    local p = path:gsub("/+$", "")
    local parent = p:match("^(.*)/[^/]+$")
    return parent
  end
  local dir = start_dir
  while dir and #dir > 0 do
    for _, marker in ipairs(config.config.project_markers) do
      local marker_path = dir .. "/" .. marker
      if file_exists(marker_path) then
        return marker_path, marker, dir
      end
    end
    local up = parent_dir(dir)
    if not up or up == dir then break end
    dir = up
  end
  return nil, nil, nil
end

-- Function to mark current project as microcontroller project
function M.mark_as_micro_project()
  local cwd = vim.fn.getcwd()
  local marker_path = cwd .. "/.microproject"

  -- Create the marker file
  local file = io.open(marker_path, "w")
  if file then
    -- Write basic project config
    file:write("-- Microcontroller Project Configuration\n")
    file:write("return {\n")
    file:write('  name = "' .. vim.fn.fnamemodify(cwd, ":t") .. '",\n')
    file:write('  created = "' .. os.date("%Y-%m-%d %H:%M:%S") .. '",\n')
    file:write("  is_microcontroller = true,\n")
    file:write("  libraries = {},\n")
    file:write("  build_params = {\n")
    file:write("    -- LifeBoat build optimization settings\n")
    file:write("    reduceAllWhitespace = true,\n")
    file:write("    reduceNewlines = true,\n")
    file:write("    removeRedundancies = true,\n")
    file:write("    removeComments = true,\n")
    file:write("    shortenStringDuplicates = true,\n")
    file:write("    -- Do not include debug-only draw code in compiled output\n")
    file:write("    stripOnDebugDraw = true,\n")
    file:write("    -- More aggressive optimizations (enabled by default)\n")
    file:write("    shortenVariables = true,\n")
    file:write("    shortenGlobals = true,\n")
    file:write("    shortenNumbers = true\n")
    file:write("  }\n")
    file:write("}\n")
    file:close()

    print("✓ Marked '" .. vim.fn.fnamemodify(cwd, ":t") .. "' as microcontroller project")
    M.setup_project_libraries()
  else
    print("✗ Failed to create .microproject file")
  end
end

-- Function to load project configuration
local function load_project_config(project_root)
  local base = project_root or (config.current_project and config.current_project.path) or vim.fn.getcwd()
  local config_path = base .. "/.microproject"

  if file_exists(config_path) then
    -- Safely load the project config
    local ok, project_config = pcall(dofile, config_path)
    if ok and type(project_config) == "table" then
      return project_config
    end
  end

  return {}
end

-- Function to setup libraries for the current project
function M.setup_project_libraries()
  local marker_path, marker_type, project_root = M.detect_micro_project()

  if not marker_path then
    print("Not a microcontroller project. Run :MarkAsMicroProject first.")
    return
  end

  config.current_project = {
    path = project_root,
    marker = marker_type,
    config = load_project_config(project_root),
  }

  -- Clear existing project libraries
  config.project_libs = {}

  -- Add standard library if it exists
  local std_lib = vim.fn.expand(STANDARD_LIB_PATH)
  if file_exists(std_lib) then
    table.insert(config.project_libs, std_lib)
    print("✓ Added standard microcontroller library: " .. std_lib)
  else
    print("⚠ Standard library not found at: " .. std_lib)
    error("StdLib not found at: " .. std_lib)
  end
  -- Add debug canvas API stubs for IntelliSense
  local dbg_lib = vim.fn.expand(LOVE_LIB_PATH)
  if file_exists(dbg_lib) then
    table.insert(config.project_libs, dbg_lib)
    print("✓ Added debug library: " .. dbg_lib)
  else
    print("⚠ Debug library not found at: " .. dbg_lib)
  end
  -- Add simulator context type stubs for IntelliSense
  local sim_lib = vim.fn.expand(SIM_LIB_PATH)
  if file_exists(sim_lib) then
    table.insert(config.project_libs, sim_lib)
    print("✓ Added simulator hint library: " .. sim_lib)
  else
    print("⚠ Simulator hint library not found at: " .. sim_lib)
  end

  -- Add user-defined libraries
  for _, lib_path in ipairs(config.config.user_lib_paths) do
    local expanded_path = vim.fn.expand(lib_path)
    if file_exists(expanded_path) then
      table.insert(config.project_libs, expanded_path)
      print("✓ Added user library: " .. expanded_path)
    end
  end

  -- Add project-specific libraries from config
  if config.current_project.config.libraries then
    for _, lib_path in ipairs(config.current_project.config.libraries) do
      local expanded_path = vim.fn.expand(lib_path)
      if dir_exists(expanded_path) then
        table.insert(config.project_libs, expanded_path)
        print("✓ Added project library: " .. expanded_path)
      end
    end
  end

  print("Microcontroller project setup complete. Libraries: " .. #config.project_libs)
  require("stormworks.modules.library").register_libraries_with_lsp(config.project_libs, { persist = true })
end

-- Function to get build parameters from project config
function M.get_build_params(project_config)
  assert(config.current_project ~= nil, "current_project is nil but it should definetly not be that way!")
  local defaults = {
    luaDocsAddonPath = "../common/addon-docs",
    luaDocsMCPath = "../common/mc-docs",
    outputDir = config.current_project.path,
    boilerPlate = "",
    reduceAllWhitespace = true,
    reduceNewlines = true,
    removeRedundancies = true,
    shortenVariables = false,
    shortenGlobals = false,
    shortenNumbers = false,
    forceNCBoilerplate = false,
    forceBoilerplate = false,
    shortenStringDuplicates = true,
    removeComments = true,
    skipCombinedFileOutput = false,
    -- By default, omit/neutralize user onDebugDraw() and onAttatch() code from compiled output
    stripOnDebugDraw = true,
    stripOnAttatch = true,
  }

  -- Merge with project-specific settings
  if project_config.build_params then
    return vim.tbl_deep_extend("force", defaults, project_config.build_params)
  end

  return defaults
end

-- Function to add a library to the current project
function M.add_library(lib_path)
  if not config.current_project then
    print("No microcontroller project active")
    return
  end

  local expanded_path = vim.fn.expand(lib_path)
  if not dir_exists(expanded_path) then
    print("✗ Library path does not exist: " .. expanded_path)
    return
  end

  -- Add to current session
  table.insert(config.project_libs, expanded_path)

  -- Save to project config file
  local project_root = assert(config.current_project and config.current_project.path, "No active project root")
  local config_path = project_root .. "/.microproject"
  local project_config = load_project_config(project_root)
  project_config.libraries = project_config.libraries or {}
  table.insert(project_config.libraries, expanded_path)

  local file = io.open(config_path, "w")
  if file then
    file:write("-- Microcontroller Project Configuration\n")
    file:write("return " .. vim.inspect(project_config))
    file:close()
    print("✓ Saved library to project config file: " .. expanded_path)
  else
    print("✗ Failed to save library to project config")
  end
end

return M
