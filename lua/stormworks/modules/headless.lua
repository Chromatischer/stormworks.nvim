-- lua/stormworks/modules/headless.lua
-- Headless export functionality for Neovim integration

local config = require("stormworks.modules.config")
local project = require("stormworks.modules.project")

local M = {}

local function path_join(a, b)
  if a:sub(-1) == "/" then
    return a .. b
  end
  return a .. "/" .. b
end

local function get_plugin_directory()
  local script_path = debug.getinfo(1, "S").source:sub(2)
  return script_path:match("(.*/)") or ""
end

local function get_love_root_dir()
  local modules_dir = get_plugin_directory()
  local lua_dir = modules_dir:gsub("/modules/?$", "/")
  local love_dir = path_join(lua_dir, "common/chromatischer/Love")
  return love_dir
end

local function find_love_binary()
  local love_cmd = config.config.love_command or "love"
  if vim.fn.executable(love_cmd) == 1 then
    return love_cmd
  end
  -- macOS fallback
  local mac_path = config.config.love_macos_path or "/Applications/love.app/Contents/MacOS/love"
  if vim.fn.executable(mac_path) == 1 then
    return mac_path
  end
  return nil
end

local function build_lib_paths()
  local libs = {}
  local proj_root = (config.current_project and config.current_project.path) or vim.loop.cwd()
  table.insert(libs, proj_root)

  -- Include LifeBoatAPI and common folders
  local lua_dir = get_plugin_directory():gsub("/modules/?$", "/")
  local lifeboat_dir = path_join(lua_dir, "common/nameouschangey/Common")
  local chroma_common = path_join(lua_dir, "common/chromatischer")

  local function add_dir_and_parent(dir)
    if vim.fn.isdirectory(dir) == 1 then
      table.insert(libs, dir)
      local parent = vim.fn.fnamemodify(dir, ":h")
      if vim.fn.isdirectory(parent) == 1 then
        table.insert(libs, parent)
      end
    end
  end

  add_dir_and_parent(lifeboat_dir)
  add_dir_and_parent(chroma_common)

  -- Include project libraries
  for _, p in ipairs(config.project_libs or {}) do
    if vim.fn.isdirectory(p) == 1 then
      add_dir_and_parent(p)
    end
  end

  if config.current_project and config.current_project.config and config.current_project.config.libraries then
    for _, p in ipairs(config.current_project.config.libraries) do
      if vim.fn.isdirectory(p) == 1 then
        add_dir_and_parent(p)
      end
    end
  end

  -- Deduplicate
  local seen = {}
  local uniq = {}
  for _, d in ipairs(libs) do
    local abs = vim.fn.fnamemodify(d, ":p"):gsub("/$", "")
    if not seen[abs] then
      seen[abs] = true
      table.insert(uniq, abs)
    end
  end

  return uniq
end

local function build_args(opts, libs)
  local args = { "--" }

  -- Required headless flag
  table.insert(args, "--headless")

  -- Script path
  if opts.script then
    table.insert(args, "--script")
    table.insert(args, opts.script)
  end

  -- Output path
  if opts.output then
    table.insert(args, "--output")
    table.insert(args, opts.output)
  end

  -- Library paths
  if libs then
    for _, lib in ipairs(libs) do
      table.insert(args, "--lib")
      table.insert(args, tostring(lib))
    end
  end

  -- Ticks
  if opts.ticks then
    table.insert(args, "--ticks")
    table.insert(args, tostring(opts.ticks))
  end

  -- Capture mode
  if opts.capture then
    table.insert(args, "--capture")
    table.insert(args, opts.capture)
  end

  -- Format
  if opts.format then
    table.insert(args, "--format")
    table.insert(args, opts.format)
  end

  -- Inputs
  if opts.inputs and type(opts.inputs) == "table" then
    local parts = {}
    for k, v in pairs(opts.inputs) do
      if type(k) == "string" then
        table.insert(parts, k .. "=" .. tostring(v))
      end
    end
    if #parts > 0 then
      table.insert(args, "--inputs")
      table.insert(args, table.concat(parts, ","))
    end
  end

  -- Inputs from JSON file
  if opts.inputs_file then
    table.insert(args, "--inputs-json")
    table.insert(args, opts.inputs_file)
  end

  -- Outputs JSON file
  if opts.outputs_file then
    table.insert(args, "--outputs-json")
    table.insert(args, opts.outputs_file)
  end

  -- Result JSON file
  if opts.result_file then
    table.insert(args, "--result-json")
    table.insert(args, opts.result_file)
  end

  -- Tiles
  if opts.tiles then
    table.insert(args, "--tiles")
    table.insert(args, tostring(opts.tiles))
  end

  -- Debug canvas size
  if opts.debug_canvas_size then
    local w = opts.debug_canvas_size.w or opts.debug_canvas_size[1]
    local h = opts.debug_canvas_size.h or opts.debug_canvas_size[2]
    if w and h then
      table.insert(args, "--debug-canvas-size")
      table.insert(args, string.format("%dx%d", w, h))
    end
  end

  -- Properties
  if opts.properties and type(opts.properties) == "table" then
    local parts = {}
    for k, v in pairs(opts.properties) do
      if type(k) == "string" then
        table.insert(parts, k .. "=" .. tostring(v))
      end
    end
    if #parts > 0 then
      table.insert(args, "--props")
      table.insert(args, table.concat(parts, ","))
    end
  end

  return args
end

---@class ExportOptions
---@field script string Path to the MC script
---@field output string Output image path
---@field ticks? number Number of ticks to run (default: 1)
---@field capture? "debug"|"game"|"both" What to capture (default: "debug")
---@field format? "png"|"jpg" Image format (default: from extension)
---@field inputs? table<string,any> Input values {B1=true, N5=0.5}
---@field inputs_file? string Path to JSON file with inputs
---@field outputs_file? string Path to write outputs JSON
---@field result_file? string Path to write result JSON
---@field tiles? string Tile dimensions "3x2"
---@field debug_canvas_size? {w:number, h:number}
---@field properties? table<string,any> Custom properties
---@field timeout? number Timeout in ms (default: 10000)
---@field on_exit? function(result: table) Callback when done

---Export debug canvas to image file (sync, blocking)
---@param opts ExportOptions
---@return table result Result table with success, image, errors, etc.
function M.export_sync(opts)
  opts = opts or {}

  -- Validate required options
  if not opts.script then
    return { success = false, error = "Missing required option: script" }
  end

  if not opts.output then
    return { success = false, error = "Missing required option: output" }
  end

  -- Ensure absolute path for script
  local script_path = opts.script
  if not script_path:match("^/") then
    script_path = vim.fn.fnamemodify(script_path, ":p")
  end
  opts.script = script_path

  -- Find Love binary
  local love_bin = find_love_binary()
  if not love_bin then
    return { success = false, error = "Could not find LÖVE2D executable. Set config.love_command or love_macos_path." }
  end

  -- Get Love root directory
  local love_root = get_love_root_dir()
  if vim.fn.isdirectory(love_root) == 0 then
    return { success = false, error = "LÖVE2D project directory not found: " .. love_root }
  end

  -- Ensure project libraries are set up
  pcall(project.detect_micro_project)
  pcall(project.setup_project_libraries)

  -- Build library paths
  local libs = build_lib_paths()

  -- Build CLI args
  local cli = { love_bin, love_root }
  local extra = build_args(opts, libs)
  for _, a in ipairs(extra) do
    table.insert(cli, a)
  end

  -- Run synchronously using system call
  local stdout_file = vim.fn.tempname()
  local stderr_file = vim.fn.tempname()
  
  -- Build command with redirects
  local cmd = table.concat(vim.tbl_map(function(arg)
    return vim.fn.shellescape(arg)
  end, cli), " ") .. " > " .. vim.fn.shellescape(stdout_file) .. " 2> " .. vim.fn.shellescape(stderr_file)
  
  vim.fn.system(cmd)
  local exit_code = vim.v.shell_error
  
  -- Read stdout
  local stdout_lines = {}
  if vim.fn.filereadable(stdout_file) == 1 then
    stdout_lines = vim.fn.readfile(stdout_file)
  end
  
  -- Read stderr
  local stderr_lines = {}
  if vim.fn.filereadable(stderr_file) == 1 then
    stderr_lines = vim.fn.readfile(stderr_file)
  end
  
  -- Clean up temp files
  vim.fn.delete(stdout_file)
  vim.fn.delete(stderr_file)
  
  -- Parse result from stdout (JSON)
  local result = nil
  local stdout_str = table.concat(stdout_lines, "\n")
  
  if stdout_str and stdout_str ~= "" then
    -- Find the JSON line (starts with {" and ends with })
    local json_line = stdout_str:match('({.+})')
    if json_line then
      local ok, parsed = pcall(vim.fn.json_decode, json_line)
      if ok then
        result = parsed
      else
        result = {
          success = false,
          error = "Failed to parse result JSON",
          raw_stdout = stdout_str,
          stderr = table.concat(stderr_lines, "\n"),
        }
      end
    else
      result = {
        success = false,
        error = "No JSON found in output",
        raw_stdout = stdout_str,
        stderr = table.concat(stderr_lines, "\n"),
      }
    end
  else
    result = {
      success = false,
      error = "No output from Love2D process",
      stderr = table.concat(stderr_lines, "\n"),
    }
  end
  
  result.exit_code = exit_code
  
  return result
end

---Export debug canvas to image file (async)
---@param opts ExportOptions
---@return nil
function M.export(opts)
  opts = opts or {}

  -- Validate required options
  if not opts.script then
    local err_msg = "Missing required option: script"
    if opts.on_exit then
      opts.on_exit({ success = false, error = err_msg })
    else
      vim.notify(err_msg, vim.log.levels.ERROR)
    end
    return
  end

  if not opts.output then
    local err_msg = "Missing required option: output"
    if opts.on_exit then
      opts.on_exit({ success = false, error = err_msg })
    else
      vim.notify(err_msg, vim.log.levels.ERROR)
    end
    return
  end

  -- Ensure absolute path for script
  local script_path = opts.script
  if not script_path:match("^/") then
    script_path = vim.fn.fnamemodify(script_path, ":p")
  end
  opts.script = script_path

  -- Find Love binary
  local love_bin = find_love_binary()
  if not love_bin then
    local err_msg = "Could not find LÖVE2D executable. Set config.love_command or love_macos_path."
    if opts.on_exit then
      opts.on_exit({ success = false, error = err_msg })
    else
      vim.notify(err_msg, vim.log.levels.ERROR)
    end
    return
  end

  -- Get Love root directory
  local love_root = get_love_root_dir()
  if vim.fn.isdirectory(love_root) == 0 then
    local err_msg = "LÖVE2D project directory not found: " .. love_root
    if opts.on_exit then
      opts.on_exit({ success = false, error = err_msg })
    else
      vim.notify(err_msg, vim.log.levels.ERROR)
    end
    return
  end

  -- Ensure project libraries are set up
  pcall(project.detect_micro_project)
  pcall(project.setup_project_libraries)

  -- Build library paths
  local libs = build_lib_paths()

  -- Build CLI args
  local cli = { love_bin, love_root }
  local extra = build_args(opts, libs)
  for _, a in ipairs(extra) do
    table.insert(cli, a)
  end

  -- Spawn job
  local stdout_data = {}
  local stderr_data = {}

  local job_id = vim.fn.jobstart(cli, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(stdout_data, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(stderr_data, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      -- Parse result from stdout (JSON)
      local result = nil
      local stdout_str = table.concat(stdout_data, "\n")

      if stdout_str and stdout_str ~= "" then
        -- Try to parse JSON result
        local ok, parsed = pcall(vim.fn.json_decode, stdout_str)
        if ok then
          result = parsed
        else
          result = {
            success = false,
            error = "Failed to parse result JSON",
            raw_stdout = stdout_str,
            stderr = table.concat(stderr_data, "\n"),
          }
        end
      else
        result = {
          success = false,
          error = "No output from Love2D process",
          stderr = table.concat(stderr_data, "\n"),
        }
      end

      result.exit_code = exit_code

      -- Call callback or notify
      if opts.on_exit then
        opts.on_exit(result)
      else
        if result.success then
          vim.notify("Export complete: " .. (result.image or ""), vim.log.levels.INFO)
        else
          vim.notify("Export failed: " .. (result.error or "unknown error"), vim.log.levels.ERROR)
        end
      end
    end,
  })

  if job_id <= 0 then
    local err_msg = "Failed to start Love2D process (jobstart error)"
    if opts.on_exit then
      opts.on_exit({ success = false, error = err_msg })
    else
      vim.notify(err_msg, vim.log.levels.ERROR)
    end
  end

  -- Set timeout
  local timeout = opts.timeout or 10000
  vim.defer_fn(function()
    if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
      -- Job still running, kill it
      vim.fn.jobstop(job_id)
      if opts.on_exit then
        opts.on_exit({ success = false, error = "Timeout after " .. timeout .. "ms" })
      else
        vim.notify("Export timeout after " .. timeout .. "ms", vim.log.levels.ERROR)
      end
    end
  end, timeout)
end

return M
