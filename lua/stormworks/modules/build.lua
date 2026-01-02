-- lua/micro-project/modules/build.lua
-- Build system functions

local config = require("stormworks.modules.config")
local project = require("stormworks.modules.project")

local MT_AVAILABILITY = false

if not MT_AVAILABILITY then
  vim.notify("Multithread not available, proceeding single threaded", vim.log.levels.WARN)
end

local M = {}

local function get_plugin_directory()
  -- Get the directory where THIS script (init.lua) is located
  local script_path = debug.getinfo(1, "S").source:sub(2) -- Remove the '@' prefix
  local script_dir = script_path:match("(.*/)") -- Extract directory
  return script_dir
end

-- Hardcoded standard library path (relative to plugin directory)
local STANDARD_LIB_PATH = get_plugin_directory() .. "../common/nameouschangey/MicroController/microcontroller.lua"

-- Build function for microcontroller projects using LifeBoat API
function M.build_micro_project(single_file)
  if not config.current_project then
    print("No microcontroller project detected. Run :SetupMicroProject first.")
    return
  end

  print("🚀 Building microcontroller project...")

  require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.Builder")

  -- Determine if this is a microcontroller project
  local is_microcontroller = config.current_project.config.is_microcontroller ~= false -- default to true

  -- Get build parameters
  local build_params = project.get_build_params(config.current_project.config)

  -- Build include roots for the combiner
  -- Include project root, each configured library path, and the parent dir of each path
  local lib_include_paths = {}
  local seen = {}
  local function add_root(p)
    if not p or p == '' then return end
    -- normalize to absolute
    local abs = vim.fn.fnamemodify(p, ":p"):gsub("/$", "")
    if not seen[abs] and vim.uv.fs_stat(abs) and vim.uv.fs_stat(abs).type == 'directory' then
      seen[abs] = true
      print("Dir added: " .. abs)
      table.insert(lib_include_paths, LifeBoatAPI.Tools.Filepath:new(abs))
    end
  end

  add_root(config.current_project.path)
  for _, path in ipairs(config.current_project.config.libraries or {}) do
    add_root(path)
    local parent = vim.fn.fnamemodify(path, ":h")
    add_root(parent)
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
      LifeBoatAPI.Tools.Filepath:new(config.current_project.path),
      { [".vscode"] = 1, ["_release"] = 1, ["_intermediate"] = 1, [".git"] = 1 },
      { ["lua"] = 1, ["luah"] = 1 }
    )

  --TODO: Multithread this task!

  if MT_AVAILABILITY then
    local mt_build = lanes.gen(function(build_method, builder, relative_path, build_params)
      local originalText, combinedText, finalText, outFile = builder[build_method](
        builder,
        relative_path,
        LifeBoatAPI.Tools.Filepath:new(config.current_project.path .. relative_path),
        build_params
      )
      LifeBoatAPI.Tools.FileSystemUtils.writeAllText(outFile, finalText)
      return originalText, combinedText, finalText, outFile
    end)

    local THREADCOUNT = 4
    local latest_compile = 0

    for _, filepath in ipairs(lua_files) do
      local relative_path = single_file and filepath:linux()
        or filepath:linux():gsub(tostring(config.current_project.path), "")
      local build_method = is_microcontroller and "buildMicrocontroller" or "buildAddonScript"
    end
  end

  -- Build each Lua file (Singlethread)
  for _, file_path in ipairs(lua_files) do
    --print(not single_file and ("Compiling multi: " .. tostring(file_path:linux()) .. "!") or "")
    local relative_path = single_file and file_path:linux()
      or file_path:linux():gsub(tostring(config.current_project.path), "")
    local build_method = is_microcontroller and "buildMicrocontroller" or "buildAddonScript"
    local originalText, combinedText, finalText, outFile = builder[build_method](
      builder,
      relative_path,
      LifeBoatAPI.Tools.Filepath:new(config.current_project.path .. relative_path),
      build_params
    )

    --print("Built file: " .. file_path:linux() .. " -> " .. tostring(outFile:linux()))
    LifeBoatAPI.Tools.FileSystemUtils.writeAllText(outFile, finalText)
  end

  print("✅ Build process completed successfully.")
end

return M
