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

  lua_client.rpc.request("workspace/didChangeConfiguration", {
    settings = current_settings,
  }, function(err, _)
    if err then
      print("✗ Failed to update LSP settings: " .. vim.inspect(err))
    else
      print("✓ Updated LSP settings with " .. #current_settings .. " extracted globals")
    end
  end)

  -- Explicitly tell LSP about each library file by "opening" them
  print("📖 Force-loading library files into LSP...")
  local loaded_count = 0

  for _, file_path in ipairs(library_files) do
    -- Read the file content
    local file = io.open(file_path, "r")
    if file then
      local content = file:read("*all")
      file:close()

      -- Tell LSP about this file
      lua_client.rpc.notify("textDocument/didOpen", {
        textDocument = {
          uri = vim.uri_from_fname(file_path),
          languageId = "lua",
          version = 1,
          text = content,
        },
      })

      loaded_count = loaded_count + 1
    end
  end

  --reset the linter
  vim.diagnostic.reset()

  -- Give it a moment then refresh
  vim.defer_fn(function()
    vim.lsp.buf.format({ async = false })
    print("✅ LSP diagnostics refresh complete")
  end, 1000)
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
function M.build_micro_project(single_file)
  if not current_project then
    print("No microcontroller project detected. Run :SetupMicroProject first.")
    return
  end

  print("🚀 Building microcontroller project...")

  require("sw-micro-project.lua.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.Builder")

  -- Determine if this is a microcontroller project
  local is_microcontroller = current_project.config.is_microcontroller ~= false -- default to true

  -- Get build parameters
  local build_params = M.get_build_params(current_project.config)

  local lib_include_paths = { LifeBoatAPI.Tools.Filepath:new(current_project.path) }
  for _, path in ipairs(current_project.config.libraries) do
    table.insert(lib_include_paths, LifeBoatAPI.Tools.Filepath:new(path))
  end

  -- Initialize the builder
  local builder = LifeBoatAPI.Tools.Builder:new(
    lib_include_paths,
    LifeBoatAPI.Tools.Filepath:new(build_params.outputDir),
    LifeBoatAPI.Tools.Filepath:new(STANDARD_LIB_PATH),
    nil
  )

  print(single_file and ("Compiling for single: " .. tostring(single_file) .. "!") or "")

  local lua_files = single_file and { LifeBoatAPI.Tools.Filepath:new(single_file) }
    or LifeBoatAPI.Tools.FileSystemUtils.findFilesRecursive(
      current_project.path,
      { [".vscode"] = 1, ["_build"] = 1, [".git"] = 1 },
      { ["lua"] = 1, ["luah"] = 1 }
    )

  -- Build each Lua file
  for _, file_path in ipairs(lua_files) do
    local relative_path = file_path:linux()
    local build_method = is_microcontroller and "buildMicrocontroller" or "buildAddonScript"
    local originalText, combinedText, finalText, outFile = builder[build_method](
      builder,
      relative_path,
      LifeBoatAPI.Tools.Filepath:new(current_project.path .. file_path:linux()),
      build_params
    )

    print("Built file: " .. file_path:linux() .. " -> " .. tostring(outFile:linux()))
    LifeBoatAPI.Tools.FileSystemUtils.writeAllText(outFile, finalText)
  end

  print("✅ Build process completed successfully.")
end

-- Function to get build parameters from project config
function M.get_build_params(project_config)
  local defaults = {
    luaDocsAddonPath = "../common/addon-docs",
    luaDocsMCPath = "../common/mc-docs",
    outputDir = current_project.path,
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

  -- Save to project config file
  local config_path = vim.fn.getcwd() .. "/.microproject"
  local project_config = load_project_config()
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
    elseif subcommand == "here" then
      M.build_micro_project(string.gsub(vim.api.nvim_buf_get_name(0), vim.loop.cwd(), ""))
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
