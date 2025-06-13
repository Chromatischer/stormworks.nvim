-- lua/micro-project/init.lua
-- Main plugin module

local M = {}

local function get_plugin_directory()
  -- Get the directory where THIS script (init.lua) is located
  local script_path = debug.getinfo(1, "S").source:sub(2) -- Remove the '@' prefix
  local script_dir = script_path:match("(.*/)") -- Extract directory
  return script_dir
end

-- Hardcoded standard library path (relative to plugin directory)
local STANDARD_LIB_PATH = get_plugin_directory() .. "common/nameouschangey/MicroController/microcontroller.lua"

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
local current_project = nil
local project_libs = {}

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
local function detect_micro_project()
  local cwd = vim.fn.getcwd()

  for _, marker in ipairs(M.config.project_markers) do
    local marker_path = cwd .. "/" .. marker
    if file_exists(marker_path) then
      return marker_path, marker
    end
  end

  return nil, nil
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
local function load_project_config()
  local cwd = vim.fn.getcwd()
  local config_path = cwd .. "/.microproject"

  if file_exists(config_path) then
    -- Safely load the project config
    local ok, project_config = pcall(dofile, config_path)
    if ok and type(project_config) == "table" then
      return project_config
    end
  end

  return {}
end

-- Function to add library files to Lua LSP workspace
function M.register_libraries_with_lsp(libraries)
  if not current_project then
    print("No microcontroller project active")
    return
  end
  print("Working on " .. #libraries .. " libraries")
  -- Get all Lua files from project libraries
  local library_files = {}

  for _, lib_path in ipairs(libraries) do
    local lua_files = M.find_lua_files_in_directory(lib_path)
    print("In path: " .. lib_path .. " found: " .. #lua_files .. " files")
    for _, file_path in ipairs(lua_files) do
      table.insert(library_files, file_path)
    end
  end

  if #library_files == 0 then
    print("No library files found to register with LSP")
    return
  end

  -- Get the Lua LSP client
  local clients = vim.lsp.get_clients({ name = "lua_ls" })
  if #clients == 0 then
    print("⚠ Lua LSP (lua_ls) not found. Make sure it's running.")
    return
  end

  local lua_client = clients[1]

  -- Method 1: Update workspace library paths in LSP settings
  local current_settings = lua_client.config.settings or {}
  if not current_settings.Lua then
    current_settings.Lua = {}
  end
  if not current_settings.Lua.workspace then
    current_settings.Lua.workspace = {}
  end

  -- Add library directories (not individual files)
  local library_dirs = {}
  for _, lib_path in ipairs(project_libs) do
    table.insert(library_dirs, lib_path)
  end

  current_settings.Lua.workspace.library = library_dirs
  current_settings.Lua.workspace.checkThirdParty = false
end

-- Helper function to recursively find Lua files in a directory
function M.find_lua_files_in_directory(directory)
  local lua_files = {}

  local function scan_directory(dir)
    local handle = vim.loop.fs_scandir(dir)
    if not handle then
      return
    end

    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end

      local full_path = dir .. "/" .. name

      if type == "directory" then
        -- Recursively scan subdirectories
        scan_directory(full_path)
      elseif type == "file" and name:match("%.lua$") then
        table.insert(lua_files, full_path)
      end
    end
  end

  if file_exists(directory) then
    return { directory }
  end

  scan_directory(directory)
  return lua_files
end

-- Function to setup libraries for the current project
function M.setup_project_libraries()
  local marker_path, marker_type = detect_micro_project()

  if not marker_path then
    print("Not a microcontroller project. Run :MarkAsMicroProject first.")
    return
  end

  current_project = {
    path = vim.fn.getcwd(),
    marker = marker_type,
    config = load_project_config(),
  }

  -- Clear existing project libraries
  project_libs = {}

  -- Add standard library if it exists
  local std_lib = vim.fn.expand(STANDARD_LIB_PATH)
  if file_exists(std_lib) then
    table.insert(project_libs, std_lib)
    print("✓ Added standard microcontroller library: " .. std_lib)
  else
    print("⚠ Standard library not found at: " .. std_lib)
  end

  -- Add user-defined libraries
  for _, lib_path in ipairs(M.config.user_lib_paths) do
    local expanded_path = vim.fn.expand(lib_path)
    if file_exists(expanded_path) then
      table.insert(project_libs, expanded_path)
      print("✓ Added user library: " .. expanded_path)
    end
  end

  -- Add project-specific libraries from config
  if current_project.config.libraries then
    for _, lib_path in ipairs(current_project.config.libraries) do
      local expanded_path = vim.fn.expand(lib_path)
      if dir_exists(expanded_path) then
        table.insert(project_libs, expanded_path)
        print("✓ Added project library: " .. expanded_path)
      end
    end
  end

  print("Microcontroller project setup complete. Libraries: " .. #project_libs)
  M.register_libraries_with_lsp(project_libs)
end

-- Build function for microcontroller projects using LifeBoat API
function M.build_micro_project()
  if not current_project then
    print("No microcontroller project detected. Run :SetupMicroProject first.")
    return
  end

  print("🔧 Generating LifeBoat build script...")

  -- Determine if this is a microcontroller project
  local is_microcontroller = current_project.config.is_microcontroller ~= false -- default to true

  -- Get build parameters
  local build_params = M.get_build_params(current_project.config)

  -- Generate the dynamic build script
  local build_script = M.generate_build_script(current_project.path, is_microcontroller, build_params)

  -- Write build script to temporary file
  local temp_script_path = current_project.path .. "/_build_temp.lua"
  local temp_file = io.open(temp_script_path, "w")
  if not temp_file then
    print("✗ Failed to create temporary build script")
    return
  end

  temp_file:write(build_script)
  temp_file:close()

  -- Prepare build arguments
  local args = {
    vim.fn.expand(build_params.luaDocsAddonPath),
    vim.fn.expand(build_params.luaDocsMCPath),
    vim.fn.expand(build_params.outputDir),
    build_params.boilerPlate,
    tostring(build_params.reduceAllWhitespace),
    tostring(build_params.reduceNewlines),
    tostring(build_params.removeRedundancies),
    tostring(build_params.shortenVariables),
    tostring(build_params.shortenGlobals),
    tostring(build_params.shortenNumbers),
    tostring(build_params.forceNCBoilerplate),
    tostring(build_params.forceBoilerplate),
    tostring(build_params.shortenStringDuplicates),
    tostring(build_params.removeComments),
    tostring(build_params.skipCombinedFileOutput),
  }

  -- Add root directories (current project)
  table.insert(args, current_project.path)

  -- Build the lua command
  local lua_cmd = "lua " .. temp_script_path .. " " .. table.concat(args, " ")

  print("🚀 Building " .. (is_microcontroller and "microcontroller" or "addon") .. " project...")

  -- Create a new terminal buffer for build output
  vim.cmd("botright new")
  vim.cmd("resize 15")

  -- Execute the build command in the terminal
  local job_id = vim.fn.termopen(lua_cmd, {
    cwd = current_project.path,
    on_exit = function(_, exit_code)
      -- Clean up temp file
      os.remove(temp_script_path)

      if exit_code == 0 then
        print("✅ LifeBoat build successful!")
      else
        print("❌ LifeBoat build failed with exit code: " .. exit_code)
      end
    end,
  })

  if job_id == 0 then
    print("✗ Failed to start LifeBoat build process")
    os.remove(temp_script_path)
  end
end

-- Function to generate dynamic build script
function M.generate_build_script(project_path, is_microcontroller, build_params)
  local script_content = [[
--- @diagnostic disable: undefined-global

require("LifeBoatAPI.Tools.Build.Builder")

-- replace newlines
for k,v in pairs(arg) do
    arg[k] = v:gsub("##LBNEWLINE##", "\n")
end

local luaDocsAddonPath  = LifeBoatAPI.Tools.Filepath:new(arg[1]);
local luaDocsMCPath     = LifeBoatAPI.Tools.Filepath:new(arg[2]);
local outputDir         = LifeBoatAPI.Tools.Filepath:new(arg[3]);
local params            = {
    boilerPlate             = arg[4],
    reduceAllWhitespace     = arg[5] == "true",
    reduceNewlines          = arg[6] == "true",
    removeRedundancies      = arg[7] == "true",
    shortenVariables        = arg[8] == "true",
    shortenGlobals          = arg[9] == "true",
    shortenNumbers          = arg[10]== "true",
    forceNCBoilerplate      = arg[11]== "true",
    forceBoilerplate        = arg[12]== "true",
    shortenStringDuplicates = arg[13]== "true",
    removeComments          = arg[14]== "true",
    skipCombinedFileOutput  = arg[15]== "true"
};
local rootDirs          = {};

for i=15, #arg do
    table.insert(rootDirs, LifeBoatAPI.Tools.Filepath:new(arg[i]));
end

local _builder = LifeBoatAPI.Tools.Builder:new(rootDirs, outputDir, luaDocsMCPath, luaDocsAddonPath)

local combinedText, outText, outFile

if onLBBuildStarted then onLBBuildStarted(_builder, params, LifeBoatAPI.Tools.Filepath:new("]] .. project_path .. [[")) end
]]

  -- Find all .lua files in project (excluding build directories)
  local exclude_patterns = {
    "_build",
    "out",
    ".vscode",
    "_examples_and_tutorials",
    ".git",
    "node_modules",
    "target",
  }

  local function should_exclude(path)
    for _, pattern in ipairs(exclude_patterns) do
      if path:find(pattern) then
        return true
      end
    end
    return false
  end

  -- Recursively find .lua files
  local function find_lua_files(dir, files)
    files = files or {}
    local handle = vim.loop.fs_scandir(dir)

    if handle then
      while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then
          break
        end

        local full_path = dir .. "/" .. name

        if type == "directory" and not should_exclude(full_path) then
          find_lua_files(full_path, files)
        elseif type == "file" and name:match("%.lua$") and not should_exclude(full_path) then
          table.insert(files, full_path)
        end
      end
    end

    return files
  end

  local lua_files = find_lua_files(project_path)

  -- Generate build commands for each file
  for _, file_path in ipairs(lua_files) do
    local relative_path = file_path:gsub("^" .. project_path .. "/", "")

    local build_method = is_microcontroller and "buildMicrocontroller" or "buildAddonScript"

    script_content = script_content
      .. string.format(
        [[

if onLBBuildFileStarted then onLBBuildFileStarted(_builder, params, LifeBoatAPI.Tools.Filepath:new("%s"), "%s", LifeBoatAPI.Tools.Filepath:new("%s")) end

combinedText, outText, outFile = _builder:%s("%s", LifeBoatAPI.Tools.Filepath:new("%s"), params)

if onLBBuildFileComplete then onLBBuildFileComplete(LifeBoatAPI.Tools.Filepath:new("%s"), "%s", LifeBoatAPI.Tools.Filepath:new("%s"), outFile, combinedText, outText) end
]],
        project_path,
        relative_path,
        file_path,
        build_method,
        relative_path,
        file_path,
        project_path,
        relative_path,
        file_path
      )
  end

  -- Check for custom build actions
  local build_actions_path = project_path .. "/_build/_buildactions.lua"
  if file_exists(build_actions_path) then
    script_content = script_content .. '\nrequire("_build._buildactions")\n'
  end

  -- Add completion hook
  script_content = script_content
    .. string.format(
      [[

if onLBBuildComplete then onLBBuildComplete(_builder, params, LifeBoatAPI.Tools.Filepath:new("%s")) end
--- @diagnostic enable: undefined-global
]],
      project_path
    )

  return script_content
end

-- Function to get build parameters from project config
function M.get_build_params(project_config)
  local defaults = {
    luaDocsAddonPath = "../common/addon-docs",
    luaDocsMCPath = "../common/mc-docs",
    outputDir = "_build/out",
    boilerPlate = "default",
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
  }

  -- Merge with project-specific settings
  if project_config.build_params then
    return vim.tbl_deep_extend("force", defaults, project_config.build_params)
  end

  return defaults
end

-- Function to add a library to the current project
function M.add_library(lib_path)
  if not current_project then
    print("No microcontroller project active")
    return
  end

  local expanded_path = vim.fn.expand(lib_path)
  if not dir_exists(expanded_path) then
    print("✗ Library path does not exist: " .. expanded_path)
    return
  end

  -- Add to current session
  table.insert(project_libs, expanded_path)

  -- TODO: Save to project config file
  print("✓ Added library: " .. expanded_path)
end

-- Setup function called by user in their config
function M.setup(user_config)
  -- Merge user config with defaults
  if user_config then
    M.config = vim.tbl_deep_extend("force", M.config, user_config)
  end

  -- Create unified command with subcommands
  vim.api.nvim_create_user_command("MicroProject", function(opts)
    local subcommand = opts.fargs[1]

    if subcommand == "mark" then
      M.mark_as_micro_project()
    elseif subcommand == "setup" then
      M.setup_project_libraries()
    elseif subcommand == "build" then
      M.build_micro_project()
    elseif subcommand == "add" then
      if opts.fargs[2] then
        M.add_library(opts.fargs[2])
      else
        print("Usage: :MicroProject add <library_path>")
      end
    else
      print("Available subcommands:")
      print("  :MicroProject mark     - Mark current directory as microcontroller project")
      print("  :MicroProject setup    - Setup project libraries")
      print("  :MicroProject build    - Build the project")
      print("  :MicroProject add <path> - Add library to project")
    end
  end, {
    nargs = "*",
    complete = function(_, line, _)
      local parts = vim.split(line, "%s+")

      -- Complete subcommands
      if #parts <= 2 then
        local subcommands = { "mark", "setup", "build", "add" }
        local partial = parts[2] or ""
        return vim.tbl_filter(function(cmd)
          return cmd:find("^" .. partial)
        end, subcommands)
      end

      -- Complete directory paths for "add" subcommand
      if parts[2] == "add" and #parts == 3 then
        return vim.fn.getcompletion(parts[3] or "", "dir")
      end

      return {}
    end,
  })

  -- Auto-detect projects when entering directories
  if M.config.auto_detect then
    vim.api.nvim_create_autocmd({ "DirChanged", "VimEnter" }, {
      callback = function()
        local marker_path = detect_micro_project()
        if marker_path then
          M.setup_project_libraries()
        end
      end,
    })
  end

  print("Micro-project plugin loaded!")
end

return M
