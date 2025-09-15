-- lua/micro-project/modules/love_runner.lua
-- Launch the LÖVE2D-based Stormworks UI against the current script

local config = require("sw-micro-project.lua.modules.config")

local M = {}

local function path_join(a, b)
  if a:sub(-1) == "/" then return a .. b end
  return a .. "/" .. b
end

local function get_plugin_directory()
  -- Directory where this file resides
  local script_path = debug.getinfo(1, "S").source:sub(2)
  return script_path:match("(.*/)") or ""
end

local function get_love_root_dir()
  -- The Love project directory ships inside the plugin at: lua/common/chromatischer/Love
  -- We are currently in .../lua/modules/, so walk up to lua/, then append common/.../Love
  local modules_dir = get_plugin_directory() -- .../lua/modules/
  local lua_dir = modules_dir:gsub("/modules/?$", "/")
  local love_dir = path_join(lua_dir, "common/chromatischer/Love")
  return love_dir
end

local function find_love_binary()
  local love_cmd = config.config.love_command or "love"
  if vim.fn.executable(love_cmd) == 1 then return love_cmd end
  -- macOS fallback
  local mac_path = config.config.love_macos_path or "/Applications/love.app/Contents/MacOS/love"
  if vim.fn.executable(mac_path) == 1 then return mac_path end
  return nil
end

local function build_args(opts)
  local args = { "--" }
  if opts.script then table.insert(args, "--script"); table.insert(args, opts.script) end
  if opts.tiles then table.insert(args, "--tiles"); table.insert(args, tostring(opts.tiles)) end
  if opts.tick then table.insert(args, "--tick"); table.insert(args, tostring(opts.tick)) end
  if opts.scale then table.insert(args, "--scale"); table.insert(args, tostring(opts.scale)) end
  if opts.debug_canvas ~= nil then table.insert(args, "--debug-canvas"); table.insert(args, opts.debug_canvas and "true" or "false") end
  if opts.props then table.insert(args, "--props"); table.insert(args, opts.props) end
  return args
end

function M.run_current_script(opts)
  opts = opts or {}
  -- Determine current buffer file
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == nil or bufname == "" then
    vim.notify("No current buffer file to run.", vim.log.levels.ERROR)
    return
  end

  -- Ensure absolute path
  local script_path = bufname
  if not script_path:match("^/") then
    script_path = vim.fn.fnamemodify(script_path, ":p")
  end

  local love_bin = find_love_binary()
  if not love_bin then
    vim.notify("Could not find LÖVE2D executable. Set config.love_command or love_macos_path.", vim.log.levels.ERROR)
    return
  end

  local love_root = get_love_root_dir()
  if vim.fn.isdirectory(love_root) == 0 then
    vim.notify("LÖVE2D project directory not found: " .. love_root, vim.log.levels.ERROR)
    return
  end

  local cli = { love_bin, love_root }
  local extra = build_args(vim.tbl_extend("force", { script = script_path }, opts))
  for _,a in ipairs(extra) do table.insert(cli, a) end

  -- Spawn detached job
  local ok = vim.fn.jobstart(cli, { detach = true })
  if ok <= 0 then
    vim.notify("Failed to start LÖVE2D UI (jobstart error)", vim.log.levels.ERROR)
  else
    vim.notify("Started LÖVE2D UI for " .. script_path, vim.log.levels.INFO)
  end
end

return M
